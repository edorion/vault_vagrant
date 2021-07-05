path "*" {
capabilities = ["create","delete","list","read","update","sudo"]
}

path "sys/namespaces/*" {
   capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
