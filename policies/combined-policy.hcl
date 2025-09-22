# Combined Policy for ${domain} domain
# KV Secrets Engine Access
path "${kv_path}/data/${domain}/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "${kv_path}/metadata/${domain}/*" {
  capabilities = ["list", "read", "delete"]
}

path "${kv_path}/metadata/${domain}" {
  capabilities = ["list"]
}

# Database Secrets Engine Access
path "database/creds/redis-role" {
  capabilities = ["read"]
}

path "database/config/redis-connection" {
  capabilities = ["read"]
}

# Token self-renewal capabilities
path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}

# Kubernetes auth token renewal
path "auth/${domain}-k8s/login" {
  capabilities = ["create", "update"]
}

# Deny access to other domains
path "${kv_path}/data/*" {
  capabilities = ["deny"]
}

path "${kv_path}/metadata/*" {
  capabilities = ["deny"]
}