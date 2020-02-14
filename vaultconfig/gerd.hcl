path "auth/*"
{
  capabilities = ["create", "read", "list"]
}

# List auth methods
path "sys/auth"
{
  capabilities = ["read"]
}

# List existing policies
path "sys/policies/acl"
{
  capabilities = ["list"]
}

# List, create, update, and delete key/value secrets
path "secret/+/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}


# List existing secrets engines.
path "sys/mounts"
{
  capabilities = ["read"]
}

