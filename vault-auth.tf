# Enable JWT Auth Method for each namespace/domain
resource "vault_jwt_auth_backend" "kubernetes" {
  for_each = var.namespaces
  depends_on = [time_sleep.vault_initialization]
  
  path         = "${each.value.domain}-k8s"
  description  = "JWT auth backend for ${each.value.domain} Kubernetes cluster"
  
  oidc_discovery_url = var.jwt_issuer
  oidc_discovery_ca_pem = var.jwt_ca_cert != "" ? var.jwt_ca_cert : null
  
  bound_issuer = var.jwt_issuer
  
  tune {
    listing_visibility = "unauth"
    default_lease_ttl  = "1h"
    max_lease_ttl      = "24h"
  }
}

# Create JWT Auth Backend Role for each namespace
resource "vault_jwt_auth_backend_role" "kubernetes" {
  for_each = var.namespaces
  depends_on = [vault_jwt_auth_backend.kubernetes]
  
  backend   = vault_jwt_auth_backend.kubernetes[each.key].path
  role_name = "${each.value.domain}-role"
  
  token_policies = [vault_policy.namespace_combined_policy[each.key].name]
  
  bound_audiences = var.jwt_bound_audiences
  
  # Bind to specific service accounts in the domain namespace
  bound_claims = {
    "kubernetes.io/serviceaccount/namespace" = each.value.domain
  }
  
  # Subject can be any service account in the namespace
  bound_subject = "system:serviceaccount:${each.value.domain}:*"
  
  user_claim = "sub"
  role_type  = "jwt"
  
  token_ttl     = 3600   # 1 hour
  token_max_ttl = 86400  # 24 hours
}

# Alternative: Enable Kubernetes Auth Method (if you prefer this over JWT)
resource "vault_auth_backend" "kubernetes_alt" {
  for_each = var.namespaces
  depends_on = [time_sleep.vault_initialization]
  
  path = "${each.value.domain}-k8s-native"
  type = "kubernetes"
  description = "Kubernetes auth backend for ${each.value.domain}"
  
  tune {
    listing_visibility = "unauth"
    default_lease_ttl  = "1h"
    max_lease_ttl      = "24h"
  }
}

# Configure Kubernetes Auth Method
resource "vault_kubernetes_auth_backend_config" "kubernetes_alt" {
  for_each = var.namespaces
  depends_on = [vault_auth_backend.kubernetes_alt]
  
  backend            = vault_auth_backend.kubernetes_alt[each.key].path
  kubernetes_host    = var.k8s_host
  kubernetes_ca_cert = var.k8s_ca_cert
  
  # Use JWT for authentication instead of service account token
  disable_iss_validation = true
}

# Create Kubernetes Auth Backend Role (alternative method)
resource "vault_kubernetes_auth_backend_role" "kubernetes_alt" {
  for_each = var.namespaces
  depends_on = [vault_kubernetes_auth_backend_config.kubernetes_alt]
  
  backend                          = vault_auth_backend.kubernetes_alt[each.key].path
  role_name                        = "${each.value.domain}-role"
  bound_service_account_names      = ["vault-secrets-operator", "default"]
  bound_service_account_namespaces = [each.value.domain]
  
  token_policies = [vault_policy.namespace_combined_policy[each.key].name]
  
  token_ttl     = 3600   # 1 hour
  token_max_ttl = 86400  # 24 hours
}