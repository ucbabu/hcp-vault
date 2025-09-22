#!/bin/bash

# AKS OIDC Enablement Script
# This script enables OIDC issuer on an existing AKS cluster

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check if required parameters are provided
if [ $# -lt 2 ]; then
    echo "Usage: $0 <resource-group> <cluster-name> [subscription-id]"
    echo ""
    echo "Enable OIDC issuer on an existing AKS cluster"
    echo ""
    echo "Parameters:"
    echo "  resource-group   Azure resource group containing the AKS cluster"
    echo "  cluster-name     Name of the AKS cluster"
    echo "  subscription-id  (Optional) Azure subscription ID"
    echo ""
    echo "Examples:"
    echo "  $0 myResourceGroup myAKSCluster"
    echo "  $0 myRG myCluster 12345678-1234-1234-1234-123456789012"
    echo ""
    echo "Note: This operation requires AKS cluster update permissions"
    exit 1
fi

RESOURCE_GROUP="$1"
CLUSTER_NAME="$2"
SUBSCRIPTION="$3"

print_status "AKS OIDC Enablement Script"
print_status "Resource Group: $RESOURCE_GROUP"
print_status "Cluster Name: $CLUSTER_NAME"

# Check Azure CLI
if ! command -v az &> /dev/null; then
    print_error "Azure CLI is not installed"
    echo "Please install Azure CLI: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

# Check login
if ! az account show &> /dev/null; then
    print_error "Not logged in to Azure"
    echo "Please run: az login"
    exit 1
fi

# Set subscription if provided
if [ -n "$SUBSCRIPTION" ]; then
    print_status "Setting subscription: $SUBSCRIPTION"
    az account set --subscription "$SUBSCRIPTION"
fi

# Check if cluster exists
print_status "Checking if AKS cluster exists..."
if ! az aks show -g "$RESOURCE_GROUP" -n "$CLUSTER_NAME" &> /dev/null; then
    print_error "AKS cluster '$CLUSTER_NAME' not found in resource group '$RESOURCE_GROUP'"
    
    # List available clusters
    print_status "Available AKS clusters in resource group '$RESOURCE_GROUP':"
    az aks list -g "$RESOURCE_GROUP" --query '[].name' -o table 2>/dev/null || echo "No AKS clusters found"
    exit 1
fi

print_success "AKS cluster found"

# Check current OIDC status
print_status "Checking current OIDC issuer status..."
OIDC_ENABLED=$(az aks show -g "$RESOURCE_GROUP" -n "$CLUSTER_NAME" --query 'oidcIssuerProfile.enabled' -o tsv 2>/dev/null || echo "false")
CURRENT_ISSUER=$(az aks show -g "$RESOURCE_GROUP" -n "$CLUSTER_NAME" --query 'oidcIssuerProfile.issuerURL' -o tsv 2>/dev/null || echo "")

if [ "$OIDC_ENABLED" = "true" ] && [ -n "$CURRENT_ISSUER" ] && [ "$CURRENT_ISSUER" != "null" ]; then
    print_success "OIDC issuer is already enabled!"
    print_success "Current issuer URL: $CURRENT_ISSUER"
    
    echo ""
    print_status "OIDC configuration ready. You can now:"
    echo "1. Use the issuer URL in your Vault configuration: $CURRENT_ISSUER"
    echo "2. Run the get-aks-info.sh script to get the complete configuration"
    echo "3. Test the OIDC discovery endpoint: curl $CURRENT_ISSUER/.well-known/openid_configuration"
    exit 0
fi

print_warning "OIDC issuer is not enabled on this cluster"

# Get cluster information
print_status "Getting cluster information..."
CLUSTER_INFO=$(az aks show -g "$RESOURCE_GROUP" -n "$CLUSTER_NAME" --query '{
    kubernetesVersion: kubernetesVersion,
    location: location,
    nodeResourceGroup: nodeResourceGroup,
    powerState: powerState.code
}')

echo "Cluster details:"
echo "$CLUSTER_INFO" | jq .

POWER_STATE=$(echo "$CLUSTER_INFO" | jq -r '.powerState')
if [ "$POWER_STATE" != "Running" ]; then
    print_error "Cluster is not in running state: $POWER_STATE"
    echo "Please start the cluster first: az aks start -g $RESOURCE_GROUP -n $CLUSTER_NAME"
    exit 1
fi

# Confirm enablement
echo ""
print_warning "About to enable OIDC issuer on AKS cluster '$CLUSTER_NAME'"
print_warning "This operation will:"
echo "  - Update the cluster configuration"
echo "  - May cause a brief interruption to cluster operations"
echo "  - Take several minutes to complete"
echo ""

read -p "Do you want to continue? (y/N): " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_status "Operation cancelled"
    exit 0
fi

# Enable OIDC issuer
print_status "Enabling OIDC issuer on AKS cluster..."
print_status "This may take 5-10 minutes. Please wait..."

if az aks update -g "$RESOURCE_GROUP" -n "$CLUSTER_NAME" --enable-oidc-issuer --no-wait; then
    print_success "OIDC issuer enablement initiated"
    
    print_status "Waiting for operation to complete..."
    
    # Wait for the operation to complete
    local attempts=0
    local max_attempts=30  # 15 minutes max
    
    while [ $attempts -lt $max_attempts ]; do
        sleep 30
        attempts=$((attempts + 1))
        
        OIDC_STATUS=$(az aks show -g "$RESOURCE_GROUP" -n "$CLUSTER_NAME" --query 'oidcIssuerProfile.enabled' -o tsv 2>/dev/null || echo "false")
        ISSUER_URL=$(az aks show -g "$RESOURCE_GROUP" -n "$CLUSTER_NAME" --query 'oidcIssuerProfile.issuerURL' -o tsv 2>/dev/null || echo "")
        
        if [ "$OIDC_STATUS" = "true" ] && [ -n "$ISSUER_URL" ] && [ "$ISSUER_URL" != "null" ]; then
            print_success "OIDC issuer successfully enabled!"
            print_success "Issuer URL: $ISSUER_URL"
            break
        fi
        
        print_status "Still in progress... (attempt $attempts/$max_attempts)"
    done
    
    if [ $attempts -eq $max_attempts ]; then
        print_warning "Operation may still be in progress. Check status manually:"
        echo "az aks show -g $RESOURCE_GROUP -n $CLUSTER_NAME --query 'oidcIssuerProfile'"
    fi
    
else
    print_error "Failed to enable OIDC issuer"
    exit 1
fi

# Verify OIDC discovery endpoint
if [ -n "$ISSUER_URL" ] && [ "$ISSUER_URL" != "null" ]; then
    print_status "Testing OIDC discovery endpoint..."
    
    DISCOVERY_URL="${ISSUER_URL}/.well-known/openid_configuration"
    
    if curl -s --max-time 10 "$DISCOVERY_URL" > /dev/null; then
        print_success "OIDC discovery endpoint is accessible"
        
        # Show discovery info
        print_status "OIDC Discovery Information:"
        curl -s "$DISCOVERY_URL" | jq '{
            issuer: .issuer,
            jwks_uri: .jwks_uri,
            supported_signing_algs: .id_token_signing_alg_values_supported
        }' 2>/dev/null || echo "Could not parse discovery document"
    else
        print_warning "OIDC discovery endpoint may not be ready yet"
        print_warning "Try again in a few minutes: curl $DISCOVERY_URL"
    fi
fi

echo ""
print_success "OIDC issuer enablement completed!"
echo ""
print_status "Next steps:"
echo "1. Add to your terraform.tfvars:"
echo "   jwt_issuer = \"$ISSUER_URL\""
echo "   jwt_bound_audiences = [\"https://kubernetes.default.svc.cluster.local\"]"
echo ""
echo "2. Get complete AKS configuration:"
echo "   ./get-aks-info.sh -g $RESOURCE_GROUP -n $CLUSTER_NAME"
echo ""
echo "3. Test OIDC discovery:"
echo "   curl $ISSUER_URL/.well-known/openid_configuration"