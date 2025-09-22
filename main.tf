terraform {
  required_version = ">= 1.0"
  required_providers {
    hcp = {
      source  = "hashicorp/hcp"
      version = "~> 0.84.1"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 3.20.0"
    }
  }
}

# Configure HCP Provider
provider "hcp" {
  client_id     = var.hcp_client_id
  client_secret = var.hcp_client_secret
}

# Configure Vault Provider
provider "vault" {
  # Configuration will be set via environment variables or vault CLI
  address   = hcp_vault_cluster.main.vault_public_endpoint_url
  token     = hcp_vault_cluster_admin_token.admin_token.token
  namespace = var.vault_namespace
}

# Create HCP Vault Cluster
resource "hcp_vault_cluster" "main" {
  cluster_id      = var.vault_cluster_id
  hvn_id          = hcp_hvn.main.hvn_id
  tier            = var.vault_tier
  public_endpoint = var.vault_public_endpoint
  
  # Audit and metrics configuration will be set up post-deployment
  # HCP Vault Plus required for advanced audit log streaming
}

# Create HashiCorp Virtual Network (HVN)
resource "hcp_hvn" "main" {
  hvn_id         = var.hvn_id
  cloud_provider = var.cloud_provider
  region         = var.region
  cidr_block     = var.hvn_cidr_block
}

# Create Admin Token for Vault Configuration
resource "hcp_vault_cluster_admin_token" "admin_token" {
  cluster_id = hcp_vault_cluster.main.cluster_id
}

# Wait for Vault cluster to be ready
resource "time_sleep" "vault_initialization" {
  depends_on = [hcp_vault_cluster.main]
  create_duration = "60s"
}