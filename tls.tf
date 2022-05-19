variable "vault_nodes" {
  type = map

  default = {
    "vault-server-1" = 0
    "vault-server-2" = 1
    "vault-server-3" = 2
    "vault-server-4" = 3
    "LDAP-server" = 9
  }
  description = "Number of Vault nodes that need keys"
}


# Generate private key for CA
resource "tls_private_key" "private_key_secondary_ca" {
  algorithm = "RSA"
}

# Self-signing the CA 
resource "tls_self_signed_cert" "secondary_ca" {
  key_algorithm   = "RSA" # Using RSA
  private_key_pem = tls_private_key.private_key_secondary_ca.private_key_pem
  subject {
    common_name  = "Vault secondary CA" # Modern browsers do not look at the CN, SANs are imporatant
    organization = "Vault secondary CA"
  }

  validity_period_hours = 3600 # Validity in hours

  allowed_uses = [ # Needed permissions for signing Vault server certs.
    "crl_signing",
    "cert_signing"
  ]

  is_ca_certificate = true # It is CA
}

# Saving the CA cert to a file
resource "local_file" "ca" {
  content  = tls_self_signed_cert.secondary_ca.cert_pem
  filename = "${path.module}/ca.pem"
}

#### GENERATING KEYS FOR SERVERS

# Generating private key for all servers mentioned in var.vault_nodes 
resource "tls_private_key" "private_key_secondary_vault" {
  for_each  = var.vault_nodes
  algorithm = "RSA"
}

resource "tls_cert_request" "csr_secondary_vault" {
  for_each = var.vault_nodes

  key_algorithm   = "RSA"
  private_key_pem = tls_private_key.private_key_secondary_vault[each.key].private_key_pem

  subject {
    common_name  = "${each.key}.secondary.local" # Just a name, the real names and adresses are in SANs
    organization = "Vault Secondary Cluster"
  }

  ip_addresses = [
    "192.168.0.1${each.value}", # IP of the Container where Vault server is running
    "192.168.1.1${each.value}", # IP of the Container where Vault server is running
    "10.100.1.11",
    "10.100.1.12",
    "10.100.1.13",
    "10.100.1.14",
    "10.100.2.11",
    "10.100.2.12",
    "10.100.3.11",
    "10.100.3.12",
    "10.100.4.11",
    "10.100.4.12",
    "127.0.0.1"
  ]

  dns_names = [
    "localhost" # More to be added
  ]
}

# Singing each of the generated certs with the CA
resource "tls_locally_signed_cert" "vault_cert_sign" {
  for_each = var.vault_nodes

  cert_request_pem   = tls_cert_request.csr_secondary_vault[each.key].cert_request_pem # Provide the CSR
  ca_key_algorithm   = "RSA"
  ca_private_key_pem = tls_private_key.private_key_secondary_ca.private_key_pem # CA private key
  ca_cert_pem        = tls_self_signed_cert.secondary_ca.cert_pem               # CA cert

  validity_period_hours = 3600

  allowed_uses = [ # Important, what the cert can be used for
    "digital_signature",
    "key_encipherment",
    "key_agreement"
  ]

  is_ca_certificate = false # It is not CA
}

# Saving the private key that is going to be used by Vault server
resource "local_file" "private_key_secondary" {
  for_each = var.vault_nodes

  content  = tls_private_key.private_key_secondary_vault[each.key].private_key_pem
  filename = "${path.module}/vault-server-${each.value}.key"
}

# Saving the cert that is going to be used by Vault server
resource "local_file" "vault_cert_secondary" {
  for_each = var.vault_nodes

  content  = tls_locally_signed_cert.vault_cert_sign[each.key].cert_pem
  filename = "${path.module}/vault-server-${each.value}.crt"
}
