# HCP Vault Cluster Outputs
output "vault_cluster_id" {
  description = "Vault cluster ID"
  value       = hcp_vault_cluster.main.cluster_id
}

output "vault_public_endpoint" {
  description = "Vault cluster public endpoint URL"
  value       = hcp_vault_cluster.main.vault_public_endpoint_url
}

output "vault_private_endpoint" {
  description = "Vault cluster private endpoint URL"
  value       = hcp_vault_cluster.main.vault_private_endpoint_url
}

output "vault_version" {
  description = "Vault cluster version"
  value       = hcp_vault_cluster.main.vault_version
}

output "vault_namespace" {
  description = "Vault namespace"
  value       = hcp_vault_cluster.main.namespace
}

# HVN Outputs
output "hvn_id" {
  description = "HVN ID"
  value       = hcp_hvn.main.hvn_id
}

output "hvn_cidr_block" {
  description = "HVN CIDR block"
  value       = hcp_hvn.main.cidr_block
}

output "hvn_self_link" {
  description = "HVN self link"
  value       = hcp_hvn.main.self_link
}

# Admin Token (Sensitive)
output "vault_admin_token" {
  description = "Vault admin token for initial setup"
  value       = hcp_vault_cluster_admin_token.admin_token.token
  sensitive   = true
}

# KV Engine Outputs
output "kv_engine_path" {
  description = "KV secrets engine path"
  value       = vault_mount.kv.path
}

# Database Engine Outputs
output "database_engine_path" {
  description = "Database secrets engine path"
  value       = vault_mount.database.path
}

output "redis_connection_name" {
  description = "Redis database connection name"
  value       = vault_database_connection.redis.name
}

# Authentication Method Outputs
output "jwt_auth_paths" {
  description = "JWT authentication paths for each domain"
  value = {
    for k, v in vault_jwt_auth_backend.kubernetes : k => v.path
  }
}

output "kubernetes_auth_paths" {
  description = "Kubernetes authentication paths for each domain"
  value = {
    for k, v in vault_auth_backend.kubernetes_alt : k => v.path
  }
}

# Policy Outputs
output "namespace_policies" {
  description = "Policies created for each namespace"
  value = {
    for k, v in vault_policy.namespace_combined_policy : k => v.name
  }
}

# Namespace Configuration
output "configured_namespaces" {
  description = "Configured namespaces and their domains"
  value = {
    for k, v in var.namespaces : k => {
      domain      = v.domain
      description = v.description
      jwt_auth_path = vault_jwt_auth_backend.kubernetes[k].path
      k8s_auth_path = vault_auth_backend.kubernetes_alt[k].path
      policy_name   = vault_policy.namespace_combined_policy[k].name
    }
  }
}

# Connection Information for Applications
output "vault_connection_info" {
  description = "Connection information for applications"
  value = {
    vault_url = hcp_vault_cluster.main.vault_public_endpoint_url
    auth_methods = {
      for k, v in var.namespaces : k => {
        jwt_path = vault_jwt_auth_backend.kubernetes[k].path
        k8s_path = vault_auth_backend.kubernetes_alt[k].path
        role_name = "${v.domain}-role"
      }
    }
    kv_path = vault_mount.kv.path
    database_path = vault_mount.database.path
  }
}