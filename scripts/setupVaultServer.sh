#!/usr/bin/env bash

export PATH=$PATH:/usr/local/bin

#installing vault
VAULT_VERSION="$VAULT_VER+ent"
echo "$VAULT_VERSION"

echo "Installing dependencies ..."
apt-get -y install unzip curl

echo "Installing telegraf"
curl -s https://repos.influxdata.com/influxdb.key | sudo apt-key add -
source /etc/lsb-release
echo "deb https://repos.influxdata.com/${DISTRIB_ID,,} ${DISTRIB_CODENAME} stable" | sudo tee /etc/apt/sources.list.d/influxdb.list
sudo apt-get update && sudo apt-get install telegraf
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

cat /vagrant/certs/ca.pem | tee -a /etc/ssl/certs/ca-certificates.crt

echo "Creating Vault configuration ..."
echo 'export VAULT_ADDR="https://localhost:8200"' | tee /etc/profile.d/vault.sh

NETWORK_INTERFACE=$(ls -1 /sys/class/net | grep -v lo | sort -r | head -n 1)
IP_ADDRESS=$(ip address show $NETWORK_INTERFACE | awk '{print $2}' | egrep -o '([0-9]+\.){3}[0-9]+')
HOSTNAME=$(hostname -s)

tee /etc/vault/vault.hcl << EOF
api_addr = "https://${IP_ADDRESS}:8200"
cluster_addr = "https://${IP_ADDRESS}:8201"
ui = true
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
# setup as per https://www.vaultproject.io/docs/configuration/seal/awskms#key-rotation
# need to export your aws key and secret to AWS_KEY_ID and AWS_SECRET respectivly
  seal "awskms" {
  region     = "ap-southeast-2"
  access_key = $AWS_KEY_ID
  secret_key = $AWS_SECRET
  kms_key_id = $KMS_KEY_ID
  }
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

systemctl daemon-reload
systemctl enable vault
systemctl restart vault

## print servers IP address
echo "The IP of the host $(hostname) is $(hostname -I | awk '{print $2}')"
