# HCP Vault with Kubernetes Integration

This repository provides a complete Terraform configuration for setting up HashiCorp Cloud Platform (HCP) Vault with seamless Kubernetes integration using JWT/OIDC authentication and the Vault Secrets Operator.

## 🏗️ Architecture Overview

```mermaid
graph TB
    subgraph "HCP (HashiCorp Cloud Platform)"
        HV[HCP Vault Cluster]
        HVN[HashiCorp Virtual Network]
    end
    
    subgraph "Azure Kubernetes Service"
        VSO[Vault Secrets Operator]
        NS1[Namespace: dev]
        NS2[Namespace: staging] 
        NS3[Namespace: prod]
        POD[Application Pods]
    end
    
    subgraph "Vault Engines"
        KV[KV Secrets Engine v2]
        DB[Database Engine - Redis]
        JWT[JWT/OIDC Auth Method]
    end
    
    HV --> HVN
    HV --> KV
    HV --> DB  
    HV --> JWT
    
    VSO --> HV
    NS1 --> VSO
    NS2 --> VSO
    NS3 --> VSO
    POD --> VSO
    
    JWT --> NS1
    JWT --> NS2
    JWT --> NS3
```

## ✨ Features

- **🔐 HCP Vault Cluster**: Fully managed Vault cluster in HashiCorp Cloud Platform
- **🔑 KV Secrets Engine v2**: Key-Value secrets with versioning
- **💾 Database Engine**: Dynamic Redis credentials with automatic rotation
- **🎟️ JWT/OIDC Authentication**: Passwordless authentication from AKS without network connectivity
- **🏷️ Multi-Namespace Support**: Domain-based isolation for teams and environments
- **🤖 Vault Secrets Operator**: Automatic secret synchronization to Kubernetes
- **📊 Audit Logging**: Comprehensive audit and metrics configuration
- **🛡️ Security Policies**: Least-privilege access control per namespace

## 📁 Repository Structure

```
.
├── main.tf                              # Main Terraform configuration
├── variables.tf                         # Variable definitions
├── outputs.tf                          # Output definitions
├── vault-secrets-engines.tf           # KV and Database engine configuration
├── vault-auth.tf                      # JWT/OIDC authentication setup
├── terraform.tfvars.example           # Example configuration file
├── policies/                          # Vault policy templates
│   ├── kv-policy.hcl                 # KV access policy template
│   ├── db-policy.hcl                 # Database access policy template
│   └── combined-policy.hcl           # Combined access policy template
├── examples/                          # Example Kubernetes configurations
│   ├── namespace-template.yaml        # VSO namespace template
│   └── sample-app-deployment.yaml     # Sample application deployment
├── scripts/                          # Automation scripts
│   └── deploy.sh                     # Deployment automation script
└── docs/                             # Documentation
    ├── vault-secrets-operator-guide.md
    └── multi-namespace-onboarding.md
```

## 🚀 Quick Start

### Prerequisites

Ensure you have the following tools installed:

- [Terraform](https://terraform.io/downloads) >= 1.0
- [kubectl](https://kubernetes.io/docs/tasks/tools/) >= 1.21
- [Vault CLI](https://developer.hashicorp.com/vault/docs/install) >= 1.13
- [Helm](https://helm.sh/docs/intro/install/) >= 3.0
- [jq](https://stedolan.github.io/jq/) (for the deployment script)

### 1. Clone and Configure

```bash
# Clone the repository
git clone <repository-url>
cd hcp-vault

# Copy and configure variables
cp terraform.tfvars.example terraform.tfvars
```

### 2. Configure HCP Authentication

Get your HCP credentials from the [HCP Console](https://portal.cloud.hashicorp.com/):

```bash
# Edit terraform.tfvars
vim terraform.tfvars
```

Set the required variables:
```hcl
hcp_client_id     = "your-hcp-client-id"
hcp_client_secret = "your-hcp-client-secret"
k8s_host         = "https://your-aks-cluster.hcp.eastus.azmk8s.io"
redis_host       = "your-redis-host.example.com"
redis_password   = "your-redis-password"
```

### 3. Deploy Infrastructure

Use the automated deployment script:

```bash
# Deploy everything
./scripts/deploy.sh all

# Or deploy step by step
./scripts/deploy.sh deploy          # Deploy Vault infrastructure
./scripts/deploy.sh install-vso     # Install Vault Secrets Operator  
./scripts/deploy.sh setup-ns        # Setup Kubernetes namespaces
./scripts/deploy.sh init-secrets    # Initialize secrets
./scripts/deploy.sh test           # Test the setup
```

### 4. Get Connection Information

```bash
# Get Vault connection details
./scripts/deploy.sh vault-info

# Example output:
# export VAULT_ADDR="https://vault-cluster.vault.abc123.z1.hashicorp.cloud:8200"
# export VAULT_TOKEN="hvs.ABC123..."
```

## 🔧 Manual Deployment

If you prefer manual deployment:

### 1. Deploy Vault Infrastructure

```bash
# Initialize Terraform
terraform init

# Plan deployment
terraform plan -var-file="terraform.tfvars"

# Apply configuration
terraform apply -var-file="terraform.tfvars"
```

### 2. Install Vault Secrets Operator

```bash
# Add HashiCorp Helm repository
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

# Get Vault URL
VAULT_URL=$(terraform output -raw vault_public_endpoint)

# Install VSO
helm install vault-secrets-operator hashicorp/vault-secrets-operator \
  --namespace vault-secrets-operator-system \
  --create-namespace \
  --set defaultVaultConnection.enabled=true \
  --set defaultVaultConnection.address="$VAULT_URL"
```

### 3. Configure Namespaces

```bash
# Set environment variables for template substitution
export DOMAIN="dev"
export VAULT_ADDR=$(terraform output -raw vault_public_endpoint)
export VAULT_HOST=$(echo "$VAULT_ADDR" | sed 's|https://||' | sed 's|:8200||')
export REDIS_HOST="your-redis-host.example.com"

# Apply namespace configuration
envsubst < examples/namespace-template.yaml | kubectl apply -f -
```

## 🎯 Namespace Configuration

The setup supports multiple isolated namespaces based on domains:

### Default Namespaces

| Namespace | Domain | Purpose | KV Path | Auth Method |
|-----------|--------|---------|---------|-------------|
| development | `dev` | Development environment | `secret/dev/*` | `dev-k8s` |
| staging | `staging` | Pre-production testing | `secret/staging/*` | `staging-k8s` |
| production | `prod` | Production workloads | `secret/prod/*` | `prod-k8s` |

### Adding New Namespaces

1. **Update terraform.tfvars**:
```hcl
namespaces = {
  # ... existing namespaces ...
  "team-alpha" = {
    domain      = "alpha"
    description = "Team Alpha dedicated namespace"
    policies    = ["alpha-policy"]
    kv_paths    = ["secret/alpha"]
  }
}
```

2. **Apply Terraform changes**:
```bash
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"
```

3. **Configure Kubernetes namespace**:
```bash
export DOMAIN="alpha"
envsubst < examples/namespace-template.yaml | kubectl apply -f -
```

## 🔐 Secret Management

### Static Secrets (KV Engine)

```bash
# Set Vault environment
export VAULT_ADDR=$(terraform output -raw vault_public_endpoint)
export VAULT_TOKEN=$(terraform output -raw vault_admin_token)

# Store application configuration
vault kv put secret/dev/app-config \
  api_url="https://dev-api.example.com" \
  log_level="debug" \
  feature_flags="new-ui,beta-features"

# Store database configuration  
vault kv put secret/dev/database/postgres \
  host="dev-postgres.example.com" \
  port="5432" \
  database="myapp_dev" \
  ssl_mode="require"
```

### Dynamic Secrets (Database Engine)

Redis credentials are automatically generated and rotated:

```bash
# Get dynamic Redis credentials
vault read database/creds/redis-role

# Example output:
# Key                Value
# lease_id           database/creds/redis-role/ABC123
# lease_duration     1h
# username           v-jwt-redis-rol-ABC123
# password           XYZ789
```

## 🚀 Application Integration

### Using Vault Secrets Operator

Create `VaultStaticSecret` and `VaultDynamicSecret` resources:

```yaml
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultStaticSecret
metadata:
  namespace: dev
  name: app-config
spec:
  type: kv-v2
  mount: secret
  path: dev/app-config
  destination:
    name: app-config
    create: true
  refreshAfter: 30s
  vaultAuthRef: vault-auth
```

### In Application Pods

```yaml
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      containers:
      - name: app
        env:
        - name: API_URL
          valueFrom:
            secretKeyRef:
              name: app-config
              key: api_url
        - name: REDIS_URL  
          valueFrom:
            secretKeyRef:
              name: redis-credentials
              key: redis_url
```

## 📊 Monitoring and Troubleshooting

### Check VSO Status

```bash
# Check operator pods
kubectl get pods -n vault-secrets-operator-system

# Check VSO logs
kubectl logs -n vault-secrets-operator-system deployment/vault-secrets-operator

# Check secret synchronization status
kubectl describe vaultstaticsecret app-config -n dev
```

### Vault Health Check

```bash
# Check Vault cluster status
vault status

# Check auth methods
vault auth list

# Check policies
vault policy list
```

### Common Issues

1. **Authentication Failures**
   ```bash
   # Check service account configuration
   kubectl get serviceaccount vault-secrets-operator -n dev -o yaml
   
   # Test JWT token generation
   kubectl create token vault-secrets-operator -n dev --duration=3600s
   ```

2. **Network Connectivity**
   ```bash
   # Test Vault connectivity from cluster
   kubectl run test-vault --rm -i --tty --image=curlimages/curl -- \
     curl -k https://your-vault-cluster.vault.xxxxx.z1.hashicorp.cloud:8200/v1/sys/health
   ```

3. **Policy Issues**
   ```bash
   # Check policy configuration
   vault policy read dev-policy
   
   # Test policy with authentication
   vault write auth/dev-k8s/login role=dev-role jwt=$JWT_TOKEN
   ```

## 📚 Documentation

- **[Vault Secrets Operator Guide](docs/vault-secrets-operator-guide.md)**: Comprehensive guide for VSO integration
- **[Multi-Namespace Onboarding](docs/multi-namespace-onboarding.md)**: Team and environment onboarding procedures

## 🔒 Security Considerations

- **Network Security**: HCP Vault uses public endpoints with TLS encryption
- **Authentication**: JWT/OIDC provides passwordless authentication without network connectivity
- **Authorization**: Least-privilege policies per namespace/domain
- **Audit Logging**: Comprehensive audit logs available in HCP
- **Secret Rotation**: Automatic rotation for database credentials

## 🛠️ Customization

### Custom Policies

Create custom policy templates in the `policies/` directory:

```hcl
# policies/custom-policy.hcl
path "secret/data/${domain}/custom/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
```

### Additional Auth Methods

Add more authentication methods in `vault-auth.tf`:

```hcl
resource "vault_auth_backend" "userpass" {
  type = "userpass"
  path = "userpass"
}
```

### Database Engines

Add support for other databases:

```hcl
resource "vault_database_connection" "postgresql" {
  backend = vault_mount.database.path
  name    = "postgresql-connection"
  
  postgresql {
    connection_url = "postgresql://{{username}}:{{password}}@postgres:5432/mydb"
    username       = var.pg_username
    password       = var.pg_password
  }
}
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add/update documentation
5. Test your changes
6. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

- **Issues**: Create an issue in this repository
- **Documentation**: Check the `docs/` directory
- **HCP Support**: [HashiCorp Support](https://support.hashicorp.com/)
- **Community**: [HashiCorp Discuss](https://discuss.hashicorp.com/)

## 🚀 What's Next?

After deployment, consider these enhancements:

- [ ] Set up monitoring and alerting
- [ ] Implement secret backup procedures  
- [ ] Add CI/CD pipeline integration
- [ ] Configure additional database engines
- [ ] Implement automated testing
- [ ] Set up disaster recovery procedures

---

**Happy Vault-ing! 🔐**