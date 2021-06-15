#!/usr/bin/env bash

export PATH=$PATH:/usr/local/bin

#installing vault
echo "Installing Vault enterprise version ..."
if [[ $(curl -s https://releases.hashicorp.com/vault/ | grep "$VAULT_VER"+ent\<) && $(ls /vagrant/vault_builds | grep "$VAULT_VER") ]]; then
  ln -s /vagrant/vault_builds/1.7.2/vault /usr/local/bin/vault;
else
  if curl -s -f -o /vagrant/vault_builds/"$VAULT_VERSION"/vault.zip --create-dirs https://releases.hashicorp.com/vault/"$VAULT_VERSION"+ent/vault_"$VAULT_VERSION"+ent_linux_amd64.zip; then
    apt update
    apt install unzip
    unzip /vagrant/vault_builds/"$VAULT_VERSION"/vault.zip -d /vagrant/vault_builds/"$VAULT_VERSION"/
    rm /vagrant/vault_builds/"$VAULT_VERSION"/vault.zip
    ln -s /vagrant/vault_builds/1.7.2/vault /usr/local/bin/vault;
  else
    echo "####### Vault version not found #########"
  fi
fi

echo "Creating Vault service account ..."
useradd -r -d /etc/vault -s /bin/false vault

echo "Creating directory structure ..."
mkdir -p /etc/vault/pki
chown -R root:vault /etc/vault
chmod -R 0750 /etc/vault

mkdir /var/{lib,log}/vault
chown vault:vault /var/{lib,log}/vault
chmod 0750 /var/{lib,log}/vault

echo "Creating Vault configuration ..."
echo 'export VAULT_ADDR="http://localhost:8200"' | tee /etc/profile.d/vault.sh

NETWORK_INTERFACE=$(ls -1 /sys/class/net | grep -v lo | sort -r | head -n 1)
IP_ADDRESS=$(ip address show $NETWORK_INTERFACE | awk '{print $2}' | egrep -o '([0-9]+\.){3}[0-9]+')
HOSTNAME=$(hostname -s)

tee /etc/vault/vault.hcl << EOF
api_addr = "http://${IP_ADDRESS}:8200"
cluster_addr = "https://${IP_ADDRESS}:8201"
ui = true
storage "consul" {
  address = "127.0.0.1:8500"
  path    = "vault/"
}
listener "tcp" {
  address       = "0.0.0.0:8200"
  cluster_addr  = "${IP_ADDRESS}:8201"
  tls_disable   = "true"
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
ExecStart=/usr/local/bin/vault server -config=/etc/vault/vault.hcl
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