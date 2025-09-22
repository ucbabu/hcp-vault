#!/bin/bash

# Quick OIDC Extractor for AKS
# Simple script to quickly get OIDC issuer URL from AKS

set -e

# Check if required parameters are provided
if [ $# -lt 2 ]; then
    echo "Usage: $0 <resource-group> <cluster-name> [subscription-id]"
    echo ""
    echo "Quick extraction of OIDC issuer URL from AKS cluster"
    echo ""
    echo "Examples:"
    echo "  $0 myResourceGroup myAKSCluster"
    echo "  $0 myRG myCluster 12345678-1234-1234-1234-123456789012"
    exit 1
fi

RESOURCE_GROUP="$1"
CLUSTER_NAME="$2"
SUBSCRIPTION="$3"

# Set subscription if provided
if [ -n "$SUBSCRIPTION" ]; then
    echo "Setting subscription: $SUBSCRIPTION"
    az account set --subscription "$SUBSCRIPTION"
fi

echo "Getting OIDC information for cluster: $CLUSTER_NAME in resource group: $RESOURCE_GROUP"
echo ""

# Check if OIDC is enabled
OIDC_ENABLED=$(az aks show -g "$RESOURCE_GROUP" -n "$CLUSTER_NAME" --query 'oidcIssuerProfile.enabled' -o tsv 2>/dev/null || echo "false")

if [ "$OIDC_ENABLED" != "true" ]; then
    echo "❌ OIDC issuer is not enabled on this AKS cluster"
    echo ""
    echo "To enable OIDC issuer, run:"
    echo "az aks update -g $RESOURCE_GROUP -n $CLUSTER_NAME --enable-oidc-issuer"
    echo ""
    echo "This operation may take a few minutes..."
    exit 1
fi

# Get OIDC issuer URL
ISSUER_URL=$(az aks show -g "$RESOURCE_GROUP" -n "$CLUSTER_NAME" --query 'oidcIssuerProfile.issuerURL' -o tsv)

if [ -z "$ISSUER_URL" ] || [ "$ISSUER_URL" = "null" ]; then
    echo "❌ Could not retrieve OIDC issuer URL"
    exit 1
fi

echo "✅ OIDC issuer URL: $ISSUER_URL"
echo ""

# Get API server URL
API_URL=$(az aks show -g "$RESOURCE_GROUP" -n "$CLUSTER_NAME" --query 'fqdn' -o tsv)
if [ -n "$API_URL" ]; then
    API_URL="https://$API_URL"
    echo "✅ Kubernetes API URL: $API_URL"
else
    echo "⚠️  Could not retrieve API server URL"
fi

echo ""
echo "📋 Add these to your terraform.tfvars:"
echo ""
echo "jwt_issuer = \"$ISSUER_URL\""
if [ -n "$API_URL" ]; then
    echo "k8s_host = \"$API_URL\""
fi
echo "jwt_bound_audiences = [\"https://kubernetes.default.svc.cluster.local\"]"
echo ""

# Test OIDC discovery
echo "🔍 Testing OIDC discovery endpoint..."
DISCOVERY_URL="${ISSUER_URL}/.well-known/openid_configuration"

if curl -s "$DISCOVERY_URL" > /dev/null; then
    echo "✅ OIDC discovery endpoint is accessible: $DISCOVERY_URL"
    
    # Show some key information from discovery
    echo ""
    echo "📋 OIDC Discovery Information:"
    curl -s "$DISCOVERY_URL" | jq '{
        issuer: .issuer,
        jwks_uri: .jwks_uri,
        supported_signing_algs: .id_token_signing_alg_values_supported
    }' 2>/dev/null || echo "Could not parse discovery document"
else
    echo "❌ OIDC discovery endpoint is not accessible"
fi

echo ""
echo "🚀 Next steps:"
echo "1. Update terraform.tfvars with the values above"
echo "2. Get the CA certificate using: ./get-aks-info.sh -g $RESOURCE_GROUP -n $CLUSTER_NAME"
echo "3. Deploy your Vault configuration"