#!/bin/bash

# AKS OIDC and Certificate Extraction Script
# This script extracts the necessary OIDC issuer URL and certificates from AKS
# for configuring Vault JWT/OIDC authentication

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
RESOURCE_GROUP=""
CLUSTER_NAME=""
SUBSCRIPTION=""
OUTPUT_FORMAT="env"
OUTPUT_FILE=""
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

# Function to show usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Extract OIDC issuer URL and certificates from AKS cluster for Vault configuration"
    echo
    echo "Options:"
    echo "  -g, --resource-group GROUP    Azure resource group name (required)"
    echo "  -n, --cluster-name NAME       AKS cluster name (required)"
    echo "  -s, --subscription SUB        Azure subscription ID (optional)"
    echo "  -f, --format FORMAT           Output format: env|json|terraform (default: env)"
    echo "  -o, --output FILE             Output to file instead of stdout"
    echo "  -v, --verbose                 Verbose output"
    echo "  -h, --help                    Show this help message"
    echo
    echo "Examples:"
    echo "  $0 -g myResourceGroup -n myAKSCluster"
    echo "  $0 -g myRG -n myCluster -f terraform -o aks-config.tf"
    echo "  $0 -g myRG -n myCluster -f json > aks-info.json"
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI (az) is not installed"
        echo "Please install Azure CLI: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
        exit 1
    fi
    
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed"
        echo "Please install kubectl: https://kubernetes.io/docs/tasks/tools/"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        print_error "jq is not installed"
        echo "Please install jq: https://stedolan.github.io/jq/"
        exit 1
    fi
    
    print_success "All prerequisites are installed"
}

# Function to check Azure login
check_azure_login() {
    print_status "Checking Azure login status..."
    
    if ! az account show &> /dev/null; then
        print_error "Not logged in to Azure"
        echo "Please run: az login"
        exit 1
    fi
    
    local current_sub=$(az account show --query id -o tsv)
    print_success "Logged in to Azure (Subscription: $current_sub)"
    
    if [ -n "$SUBSCRIPTION" ] && [ "$SUBSCRIPTION" != "$current_sub" ]; then
        print_status "Switching to subscription: $SUBSCRIPTION"
        az account set --subscription "$SUBSCRIPTION"
    fi
}

# Function to get AKS cluster information
get_aks_info() {
    print_status "Getting AKS cluster information..."
    
    # Check if cluster exists
    if ! az aks show -g "$RESOURCE_GROUP" -n "$CLUSTER_NAME" &> /dev/null; then
        print_error "AKS cluster '$CLUSTER_NAME' not found in resource group '$RESOURCE_GROUP'"
        exit 1
    fi
    
    # Get cluster details
    local cluster_info=$(az aks show -g "$RESOURCE_GROUP" -n "$CLUSTER_NAME" --query '{
        fqdn: fqdn,
        location: location,
        kubernetesVersion: kubernetesVersion,
        oidcIssuerProfile: oidcIssuerProfile,
        resourceGroup: resourceGroup,
        name: name
    }')
    
    if [ "$VERBOSE" = true ]; then
        print_status "Cluster information:"
        echo "$cluster_info" | jq .
    fi
    
    echo "$cluster_info"
}

# Function to get OIDC issuer URL
get_oidc_issuer() {
    print_status "Extracting OIDC issuer URL..."
    
    local cluster_info="$1"
    local oidc_enabled=$(echo "$cluster_info" | jq -r '.oidcIssuerProfile.enabled // false')
    
    if [ "$oidc_enabled" = "false" ] || [ "$oidc_enabled" = "null" ]; then
        print_error "OIDC issuer is not enabled on this AKS cluster"
        echo "To enable OIDC issuer, run:"
        echo "az aks update -g $RESOURCE_GROUP -n $CLUSTER_NAME --enable-oidc-issuer"
        exit 1
    fi
    
    local issuer_url=$(echo "$cluster_info" | jq -r '.oidcIssuerProfile.issuerURL')
    
    if [ "$issuer_url" = "null" ] || [ -z "$issuer_url" ]; then
        print_error "Could not retrieve OIDC issuer URL"
        exit 1
    fi
    
    print_success "OIDC issuer URL: $issuer_url"
    echo "$issuer_url"
}

# Function to get AKS credentials and connect
get_aks_credentials() {
    print_status "Getting AKS credentials..."
    
    # Get AKS credentials
    az aks get-credentials -g "$RESOURCE_GROUP" -n "$CLUSTER_NAME" --overwrite-existing
    
    # Test connection
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to AKS cluster"
        exit 1
    fi
    
    print_success "Successfully connected to AKS cluster"
}

# Function to get Kubernetes CA certificate
get_k8s_ca_cert() {
    print_status "Extracting Kubernetes CA certificate..."
    
    # Get the CA certificate from kubeconfig
    local ca_cert=$(kubectl config view --raw -o json | jq -r '.clusters[] | select(.name | contains("'$CLUSTER_NAME'")) | .cluster."certificate-authority-data"')
    
    if [ "$ca_cert" = "null" ] || [ -z "$ca_cert" ]; then
        print_error "Could not retrieve CA certificate from kubeconfig"
        exit 1
    fi
    
    # Decode base64 and format as PEM
    local ca_cert_pem=$(echo "$ca_cert" | base64 -d)
    
    print_success "CA certificate extracted successfully"
    echo "$ca_cert_pem"
}

# Function to get Kubernetes API server URL
get_k8s_api_url() {
    print_status "Getting Kubernetes API server URL..."
    
    local api_url=$(kubectl config view --raw -o json | jq -r '.clusters[] | select(.name | contains("'$CLUSTER_NAME'")) | .cluster.server')
    
    if [ "$api_url" = "null" ] || [ -z "$api_url" ]; then
        print_error "Could not retrieve API server URL"
        exit 1
    fi
    
    print_success "API server URL: $api_url"
    echo "$api_url"
}

# Function to get OIDC discovery CA certificate
get_oidc_ca_cert() {
    print_status "Getting OIDC discovery CA certificate..."
    
    local issuer_url="$1"
    local discovery_url="${issuer_url}/.well-known/openid_configuration"
    
    # Try to get the CA certificate from the OIDC discovery endpoint
    local ca_cert=""
    
    # Method 1: Try to extract from the issuer URL
    local host=$(echo "$issuer_url" | sed 's|https://||' | sed 's|/.*||')
    
    if command -v openssl &> /dev/null; then
        print_status "Extracting CA certificate from OIDC endpoint..."
        ca_cert=$(echo | openssl s_client -servername "$host" -connect "$host:443" 2>/dev/null | openssl x509 2>/dev/null)
        
        if [ -n "$ca_cert" ]; then
            print_success "OIDC CA certificate extracted successfully"
            echo "$ca_cert"
            return 0
        fi
    fi
    
    print_warning "Could not extract OIDC CA certificate automatically"
    print_warning "For production use, you may need to provide the CA certificate manually"
    echo ""
}

# Function to output in environment variable format
output_env_format() {
    local issuer_url="$1"
    local k8s_api_url="$2"
    local k8s_ca_cert="$3"
    local oidc_ca_cert="$4"
    local cluster_info="$5"
    
    echo "# AKS Configuration for Vault JWT/OIDC Authentication"
    echo "# Generated on: $(date)"
    echo "# Cluster: $CLUSTER_NAME"
    echo "# Resource Group: $RESOURCE_GROUP"
    echo ""
    
    echo "# Kubernetes Configuration"
    echo "export K8S_HOST=\"$k8s_api_url\""
    echo ""
    
    echo "# OIDC Configuration"
    echo "export JWT_ISSUER=\"$issuer_url\""
    echo ""
    
    echo "# Kubernetes CA Certificate"
    echo "export K8S_CA_CERT=\"$(echo "$k8s_ca_cert" | tr '\n' '\\n' | sed 's/$/\\n/' | tr -d '\n' | sed 's/\\n$//')\""
    echo ""
    
    if [ -n "$oidc_ca_cert" ]; then
        echo "# OIDC CA Certificate (optional)"
        echo "export JWT_CA_CERT=\"$(echo "$oidc_ca_cert" | tr '\n' '\\n' | sed 's/$/\\n/' | tr -d '\n' | sed 's/\\n$//')\""
        echo ""
    fi
    
    echo "# Terraform Variables (add to terraform.tfvars)"
    echo "k8s_host = \"$k8s_api_url\""
    echo "jwt_issuer = \"$issuer_url\""
    echo "k8s_ca_cert = <<EOF"
    echo "$k8s_ca_cert"
    echo "EOF"
    
    if [ -n "$oidc_ca_cert" ]; then
        echo "jwt_ca_cert = <<EOF"
        echo "$oidc_ca_cert"
        echo "EOF"
    fi
}

# Function to output in JSON format
output_json_format() {
    local issuer_url="$1"
    local k8s_api_url="$2"
    local k8s_ca_cert="$3"
    local oidc_ca_cert="$4"
    local cluster_info="$5"
    
    jq -n \
        --arg issuer_url "$issuer_url" \
        --arg k8s_api_url "$k8s_api_url" \
        --arg k8s_ca_cert "$k8s_ca_cert" \
        --arg oidc_ca_cert "$oidc_ca_cert" \
        --arg cluster_name "$CLUSTER_NAME" \
        --arg resource_group "$RESOURCE_GROUP" \
        --argjson cluster_info "$cluster_info" \
        '{
            cluster: {
                name: $cluster_name,
                resource_group: $resource_group,
                info: $cluster_info
            },
            kubernetes: {
                api_url: $k8s_api_url,
                ca_certificate: $k8s_ca_cert
            },
            oidc: {
                issuer_url: $issuer_url,
                ca_certificate: $oidc_ca_cert
            },
            terraform_vars: {
                k8s_host: $k8s_api_url,
                jwt_issuer: $issuer_url,
                k8s_ca_cert: $k8s_ca_cert,
                jwt_ca_cert: $oidc_ca_cert
            }
        }'
}

# Function to output in Terraform format
output_terraform_format() {
    local issuer_url="$1"
    local k8s_api_url="$2"
    local k8s_ca_cert="$3"
    local oidc_ca_cert="$4"
    local cluster_info="$5"
    
    echo "# AKS Configuration Variables"
    echo "# Generated on: $(date)"
    echo "# Cluster: $CLUSTER_NAME"
    echo "# Resource Group: $RESOURCE_GROUP"
    echo ""
    
    echo "# Kubernetes API Server URL"
    echo "k8s_host = \"$k8s_api_url\""
    echo ""
    
    echo "# JWT/OIDC Issuer URL"
    echo "jwt_issuer = \"$issuer_url\""
    echo ""
    
    echo "# Kubernetes CA Certificate"
    echo "k8s_ca_cert = <<EOF"
    echo "$k8s_ca_cert"
    echo "EOF"
    echo ""
    
    if [ -n "$oidc_ca_cert" ]; then
        echo "# OIDC CA Certificate (optional)"
        echo "jwt_ca_cert = <<EOF"
        echo "$oidc_ca_cert"
        echo "EOF"
        echo ""
    fi
    
    echo "# JWT Bound Audiences"
    echo "jwt_bound_audiences = [\"https://kubernetes.default.svc.cluster.local\"]"
}

# Function to save service account configuration
save_service_account_config() {
    local output_dir="aks-config"
    
    print_status "Creating service account configuration..."
    
    mkdir -p "$output_dir"
    
    cat > "$output_dir/service-account.yaml" << EOF
# Service Account for Vault Secrets Operator
# Apply this to each namespace that will use Vault
apiVersion: v1
kind: ServiceAccount
metadata:
  name: vault-secrets-operator
  namespace: \${NAMESPACE}
  annotations:
    # Uncomment if using Azure Workload Identity
    # azure.workload.identity/client-id: "your-client-id"
automountServiceAccountToken: true
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: vault-secrets-operator-\${NAMESPACE}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:auth-delegator
subjects:
- kind: ServiceAccount
  name: vault-secrets-operator
  namespace: \${NAMESPACE}
EOF

    cat > "$output_dir/test-jwt-token.sh" << 'EOF'
#!/bin/bash

# Test JWT token generation
NAMESPACE=${1:-default}
SERVICE_ACCOUNT=${2:-vault-secrets-operator}

echo "Generating JWT token for service account: $SERVICE_ACCOUNT in namespace: $NAMESPACE"

# Create token with 1 hour duration
TOKEN=$(kubectl create token "$SERVICE_ACCOUNT" -n "$NAMESPACE" --duration=3600s)

echo "JWT Token:"
echo "$TOKEN"
echo ""

# Decode and display token payload
echo "Token payload (decoded):"
echo "$TOKEN" | cut -d'.' -f2 | base64 -d 2>/dev/null | jq . || echo "Could not decode token payload"
EOF

    chmod +x "$output_dir/test-jwt-token.sh"
    
    print_success "Service account configuration saved to $output_dir/"
}

# Main execution function
main() {
    check_prerequisites
    check_azure_login
    
    # Get AKS information
    local cluster_info=$(get_aks_info)
    local issuer_url=$(get_oidc_issuer "$cluster_info")
    
    # Get AKS credentials and connect
    get_aks_credentials
    
    # Extract certificates and URLs
    local k8s_api_url=$(get_k8s_api_url)
    local k8s_ca_cert=$(get_k8s_ca_cert)
    local oidc_ca_cert=$(get_oidc_ca_cert "$issuer_url")
    
    # Generate output
    local output=""
    case "$OUTPUT_FORMAT" in
        env)
            output=$(output_env_format "$issuer_url" "$k8s_api_url" "$k8s_ca_cert" "$oidc_ca_cert" "$cluster_info")
            ;;
        json)
            output=$(output_json_format "$issuer_url" "$k8s_api_url" "$k8s_ca_cert" "$oidc_ca_cert" "$cluster_info")
            ;;
        terraform)
            output=$(output_terraform_format "$issuer_url" "$k8s_api_url" "$k8s_ca_cert" "$oidc_ca_cert" "$cluster_info")
            ;;
        *)
            print_error "Unknown output format: $OUTPUT_FORMAT"
            exit 1
            ;;
    esac
    
    # Output results
    if [ -n "$OUTPUT_FILE" ]; then
        echo "$output" > "$OUTPUT_FILE"
        print_success "Configuration saved to: $OUTPUT_FILE"
    else
        echo "$output"
    fi
    
    # Save additional configurations
    save_service_account_config
    
    print_success "AKS information extraction completed!"
    echo ""
    print_status "Next steps:"
    echo "1. Update your terraform.tfvars with the generated configuration"
    echo "2. Apply the service account configuration: kubectl apply -f aks-config/service-account.yaml"
    echo "3. Test JWT token generation: ./aks-config/test-jwt-token.sh"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -g|--resource-group)
            RESOURCE_GROUP="$2"
            shift 2
            ;;
        -n|--cluster-name)
            CLUSTER_NAME="$2"
            shift 2
            ;;
        -s|--subscription)
            SUBSCRIPTION="$2"
            shift 2
            ;;
        -f|--format)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Validate required parameters
if [ -z "$RESOURCE_GROUP" ] || [ -z "$CLUSTER_NAME" ]; then
    print_error "Resource group and cluster name are required"
    usage
    exit 1
fi

# Validate output format
if [[ ! "$OUTPUT_FORMAT" =~ ^(env|json|terraform)$ ]]; then
    print_error "Invalid output format: $OUTPUT_FORMAT. Must be env, json, or terraform"
    exit 1
fi

# Run main function
main