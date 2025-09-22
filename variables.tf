# HCP Authentication
variable "hcp_client_id" {
  description = "HCP Client ID"
  type        = string
  sensitive   = true
}

variable "hcp_client_secret" {
  description = "HCP Client Secret"
  type        = string
  sensitive   = true
}

# HCP HVN Configuration
variable "hvn_id" {
  description = "HVN ID for the Vault cluster"
  type        = string
  default     = "vault-hvn"
}

variable "cloud_provider" {
  description = "Cloud provider for HVN"
  type        = string
  default     = "azure"
  validation {
    condition     = contains(["aws", "azure"], var.cloud_provider)
    error_message = "Cloud provider must be either 'aws' or 'azure'."
  }
}

variable "region" {
  description = "Region for HVN and Vault cluster"
  type        = string
  default     = "eastus"
}

variable "hvn_cidr_block" {
  description = "CIDR block for HVN"
  type        = string
  default     = "172.25.16.0/20"
}

# Vault Cluster Configuration
variable "vault_cluster_id" {
  description = "Vault Cluster ID"
  type        = string
  default     = "vault-cluster"
}

variable "vault_tier" {
  description = "Vault cluster tier"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "starter_small", "standard_small", "standard_medium", "standard_large"], var.vault_tier)
    error_message = "Vault tier must be one of: dev, starter_small, standard_small, standard_medium, standard_large."
  }
}

variable "vault_public_endpoint" {
  description = "Enable public endpoint for Vault cluster"
  type        = bool
  default     = true
}

variable "vault_namespace" {
  description = "Vault namespace (HCP Plus only)"
  type        = string
  default     = null
}

# KV Engine Configuration
variable "kv_path" {
  description = "Path for KV secrets engine"
  type        = string
  default     = "secret"
}

variable "kv_version" {
  description = "KV secrets engine version"
  type        = number
  default     = 2
  validation {
    condition     = contains([1, 2], var.kv_version)
    error_message = "KV version must be either 1 or 2."
  }
}

# Database Engine Configuration for Redis
variable "redis_connection_name" {
  description = "Name for Redis database connection"
  type        = string
  default     = "redis-connection"
}

variable "redis_host" {
  description = "Redis host"
  type        = string
}

variable "redis_port" {
  description = "Redis port"
  type        = number
  default     = 6379
}

variable "redis_username" {
  description = "Redis username"
  type        = string
  default     = "default"
}

variable "redis_password" {
  description = "Redis password"
  type        = string
  sensitive   = true
}

variable "redis_tls" {
  description = "Enable TLS for Redis connection"
  type        = bool
  default     = false
}

# Kubernetes Authentication Configuration
variable "k8s_auth_path" {
  description = "Path for Kubernetes authentication"
  type        = string
  default     = "kubernetes"
}

variable "k8s_host" {
  description = "Kubernetes API server URL"
  type        = string
}

variable "k8s_ca_cert" {
  description = "Kubernetes CA certificate"
  type        = string
}

variable "jwt_issuer" {
  description = "JWT issuer for OIDC authentication"
  type        = string
}

variable "jwt_ca_cert" {
  description = "JWT CA certificate"
  type        = string
  default     = ""
}

variable "jwt_bound_audiences" {
  description = "Bound audiences for JWT authentication"
  type        = list(string)
  default     = ["https://kubernetes.default.svc.cluster.local"]
}

# Namespace Configuration
variable "namespaces" {
  description = "Configuration for different namespaces based on domains"
  type = map(object({
    domain      = string
    description = string
    policies    = list(string)
    kv_paths    = list(string)
  }))
  default = {
    "development" = {
      domain      = "dev"
      description = "Development environment namespace"
      policies    = ["dev-policy"]
      kv_paths    = ["secret/dev"]
    }
    "staging" = {
      domain      = "staging"
      description = "Staging environment namespace"
      policies    = ["staging-policy"]
      kv_paths    = ["secret/staging"]
    }
    "production" = {
      domain      = "prod"
      description = "Production environment namespace"
      policies    = ["prod-policy"]
      kv_paths    = ["secret/prod"]
    }
  }
}

# Audit and Metrics Configuration (Optional)
variable "grafana_endpoint_id" {
  description = "Grafana endpoint ID for audit logs and metrics"
  type        = string
  default     = null
}

variable "grafana_user" {
  description = "Grafana username"
  type        = string
  default     = null
}

variable "grafana_password" {
  description = "Grafana password"
  type        = string
  sensitive   = true
  default     = null
}

variable "splunk_hecendpoint" {
  description = "Splunk HEC endpoint"
  type        = string
  default     = null
}

variable "splunk_token" {
  description = "Splunk HEC token"
  type        = string
  sensitive   = true
  default     = null
}

variable "datadog_api_key" {
  description = "Datadog API key"
  type        = string
  sensitive   = true
  default     = null
}

variable "datadog_region" {
  description = "Datadog region"
  type        = string
  default     = null
}

variable "elasticsearch_endpoint" {
  description = "Elasticsearch endpoint"
  type        = string
  default     = null
}

variable "elasticsearch_user" {
  description = "Elasticsearch username"
  type        = string
  default     = null
}

variable "elasticsearch_password" {
  description = "Elasticsearch password"
  type        = string
  sensitive   = true
  default     = null
}