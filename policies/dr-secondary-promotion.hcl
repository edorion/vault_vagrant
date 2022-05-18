path "sys/replication/dr/secondary/promote" {
  capabilities = [ "update" ]
}

# To update the primary to connect
path "sys/replication/dr/secondary/update-primary" {
    capabilities = [ "update" ]
}

# To read raft configuration
path "sys/storage/raft/configuration" {
    capabilities = [ "read", "update" ]
}

path "sys/replication/dr/secondary/license" {
    capabilities = [ "read" ]
}

