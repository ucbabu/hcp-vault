# KV Policy for ${domain} domain
# Allow full access to domain-specific paths
path "${kv_path}/data/${domain}/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "${kv_path}/metadata/${domain}/*" {
  capabilities = ["list", "read", "delete"]
}

# Allow listing at the domain level
path "${kv_path}/metadata/${domain}" {
  capabilities = ["list"]
}

# Deny access to other domains
path "${kv_path}/data/*" {
  capabilities = ["deny"]
}

path "${kv_path}/metadata/*" {
  capabilities = ["deny"]
}