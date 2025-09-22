# Enable KV Secrets Engine
resource "vault_mount" "kv" {
  depends_on = [time_sleep.vault_initialization]
  path       = var.kv_path
  type       = "kv"
  
  options = {
    version = var.kv_version
  }
  
  description = "KV Secrets Engine for application secrets"
}

# Create KV paths for different environments
resource "vault_generic_secret" "namespace_secrets" {
  for_each = var.namespaces
  depends_on = [vault_mount.kv]
  
  path = "${var.kv_path}/${each.value.domain}/config"
  
  data_json = jsonencode({
    environment = each.key
    domain      = each.value.domain
    description = each.value.description
  })
}

# Enable Database Secrets Engine
resource "vault_mount" "database" {
  depends_on  = [time_sleep.vault_initialization]
  path        = "database"
  type        = "database"
  description = "Database secrets engine for dynamic credentials"
}

# Configure Redis Database Connection
resource "vault_database_connection" "redis" {
  depends_on    = [vault_mount.database]
  backend       = vault_mount.database.path
  name          = var.redis_connection_name
  allowed_roles = ["redis-role"]

  redis {
    host     = var.redis_host
    port     = var.redis_port
    username = var.redis_username
    password = var.redis_password
    tls      = var.redis_tls
  }
}

# Create Redis Database Role
resource "vault_database_role" "redis" {
  depends_on    = [vault_database_connection.redis]
  backend       = vault_mount.database.path
  name          = "redis-role"
  db_name       = vault_database_connection.redis.name
  
  creation_statements = [
    "ACL SETUSER {{username}} on >{{password}} ~* &* +@all"
  ]
  
  revocation_statements = [
    "ACL DELUSER {{username}}"
  ]
  
  default_ttl = 3600    # 1 hour
  max_ttl     = 86400   # 24 hours
}

# Create namespace-specific KV policies
resource "vault_policy" "namespace_kv_policy" {
  for_each = var.namespaces
  name     = "${each.value.domain}-kv-policy"

  policy = templatefile("${path.module}/policies/kv-policy.hcl", {
    kv_path = var.kv_path
    domain  = each.value.domain
  })
}

# Create database policies for each namespace
resource "vault_policy" "namespace_db_policy" {
  for_each = var.namespaces
  name     = "${each.value.domain}-db-policy"

  policy = templatefile("${path.module}/policies/db-policy.hcl", {
    domain = each.value.domain
  })
}

# Create comprehensive policies combining KV and DB access
resource "vault_policy" "namespace_combined_policy" {
  for_each = var.namespaces
  name     = "${each.value.domain}-policy"

  policy = templatefile("${path.module}/policies/combined-policy.hcl", {
    kv_path = var.kv_path
    domain  = each.value.domain
  })
}