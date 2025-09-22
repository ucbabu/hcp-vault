# AKS OIDC and Certificate Extraction Scripts

This directory contains scripts to extract OIDC issuer URLs and certificates from Azure Kubernetes Service (AKS) clusters for Vault JWT/OIDC authentication configuration.

## Scripts Overview

| Script | Purpose | Use Case |
|--------|---------|----------|
| `quick-oidc.sh` | Quick OIDC issuer extraction | Fast check and basic configuration |
| `get-aks-info.sh` | Complete configuration extraction | Full setup with certificates |
| `enable-oidc.sh` | Enable OIDC on existing cluster | When OIDC is not enabled |

## Prerequisites

- **Azure CLI** (`az`) - [Install Guide](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- **kubectl** - [Install Guide](https://kubernetes.io/docs/tasks/tools/)
- **jq** - [Install Guide](https://stedolan.github.io/jq/)
- **curl** - Usually pre-installed
- **base64** - Usually pre-installed

## Quick Start

### 1. Check OIDC Status

```bash
# Quick check if OIDC is enabled
./quick-oidc.sh myResourceGroup myAKSCluster
```

**Expected Output:**
```
✅ OIDC issuer URL: https://eastus.oic.prod-aks.azure.com/72f988bf-86f1-41af-91ab-2d7cd011db47/abcd1234-5678-90ab-cdef-1234567890ab/
✅ Kubernetes API URL: https://myakscluster-rg-abcd1234.hcp.eastus.azmk8s.io

📋 Add these to your terraform.tfvars:

jwt_issuer = "https://eastus.oic.prod-aks.azure.com/72f988bf-86f1-41af-91ab-2d7cd011db47/abcd1234-5678-90ab-cdef-1234567890ab/"
k8s_host = "https://myakscluster-rg-abcd1234.hcp.eastus.azmk8s.io"
jwt_bound_audiences = ["https://kubernetes.default.svc.cluster.local"]
```

### 2. Get Complete Configuration

```bash
# Extract complete configuration with certificates
./get-aks-info.sh -g myResourceGroup -n myAKSCluster
```

**Output Options:**

```bash
# Environment variables format (default)
./get-aks-info.sh -g myRG -n myCluster

# Terraform format
./get-aks-info.sh -g myRG -n myCluster -f terraform

# JSON format
./get-aks-info.sh -g myRG -n myCluster -f json

# Save to file
./get-aks-info.sh -g myRG -n myCluster -f terraform -o aks-config.tf
```

### 3. Enable OIDC (if needed)

```bash
# Enable OIDC issuer on existing cluster
./enable-oidc.sh myResourceGroup myAKSCluster
```

## Script Details

### quick-oidc.sh

**Purpose:** Quick extraction of OIDC issuer URL

**Usage:**
```bash
./quick-oidc.sh <resource-group> <cluster-name> [subscription-id]
```

**What it does:**
- Checks if OIDC is enabled
- Extracts OIDC issuer URL
- Gets Kubernetes API URL
- Tests OIDC discovery endpoint
- Provides ready-to-use Terraform variables

**Example:**
```bash
./quick-oidc.sh myResourceGroup myAKSCluster
./quick-oidc.sh myRG myCluster 12345678-1234-1234-1234-123456789012
```

### get-aks-info.sh

**Purpose:** Complete configuration extraction with certificates

**Usage:**
```bash
./get-aks-info.sh [OPTIONS]

Options:
  -g, --resource-group GROUP    Azure resource group name (required)
  -n, --cluster-name NAME       AKS cluster name (required)
  -s, --subscription SUB        Azure subscription ID (optional)
  -f, --format FORMAT           Output format: env|json|terraform (default: env)
  -o, --output FILE             Output to file instead of stdout
  -v, --verbose                 Verbose output
  -h, --help                    Show help message
```

**What it does:**
- Extracts OIDC issuer URL
- Gets Kubernetes CA certificate
- Retrieves API server URL
- Attempts to get OIDC CA certificate
- Creates service account configuration files
- Generates test scripts

**Examples:**
```bash
# Basic usage
./get-aks-info.sh -g myResourceGroup -n myAKSCluster

# Terraform output
./get-aks-info.sh -g myRG -n myCluster -f terraform -o aks-vars.tf

# JSON output with verbose logging
./get-aks-info.sh -g myRG -n myCluster -f json -v > aks-config.json

# Specific subscription
./get-aks-info.sh -g myRG -n myCluster -s 12345678-1234-1234-1234-123456789012
```

**Generated Files:**
- `aks-config/service-account.yaml` - Service account template
- `aks-config/test-jwt-token.sh` - JWT token generation test script

### enable-oidc.sh

**Purpose:** Enable OIDC issuer on existing AKS cluster

**Usage:**
```bash
./enable-oidc.sh <resource-group> <cluster-name> [subscription-id]
```

**What it does:**
- Checks current OIDC status
- Enables OIDC issuer if not already enabled
- Waits for operation completion
- Validates OIDC discovery endpoint
- Provides next steps

**Example:**
```bash
./enable-oidc.sh myResourceGroup myAKSCluster
```

**Important Notes:**
- Operation takes 5-10 minutes
- Requires cluster update permissions
- May cause brief service interruption
- Cluster must be in running state

## Output Formats

### Environment Variables Format

```bash
# AKS Configuration for Vault JWT/OIDC Authentication
export K8S_HOST="https://myakscluster-rg-abcd1234.hcp.eastus.azmk8s.io"
export JWT_ISSUER="https://eastus.oic.prod-aks.azure.com/tenant-id/cluster-id/"
export K8S_CA_CERT="-----BEGIN CERTIFICATE-----\nMIIC5zCCAc+gAwIBAgI..."

# Terraform Variables (add to terraform.tfvars)
k8s_host = "https://myakscluster-rg-abcd1234.hcp.eastus.azmk8s.io"
jwt_issuer = "https://eastus.oic.prod-aks.azure.com/tenant-id/cluster-id/"
k8s_ca_cert = <<EOF
-----BEGIN CERTIFICATE-----
MIIC5zCCAc+gAwIBAgI...
-----END CERTIFICATE-----
EOF
```

### Terraform Format

```hcl
# AKS Configuration Variables
k8s_host = "https://myakscluster-rg-abcd1234.hcp.eastus.azmk8s.io"
jwt_issuer = "https://eastus.oic.prod-aks.azure.com/tenant-id/cluster-id/"
k8s_ca_cert = <<EOF
-----BEGIN CERTIFICATE-----
MIIC5zCCAc+gAwIBAgI...
-----END CERTIFICATE-----
EOF
jwt_bound_audiences = ["https://kubernetes.default.svc.cluster.local"]
```

### JSON Format

```json
{
  "cluster": {
    "name": "myAKSCluster",
    "resource_group": "myResourceGroup"
  },
  "kubernetes": {
    "api_url": "https://myakscluster-rg-abcd1234.hcp.eastus.azmk8s.io",
    "ca_certificate": "-----BEGIN CERTIFICATE-----\n..."
  },
  "oidc": {
    "issuer_url": "https://eastus.oic.prod-aks.azure.com/tenant-id/cluster-id/",
    "ca_certificate": "-----BEGIN CERTIFICATE-----\n..."
  }
}
```

## Integration with Terraform

### Step 1: Extract Configuration

```bash
# Generate Terraform variables
./get-aks-info.sh -g myRG -n myCluster -f terraform >> terraform.tfvars
```

### Step 2: Apply Configuration

```bash
# Deploy Vault with AKS integration
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"
```

### Step 3: Configure Service Accounts

```bash
# Apply generated service account configuration
kubectl apply -f aks-config/service-account.yaml
```

### Step 4: Test JWT Token Generation

```bash
# Test JWT token for specific namespace
./aks-config/test-jwt-token.sh dev vault-secrets-operator
```

## Troubleshooting

### Common Issues

#### 1. OIDC Not Enabled

**Error:** `OIDC issuer is not enabled on this AKS cluster`

**Solution:**
```bash
./enable-oidc.sh myResourceGroup myAKSCluster
```

#### 2. Authentication Failed

**Error:** `ERROR: Please run: az login`

**Solution:**
```bash
az login
# Or for service principal
az login --service-principal -u <app-id> -p <password> --tenant <tenant-id>
```

#### 3. Cluster Not Found

**Error:** `AKS cluster 'myCluster' not found`

**Solution:**
```bash
# List available clusters
az aks list -g myResourceGroup --query '[].name' -o table

# Verify resource group
az group list --query '[].name' -o table
```

#### 4. Permission Denied

**Error:** `Operation failed due to insufficient permissions`

**Solution:**
- Ensure you have `Azure Kubernetes Service Cluster Admin Role` or `Contributor` role
- Check subscription access: `az account show`

#### 5. Certificate Extraction Failed

**Error:** `Could not retrieve CA certificate`

**Solution:**
```bash
# Manual certificate extraction
kubectl config view --raw -o json | \
  jq -r '.clusters[0].cluster."certificate-authority-data"' | \
  base64 -d > k8s-ca.crt
```

### Validation Commands

```bash
# Test OIDC discovery
curl -s https://eastus.oic.prod-aks.azure.com/.../. well-known/openid_configuration | jq .

# Validate JWT token
kubectl create token vault-secrets-operator -n default --duration=3600s

# Test Kubernetes API connectivity
kubectl cluster-info

# Check cluster OIDC status
az aks show -g myRG -n myCluster --query 'oidcIssuerProfile'
```

## Security Considerations

1. **Credential Management**: Store Azure credentials securely
2. **Certificate Validation**: Always validate extracted certificates
3. **Token Scope**: Use minimal required permissions for service accounts
4. **Network Access**: Ensure OIDC discovery endpoints are accessible
5. **Audit Logging**: Enable audit logging for authentication events

## Next Steps

After extracting the configuration:

1. **Update terraform.tfvars** with the extracted values
2. **Deploy Vault infrastructure** using the main deployment script
3. **Configure Vault Secrets Operator** with the generated service account files
4. **Test authentication** using the provided test scripts
5. **Deploy applications** with Vault secret integration

For complete setup instructions, see the [main README](../../README.md) and [Vault Secrets Operator Guide](../vault-secrets-operator-guide.md).