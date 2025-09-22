# Database Policy for ${domain} domain
# Allow access to Redis credentials for this domain
path "database/creds/redis-role" {
  capabilities = ["read"]
}

# Allow reading database configuration
path "database/config/redis-connection" {
  capabilities = ["read"]
}