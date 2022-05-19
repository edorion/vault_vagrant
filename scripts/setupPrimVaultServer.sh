#!/usr/bin/env bash

export PATH=$PATH:/usr/local/bin

#installing vault
VAULT_VERSION="$VAULT_VER+ent"
echo "$VAULT_VERSION"

echo "$AWS_KEY_ID"
echo "$AWS_SECRET"
echo "$KMS_KEY_ID"

echo "Installing dependencies ..."
apt-get update && apt-get -y install unzip curl gnupg software-properties-common

echo "Installing Terraform"
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install terraform

echo "Installing telegraf"
curl -s https://repos.influxdata.com/influxdb.key | sudo apt-key add -
source /etc/lsb-release
echo "deb https://repos.influxdata.com/${DISTRIB_ID,,} ${DISTRIB_CODENAME} stable" | sudo tee /etc/apt/sources.list.d/influxdb.list
sudo apt-get update && sudo apt-get install telegraf jq
sudo systemctl start telegraf

echo "Installing Vault enterprise version ..."
if [[ $(curl -s https://releases.hashicorp.com/vault/ | grep "$VAULT_VERSION") && $(ls /vagrant/vault_builds | grep "$VAULT_VERSION") ]]; then
  echo "Linking Vault build"
  ln -s /vagrant/vault_builds/"$VAULT_VERSION"/vault /usr/local/bin/vault;
else
  if curl -s -f -o /vagrant/vault_builds/"$VAULT_VERSION"/vault.zip --create-dirs https://releases.hashicorp.com/vault/"$VAULT_VERSION"/vault_"$VAULT_VERSION"_linux_amd64.zip; then
    unzip /vagrant/vault_builds/"$VAULT_VERSION"/vault.zip -d /vagrant/vault_builds/"$VAULT_VERSION"/
    rm /vagrant/vault_builds/"$VAULT_VERSION"/vault.zip
    ln -s /vagrant/vault_builds/"$VAULT_VERSION"/vault /usr/local/bin/vault;
  else
    echo "####### Vault version not found #########"
  fi
fi

echo "Creating Vault service account ..."
useradd -r -d /etc/vault -s /bin/false vault

echo "Creating directory structure ..."
mkdir -p /etc/vault/pki
mkdir /opt/vault
chown vault:vault /opt/vault
chown -R root:vault /etc/vault
chmod -R 0750 /etc/vault

mkdir /var/{lib,log}/vault
chown vault:vault /var/{lib,log}/vault
chmod 0750 /var/{lib,log}/vault

sudo cp /vagrant/certs/ca.pem /usr/local/share/ca-certificates
sudo cp /vagrant/certs/ca.pem /etc/ssl/certs/ca.pem
sudo cat /vagrant/certs/ca.pem >> /etc/ssl/certs/ca-certificates.crt
sudo update-ca-certificates --fresh

echo "Creating Vault configuration ..."
echo 'export VAULT_ADDR="https://localhost:8200"' | tee /etc/profile.d/vault.sh

NETWORK_INTERFACE=$(ls -1 /sys/class/net | grep -v lo | sort -r | head -n 1)
IP_ADDRESS=$(ip address show $NETWORK_INTERFACE | awk '{print $2}' | egrep -o '([0-9]+\.){3}[0-9]+')
HOSTNAME=$(hostname -s)

tee /etc/vault/vault.hcl << EOF
api_addr = "https://${IP_ADDRESS}:8200"
cluster_addr = "https://${IP_ADDRESS}:8201"
ui = true
# raw_storage_endpoint = "true"
license_path = "/vagrant/.license"
storage "raft" {
  path = "/opt/vault"
  node_id = "${HOST}"

  retry_join {
    leader_api_addr = "https://10.100.1.11:8200"
  }

  retry_join {
    leader_api_addr = "https://10.100.1.12:8200"
  }

  retry_join {
    leader_api_addr = "https://10.100.1.13:8200"
  }
}

#storage "consul" {
#  address = "127.0.0.1:8500"
#  path    = "vault/"
#}
listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_disable   = "false"
  tls_cert_file = "/vagrant/certs/vault-server-1.crt"
  tls_key_file  = "/vagrant/certs/vault-server-1.key"
  tls_client_ca_file = "/vagrant/certs/ca.pem"
  telemetry {
    unauthenticated_metrics_access = true
  }
}
# setup as per https://www.vaultproject.io/docs/configuration/seal/awskms#key-rotation
# need to export your aws key and secret to AWS_KEY_ID and AWS_SECRET respectivly
seal "awskms" {
  region     = "ap-southeast-2"
  access_key = "$AWS_KEY_ID"
  secret_key = "$AWS_SECRET"
  kms_key_id = "$KMS_KEY_ID"
}
telemetry {
  dogstatsd_addr = "localhost:8125"
  disable_hostname = true
  enable_hostname_label = false
  prometheus_retention_time = "0h"
}
EOF

chown root:vault /etc/vault/vault.hcl
chmod 0640 /etc/vault/vault.hcl

tee /etc/systemd/system/vault.service << EOF
[Unit]
Description="Vault secret management tool"
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/vault/vault.hcl
[Service]
User=vault
Group=vault
PIDFile=/var/run/vault/vault.pid
ExecStart=/usr/local/bin/vault server -config=/etc/vault/vault.hcl -log-level=trace
StandardOutput=file:/var/log/vault/vault.log
StandardError=file:/var/log/vault/vault.log
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
KillSignal=SIGINT
Restart=on-failure
RestartSec=42
TimeoutStopSec=30
StartLimitInterval=60
StartLimitBurst=3
LimitMEMLOCK=infinity
[Install]
WantedBy=multi-user.target
EOF

tee /etc/telegraf/telegraf.conf << EOF
[global_tags]
  index="vault-metrics"
  datacenter = "testing"
  role       = "vault-server"
  cluster    = "vtl"

# Agent options around collection interval, sizes, jitter and so on
[agent]
  interval = "10s"
  round_interval = true
  metric_batch_size = 1000
  metric_buffer_limit = 10000
  collection_jitter = "0s"
  flush_interval = "10s"
  flush_jitter = "0s"
  precision = ""
  hostname = ""
  omit_hostname = false

# An input plugin that listens on UDP/8125 for statsd compatible telemetry
# messages using Datadog extensions which are emitted by Vault
[[inputs.statsd]]
  protocol = "udp"
  service_address = ":8125"
  metric_separator = "."
  datadog_extensions = true

##[[outputs.file]]
##  files = ["stdout", "/tmp/metrics.out"]
##  data_format = "json"
##  json_timestamp_units = "1s"
EOF


systemctl daemon-reload
systemctl enable vault
systemctl restart vault

### Init Vault
vault operator init > ~/VaultCreds.txt

## print servers IP address
echo "The IP of the host $(hostname) is $(hostname -I | awk '{print $2}')"
