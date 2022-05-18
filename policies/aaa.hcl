# List existing policies
path "sys/policies/acl"
{
  capabilities = ["list"]
}

# List and Read policy through CLI
path "/sys/policies/acl/*" {
  capabilities = ["read", "list"]
}
