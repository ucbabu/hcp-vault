# Complete HCP Vault + AKS Integration Solution

## 🎯 **Solution Overview**

This repository provides a **complete, production-ready solution** for integrating HashiCorp Cloud Platform (HCP) Vault with Azure Kubernetes Service (AKS) using JWT/OIDC authentication without requiring network connectivity between AKS and Vault.

## ✅ **What's Included**

### 🏗️ **Infrastructure as Code**
- **HCP Vault Cluster** with complete Terraform configuration
- **KV Secrets Engine v2** for application secrets with versioning
- **Database Engine** for Redis with dynamic credential rotation
- **JWT/OIDC Authentication** for passwordless AKS integration
- **Multi-namespace isolation** with domain-based policies

### 🛠️ **AKS Integration Scripts**
- **`quick-oidc.sh`** - Fast OIDC issuer URL extraction
- **`get-aks-info.sh`** - Complete configuration with certificates
- **`enable-oidc.sh`** - Enable OIDC on existing AKS clusters

### 📚 **Comprehensive Documentation**
- **Setup guides** for complete deployment workflow
- **Multi-namespace onboarding** procedures
- **Vault Secrets Operator integration** guide
- **Troubleshooting** and best practices

### 🤖 **Automation Tools**
- **Deployment script** for end-to-end automation
- **Makefile** with common operations
- **Example configurations** for immediate use

## 🚀 **Quick Start Guide**

### Step 1: Extract AKS OIDC Configuration

```bash
# Quick OIDC check
./scripts/aks-setup/quick-oidc.sh myResourceGroup myAKSCluster

# Complete configuration extraction
./scripts/aks-setup/get-aks-info.sh -g myResourceGroup -n myAKSCluster -f terraform >> terraform.tfvars
```

### Step 2: Configure and Deploy

```bash
# Copy configuration template
cp terraform.tfvars.example terraform.tfvars

# Edit with your values (including AKS config from Step 1)
vim terraform.tfvars

# Deploy everything
./scripts/deploy.sh all
```

### Step 3: Verify and Test

```bash
# Check status
make status

# Deploy example application
kubectl apply -f examples/sample-app-deployment.yaml
```

## 🔧 **AKS OIDC and Certificate Scripts**

### Quick OIDC Extraction

```bash
# Basic usage - gets OIDC issuer URL and API endpoint
./scripts/aks-setup/quick-oidc.sh <resource-group> <cluster-name>

# Example output:
✅ OIDC issuer URL: https://eastus.oic.prod-aks.azure.com/tenant-id/cluster-id/
✅ Kubernetes API URL: https://myaks-rg-abcd1234.hcp.eastus.azmk8s.io

📋 Add these to your terraform.tfvars:
jwt_issuer = \"https://eastus.oic.prod-aks.azure.com/tenant-id/cluster-id/\"
k8s_host = \"https://myaks-rg-abcd1234.hcp.eastus.azmk8s.io\"
```

### Complete Configuration Extraction

```bash\n# Extract everything including certificates\n./scripts/aks-setup/get-aks-info.sh -g myRG -n myCluster\n\n# Output formats:\n./scripts/aks-setup/get-aks-info.sh -g myRG -n myCluster -f env        # Environment variables\n./scripts/aks-setup/get-aks-info.sh -g myRG -n myCluster -f terraform  # Terraform format\n./scripts/aks-setup/get-aks-info.sh -g myRG -n myCluster -f json       # JSON format\n\n# Save to file:\n./scripts/aks-setup/get-aks-info.sh -g myRG -n myCluster -f terraform -o aks-config.tf\n```\n\n### OIDC Enablement (if needed)\n\n```bash\n# Enable OIDC issuer on existing AKS cluster\n./scripts/aks-setup/enable-oidc.sh myResourceGroup myAKSCluster\n\n# This will:\n# - Check current OIDC status\n# - Enable OIDC issuer (takes 5-10 minutes)\n# - Validate the configuration\n# - Provide next steps\n```\n\n## 📋 **Configuration Output Examples**\n\n### Terraform Variables Format\n\n```hcl\n# AKS Configuration Variables\nk8s_host = \"https://myaks-rg-abcd1234.hcp.eastus.azmk8s.io\"\njwt_issuer = \"https://eastus.oic.prod-aks.azure.com/tenant-id/cluster-id/\"\nk8s_ca_cert = <<EOF\n-----BEGIN CERTIFICATE-----\nMIIC5zCCAc+gAwIBAgIQNWlLOQdJzYH...\n-----END CERTIFICATE-----\nEOF\njwt_bound_audiences = [\"https://kubernetes.default.svc.cluster.local\"]\n```\n\n### Environment Variables Format\n\n```bash\n# AKS Configuration for Vault JWT/OIDC Authentication\nexport K8S_HOST=\"https://myaks-rg-abcd1234.hcp.eastus.azmk8s.io\"\nexport JWT_ISSUER=\"https://eastus.oic.prod-aks.azure.com/tenant-id/cluster-id/\"\nexport K8S_CA_CERT=\"-----BEGIN CERTIFICATE-----\\nMIIC5zCCAc+gAwIBAgI...\"\n```\n\n## 🎯 **Key Features Delivered**\n\n### 🔒 **Security**\n- **Passwordless Authentication**: JWT/OIDC with no network connectivity required\n- **Namespace Isolation**: Complete separation between domains/teams\n- **Least Privilege**: Minimal required permissions per namespace\n- **Certificate Management**: Automatic extraction and validation\n\n### 🚀 **Automation**\n- **One-Command Deployment**: Complete setup with `./scripts/deploy.sh all`\n- **AKS Integration Scripts**: Automatic OIDC and certificate extraction\n- **Make Targets**: Common operations with simple commands\n- **CI/CD Ready**: All configurations as code\n\n### 📊 **Operational Excellence**\n- **Multi-Namespace Support**: Easy team onboarding\n- **Dynamic Secrets**: Automatic Redis credential rotation\n- **Monitoring Ready**: Comprehensive audit and logging\n- **Documentation**: Complete guides and examples\n\n## 🔄 **Workflow Summary**\n\n### For First-Time Setup:\n\n1. **Extract AKS Configuration**:\n   ```bash\n   ./scripts/aks-setup/get-aks-info.sh -g myRG -n myCluster -f terraform >> terraform.tfvars\n   ```\n\n2. **Complete Configuration**:\n   ```bash\n   vim terraform.tfvars  # Add HCP credentials and other settings\n   ```\n\n3. **Deploy Infrastructure**:\n   ```bash\n   ./scripts/deploy.sh all\n   ```\n\n4. **Verify Setup**:\n   ```bash\n   make status\n   kubectl apply -f examples/sample-app-deployment.yaml\n   ```\n\n### For Adding New Teams/Namespaces:\n\n1. **Update Configuration**:\n   ```hcl\n   # Add to terraform.tfvars\n   namespaces = {\n     # ... existing ...\n     \"team-alpha\" = {\n       domain      = \"alpha\"\n       description = \"Team Alpha namespace\"\n       policies    = [\"alpha-policy\"]\n       kv_paths    = [\"secret/alpha\"]\n     }\n   }\n   ```\n\n2. **Apply Changes**:\n   ```bash\n   terraform apply -var-file=\"terraform.tfvars\"\n   ```\n\n3. **Configure Kubernetes**:\n   ```bash\n   export DOMAIN=\"alpha\"\n   envsubst < examples/namespace-template.yaml | kubectl apply -f -\n   ```\n\n## 🛠️ **Make Targets for AKS Setup**\n\n```bash\n# Quick OIDC extraction\nmake aks-quick-oidc RESOURCE_GROUP=myRG CLUSTER_NAME=myCluster\n\n# Complete configuration extraction\nmake aks-get-config RESOURCE_GROUP=myRG CLUSTER_NAME=myCluster\n\n# Save configuration to file\nmake aks-get-config RESOURCE_GROUP=myRG CLUSTER_NAME=myCluster OUTPUT_FILE=aks-config.tf\n\n# Enable OIDC on cluster\nmake aks-enable-oidc RESOURCE_GROUP=myRG CLUSTER_NAME=myCluster\n```\n\n## 🔍 **Troubleshooting**\n\n### Common Issues and Solutions:\n\n1. **OIDC Not Enabled**:\n   ```bash\n   ./scripts/aks-setup/enable-oidc.sh myResourceGroup myAKSCluster\n   ```\n\n2. **Authentication Failed**:\n   ```bash\n   az login\n   # Verify credentials and permissions\n   ```\n\n3. **Certificate Issues**:\n   ```bash\n   # Re-extract configuration\n   ./scripts/aks-setup/get-aks-info.sh -g myRG -n myCluster -v\n   ```\n\n4. **VSO Issues**:\n   ```bash\n   kubectl logs -n vault-secrets-operator-system deployment/vault-secrets-operator\n   ```\n\n## 📁 **Repository Structure**\n\n```\nhcp-vault/\n├── main.tf                                 # HCP Vault cluster\n├── vault-secrets-engines.tf              # KV and Database engines\n├── vault-auth.tf                         # JWT/OIDC authentication\n├── scripts/\n│   ├── deploy.sh                         # Main deployment script\n│   └── aks-setup/                       # AKS integration scripts\n│       ├── quick-oidc.sh                # Quick OIDC extraction\n│       ├── get-aks-info.sh              # Complete config extraction\n│       ├── enable-oidc.sh               # OIDC enablement\n│       └── README.md                    # AKS setup guide\n├── examples/\n│   ├── namespace-template.yaml          # VSO namespace template\n│   └── sample-app-deployment.yaml       # Example application\n├── docs/\n│   ├── vault-secrets-operator-guide.md  # VSO integration guide\n│   └── multi-namespace-onboarding.md    # Team onboarding\n└── policies/                           # Vault policy templates\n```\n\n## 🎉 **Ready to Use!**\n\nThis solution provides everything you need for production-ready HCP Vault integration with AKS:\n\n- ✅ **Complete Infrastructure**: HCP Vault with KV and Database engines\n- ✅ **AKS Integration**: JWT/OIDC authentication without network connectivity\n- ✅ **Automation Scripts**: One-command deployment and AKS configuration extraction\n- ✅ **Multi-Namespace Support**: Team-based isolation and onboarding\n- ✅ **Documentation**: Comprehensive guides and examples\n- ✅ **Best Practices**: Security, monitoring, and operational excellence\n\n**Start deploying now**: Copy the repository, run the AKS setup scripts, configure your variables, and deploy! 🚀