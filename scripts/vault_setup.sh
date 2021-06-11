#!/usr/bin/env bash

#VAULT_VERSION=$1
VAULT_VERSION="1.7.2"

## print servers IP address
echo "The IP of the host $(hostname) is $(hostname -I | awk '{print $2}')"

if [[ $(curl -s https://releases.hashicorp.com/vault/ | grep "$VAULT_VERSION"+ent\<) && $(ls /vagrant/vault_builds | grep "$VAULT_VERSION") ]]; then
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