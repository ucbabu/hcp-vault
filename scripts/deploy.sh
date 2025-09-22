#!/bin/bash

# HCP Vault Deployment Script
# This script helps deploy and configure HCP Vault with Kubernetes integration

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Default values
TERRAFORM_VAR_FILE="${PROJECT_ROOT}/terraform.tfvars"
KUBECTL_CONTEXT=""
DRY_RUN=false
VERBOSE=false

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    local missing_tools=()
    
    if ! command -v terraform &> /dev/null; then
        missing_tools+=("terraform")
    fi
    
    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl")
    fi
    
    if ! command -v vault &> /dev/null; then
        missing_tools+=("vault")
    fi
    
    if ! command -v helm &> /dev/null; then
        missing_tools+=("helm")
    fi
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        echo "Please install the missing tools and try again."
        exit 1
    fi
    
    print_success "All prerequisites are installed"
}

# Function to validate Terraform configuration
validate_terraform() {
    print_status "Validating Terraform configuration..."
    
    if [ ! -f "$TERRAFORM_VAR_FILE" ]; then
        print_error "Terraform variables file not found: $TERRAFORM_VAR_FILE"
        echo "Please copy terraform.tfvars.example to terraform.tfvars and configure it."
        exit 1
    fi
    
    cd "$PROJECT_ROOT"
    
    if ! terraform init -backend=false &> /dev/null; then
        print_error "Terraform initialization failed"
        exit 1
    fi
    
    if ! terraform validate &> /dev/null; then
        print_error "Terraform validation failed"
        terraform validate
        exit 1
    fi
    
    print_success "Terraform configuration is valid"
}

# Function to deploy HCP Vault infrastructure
deploy_vault() {
    print_status "Deploying HCP Vault infrastructure..."
    
    cd "$PROJECT_ROOT"
    
    if [ "$DRY_RUN" = true ]; then
        print_status "Dry run: Planning Terraform deployment..."
        terraform plan -var-file="$TERRAFORM_VAR_FILE"
        return 0
    fi
    
    print_status "Initializing Terraform..."
    terraform init
    
    print_status "Planning Terraform deployment..."
    terraform plan -var-file="$TERRAFORM_VAR_FILE" -out=tfplan
    
    echo
    print_warning "About to deploy HCP Vault infrastructure. This will:"
    echo "  - Create HCP Vault cluster"
    echo "  - Configure KV and Database engines"
    echo "  - Set up JWT/OIDC authentication"
    echo "  - Create policies for each namespace"
    echo
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Applying Terraform configuration..."
        terraform apply tfplan
        rm -f tfplan
        print_success "HCP Vault infrastructure deployed successfully"
    else
        print_warning "Deployment cancelled"
        rm -f tfplan
        exit 0
    fi
}

# Function to get Vault connection info
get_vault_info() {
    cd "$PROJECT_ROOT"
    
    local vault_url=$(terraform output -raw vault_public_endpoint 2>/dev/null)
    local vault_token=$(terraform output -raw vault_admin_token 2>/dev/null)
    
    if [ -z "$vault_url" ] || [ -z "$vault_token" ]; then
        print_error "Could not retrieve Vault connection information"
        echo "Make sure Terraform has been applied successfully"
        exit 1
    fi
    
    echo "export VAULT_ADDR=\"$vault_url\""
    echo "export VAULT_TOKEN=\"$vault_token\""
}

# Function to install Vault Secrets Operator
install_vso() {
    print_status "Installing Vault Secrets Operator..."
    
    # Check if Helm repo exists
    if ! helm repo list | grep -q hashicorp; then
        print_status "Adding HashiCorp Helm repository..."
        helm repo add hashicorp https://helm.releases.hashicorp.com
    fi
    
    helm repo update
    
    # Get Vault URL from Terraform output
    cd "$PROJECT_ROOT"
    local vault_url=$(terraform output -raw vault_public_endpoint 2>/dev/null)
    
    if [ -z "$vault_url" ]; then
        print_error "Could not retrieve Vault URL from Terraform output"
        exit 1
    fi
    
    if [ "$DRY_RUN" = true ]; then
        print_status "Dry run: Would install Vault Secrets Operator with URL: $vault_url"
        return 0
    fi
    
    # Install VSO
    helm upgrade --install vault-secrets-operator hashicorp/vault-secrets-operator \
        --namespace vault-secrets-operator-system \
        --create-namespace \
        --set defaultVaultConnection.enabled=true \
        --set defaultVaultConnection.address="$vault_url" \
        --set defaultVaultConnection.skipTLSVerify=false \
        --wait
    
    print_success "Vault Secrets Operator installed successfully"
}

# Function to setup namespaces
setup_namespaces() {
    print_status "Setting up Kubernetes namespaces..."
    
    cd "$PROJECT_ROOT"
    
    # Get configured namespaces from Terraform
    local namespaces=$(terraform output -json configured_namespaces 2>/dev/null | jq -r 'keys[]')
    
    if [ -z "$namespaces" ]; then
        print_error "Could not retrieve namespace configuration from Terraform"
        exit 1
    fi
    
    # Get Vault connection info
    local vault_url=$(terraform output -raw vault_public_endpoint 2>/dev/null)
    local vault_host=$(echo "$vault_url" | sed 's|https://||' | sed 's|:8200||')
    
    for namespace in $namespaces; do
        local domain=$(terraform output -json configured_namespaces | jq -r ".[\"$namespace\"].domain")
        
        print_status "Setting up namespace: $namespace (domain: $domain)"
        
        if [ "$DRY_RUN" = true ]; then
            print_status "Dry run: Would create namespace $namespace with domain $domain"
            continue
        fi
        
        # Create namespace if it doesn't exist
        if ! kubectl get namespace "$domain" &> /dev/null; then
            kubectl create namespace "$domain"
            kubectl label namespace "$domain" domain="$domain"
        fi
        
        # Apply VSO configuration
        export DOMAIN="$domain"
        export VAULT_ADDR="$vault_url"
        export VAULT_HOST="$vault_host"
        export REDIS_HOST="${REDIS_HOST:-redis-host.example.com}"
        
        envsubst < examples/namespace-template.yaml | kubectl apply -f -
        
        print_success "Namespace $domain configured successfully"
    done
}

# Function to initialize secrets
initialize_secrets() {
    print_status "Initializing secrets in Vault..."
    
    cd "$PROJECT_ROOT"
    
    # Set Vault environment variables
    eval $(get_vault_info)
    
    local namespaces=$(terraform output -json configured_namespaces 2>/dev/null | jq -r 'keys[]')
    
    for namespace in $namespaces; do
        local domain=$(terraform output -json configured_namespaces | jq -r ".[\"$namespace\"].domain")
        
        print_status "Initializing secrets for domain: $domain"
        
        if [ "$DRY_RUN" = true ]; then
            print_status "Dry run: Would initialize secrets for domain $domain"
            continue
        fi
        
        # Create basic app configuration
        vault kv put secret/${domain}/app-config \
            log_level="info" \
            environment="$domain" \
            debug="false" || true
        
        # Create database configuration
        vault kv put secret/${domain}/database/postgres \
            host="${domain}-postgres.example.com" \
            port="5432" \
            database="${domain}_app" \
            ssl_mode="require" || true
        
        # Create certificates placeholder
        vault kv put secret/${domain}/certificates/app \
            certificate="# Certificate will be stored here" \
            private_key="# Private key will be stored here" || true
        
        print_success "Secrets initialized for domain: $domain"
    done
}

# Function to test the setup
test_setup() {
    print_status "Testing the setup..."
    
    cd "$PROJECT_ROOT"
    
    # Check Vault connectivity
    eval $(get_vault_info)
    
    if ! vault status &> /dev/null; then
        print_error "Cannot connect to Vault"
        exit 1
    fi
    
    print_success "Vault connectivity: OK"
    
    # Check VSO
    if ! kubectl get pods -n vault-secrets-operator-system | grep -q Running; then
        print_error "Vault Secrets Operator is not running"
        exit 1
    fi
    
    print_success "Vault Secrets Operator: OK"
    
    # Check namespaces
    local namespaces=$(terraform output -json configured_namespaces 2>/dev/null | jq -r 'keys[]')
    
    for namespace in $namespaces; do
        local domain=$(terraform output -json configured_namespaces | jq -r ".[\"$namespace\"].domain")
        
        if ! kubectl get namespace "$domain" &> /dev/null; then
            print_error "Namespace $domain does not exist"
            exit 1
        fi
        
        # Check if VaultAuth resource exists
        if ! kubectl get vaultauth vault-auth -n "$domain" &> /dev/null; then
            print_error "VaultAuth resource not found in namespace $domain"
            exit 1
        fi
        
        print_success "Namespace $domain: OK"
    done
    
    print_success "All tests passed!"
}

# Function to show usage
usage() {
    echo "Usage: $0 [OPTIONS] COMMAND"
    echo
    echo "Commands:"
    echo "  deploy          Deploy HCP Vault infrastructure"
    echo "  install-vso     Install Vault Secrets Operator"
    echo "  setup-ns        Setup Kubernetes namespaces"
    echo "  init-secrets    Initialize secrets in Vault"
    echo "  test            Test the setup"
    echo "  all             Run all commands in sequence"
    echo "  vault-info      Show Vault connection information"
    echo
    echo "Options:"
    echo "  -f, --var-file FILE     Terraform variables file (default: terraform.tfvars)"
    echo "  -c, --context CONTEXT   Kubectl context to use"
    echo "  -d, --dry-run          Dry run mode (don't make changes)"
    echo "  -v, --verbose          Verbose output"
    echo "  -h, --help             Show this help message"
    echo
    echo "Examples:"
    echo "  $0 deploy                    # Deploy Vault infrastructure"
    echo "  $0 --dry-run all            # Dry run all steps"
    echo "  $0 -f custom.tfvars deploy  # Use custom variables file"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--var-file)
            TERRAFORM_VAR_FILE="$2"
            shift 2
            ;;
        -c|--context)
            KUBECTL_CONTEXT="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        deploy|install-vso|setup-ns|init-secrets|test|all|vault-info)
            COMMAND="$1"
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Set kubectl context if specified
if [ -n "$KUBECTL_CONTEXT" ]; then
    kubectl config use-context "$KUBECTL_CONTEXT"
fi

# Execute command
case "${COMMAND:-}" in
    deploy)
        check_prerequisites
        validate_terraform
        deploy_vault
        ;;
    install-vso)
        check_prerequisites
        install_vso
        ;;
    setup-ns)
        check_prerequisites
        setup_namespaces
        ;;
    init-secrets)
        check_prerequisites
        initialize_secrets
        ;;
    test)
        check_prerequisites
        test_setup
        ;;
    all)
        check_prerequisites
        validate_terraform
        deploy_vault
        install_vso
        setup_namespaces
        initialize_secrets
        test_setup
        print_success "Complete setup finished successfully!"
        echo
        print_status "To get Vault connection info, run:"
        echo "  $0 vault-info"
        ;;
    vault-info)
        get_vault_info
        ;;
    *)
        print_error "No command specified"
        usage
        exit 1
        ;;
esac