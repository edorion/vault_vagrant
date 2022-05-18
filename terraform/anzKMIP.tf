# kmip module
# Variabalise kmip in /au/kmip
resource "vault_mount" "kmip" {
  path = format("%s/au/kmip/data/%s", var.platform, var.zone)
  type = "kmip"
  description = "ADP KMIP Secret Engine"
}

resource "vault_generic_endpoint" "kmip_config" {
  depends_on = [vault_mount.kmip]
  path = format("%s/au/kmip/data/%s/config", var.platform, var.zone)
  ignore_absent_fields = true
  data_json = <<EOT
    {
      "listen_addrs": "${var.listen_addrs}",
      "default_tls_client_key_type": "rsa",
      "default_tls_client_key_bits": "2048",
      "default_tls_client_ttl": "${var.default_tls_client_ttl}",
      "server_hostnames": "${join(", ","${var.server_hostnames}")}"
    }
  EOT
  }

# kmip scopes-opes module
resource "vault_generic_endpoint" "kmip_scope" {
  for_each = local.vcenters_flattened_map
  path = format("%s/au/kmip/data/%s/scope/%s", var.platform, var.zone, each.value.scope_name)
  ignore_absent_fields = true
  disable_read = true
  data_json = <<EOT
  {
  }
  EOT
}

resource "vault_generic_endpoint" "kmip_scope_role" {
  depends_on = [vault_generic_endpoint.kmip_scope]
  for_each = local.vcenters_flattened_map
  path = format("%s/au/kmip/data/%s/scope/%s/role/%s", var.platform, var.zone, each.value.scope_name, each.value.role_name)
  ignore_absent_fields = false
  data_json = <<EOT
  {
    "operation_all": "${var.operation_all}"
  }
  EOT
}

# Call kmip module
module "vault_namespace_kmip" {
  count = var.is_kmip_required == true ? 1 : 0
  source = "../../modules/engine/kmip"
  providers = {
    vault = vault.namespace
    }
      server_hostnames = var.server_hostnames
    }
    # Call kmiprole module
    # # Create module to call kmip roles on au_adp_admin and configure within a given namespace
    module "vault_namespace_kmiproles" {
        count = var.is_kmip_required == true ? 1 : 0
        source = "../../modules/engine/kmiprole"
        providers = {
          vault = vault.namespace
        }
        vcenters = var.vcenters
      }

# tfvars
server_hostnames = [ "eaas.adp.dev.service.anz", "daxxx01l.unixtest.anz", "daxxx02l.unixtest.anz", "daxxx06l.unixtest.anz", "eaas.adp.cluster.dev.service.anz" ]
vcenters = [
  {
    vcenter_name = "vcsau101melf001"
    vcenter_clusters = [
  {
    vcenter_cluster_name = "clu-101mel_01-m01-cl01"
    kmip_scope_name = "clu-101mel_01-m01-cl01"
    roles = [{
      role_name = "vcf"
      operations = ["operations_all"]
    }]
  }]
},
{
  vcenter_name = "vcsau101melf002"
  vcenter_clusters = [
{
  vcenter_cluster_name = "clu-101mel01-w01-cl01"
  kmip_scope_name = "clu-101mel01-w01-cl01"
  roles = [{
    role_name = "vcf"
    operations = ["operations_all"]
    }]
  }]
}
]
