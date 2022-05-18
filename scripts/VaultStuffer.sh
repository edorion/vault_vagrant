#!/usr/bin/env zsh

vault secrets enable -path=secret kv-v2
vault secrets enable -path=secret1 kv-v2
vault secrets enable -path=secret2 kv-v2
vault auth enable userpass
vault policy write aaa ../policies/aaa.hcl;

vault secrets enable pki
vault secrets tune -max-lease-ttl=8760h pki
vault write pki/root/generate/internal common_name=my-website.com ttl=8760h

for i in {1..1000}; do echo $i; vault kv put secret/customer/acme$i name="test$i" contact_email="test$i@acme.com"; done
for i in {1..1000}; do echo $i; vault kv put secret1/customer/acme$i name="test$i" contact_email="test$i@acme.com"; done
for i in {1..1000}; do echo $i; vault kv put secret2/customer/acme$i name="test$i" contact_email="test$i@acme.com"; done
for i in {1..1000}; do echo $i; vault write auth/userpass/users/test$i password=foo policies=aaa; done
for i in {1..1000}; do echo $i; vault token create -policy=admin -ttl=1500s;done

for j in {1..5}; do
  echo $j
  vault namespace create $j
  vault secrets enable -namespace=$j -path=secret kv-v2
  vault secrets enable -namespace=$j -path=secret1 kv-v2
  vault secrets enable -namespace=$j -path=secret2 kv-v2
  vault auth enable -namespace=$j userpass
  vault policy write -namespace=$j aaa ../policies/aaa.hcl;

  vault secrets enable -namespace=$j pki
  vault secrets tune -namespace=$j -max-lease-ttl=8760h pki
  vault write -namespace=$j pki/root/generate/internal common_name="$j-website.com" ttl=8760h

  for i in {1..1000}; do echo $i; vault kv put -namespace=$j secret/customer/acme$i name="test$i" contact_email="test$i@acme.com"; done
  for i in {1..1000}; do echo $i; vault kv put -namespace=$j secret1/customer/acme$i name="test$i" contact_email="test$i@acme.com"; done
  for i in {1..1000}; do echo $i; vault kv put -namespace=$j secret2/customer/acme$i name="test$i" contact_email="test$i@acme.com"; done
  for i in {1..1000}; do echo $i; vault write -namespace=$j auth/userpass/users/test$i password=foo policies=aaa; done
  for i in {1..1000}; do echo $i; vault token create -namespace=$j -policy=admin -ttl=1500s;done
done
