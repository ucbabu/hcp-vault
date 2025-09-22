.PHONY: help init plan apply deploy install-vso setup-ns init-secrets test clean destroy vault-info

# Variables
TERRAFORM_VAR_FILE ?= terraform.tfvars
SCRIPT_DIR = scripts

# Default target
help: ## Show this help message
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Terraform targets
init: ## Initialize Terraform
	terraform init

validate: ## Validate Terraform configuration
	terraform validate

plan: ## Plan Terraform deployment
	terraform plan -var-file="$(TERRAFORM_VAR_FILE)"

apply: ## Apply Terraform configuration
	terraform apply -var-file="$(TERRAFORM_VAR_FILE)"

# Full deployment
deploy: ## Deploy HCP Vault infrastructure
	$(SCRIPT_DIR)/deploy.sh deploy

install-vso: ## Install Vault Secrets Operator
	$(SCRIPT_DIR)/deploy.sh install-vso

setup-ns: ## Setup Kubernetes namespaces
	$(SCRIPT_DIR)/deploy.sh setup-ns

init-secrets: ## Initialize secrets in Vault
	$(SCRIPT_DIR)/deploy.sh init-secrets

test: ## Test the complete setup
	$(SCRIPT_DIR)/deploy.sh test

all: ## Deploy everything (infrastructure + VSO + namespaces + secrets)
	$(SCRIPT_DIR)/deploy.sh all

# Utility targets
vault-info: ## Show Vault connection information
	$(SCRIPT_DIR)/deploy.sh vault-info

dry-run: ## Dry run all steps
	$(SCRIPT_DIR)/deploy.sh --dry-run all

# Cleanup targets
clean: ## Clean Terraform temporary files
	rm -f terraform.tfplan
	rm -f .terraform.lock.hcl
	rm -rf .terraform/

destroy: ## Destroy all Terraform resources (WARNING: This will delete everything!)
	@echo "WARNING: This will destroy all resources including the Vault cluster!"
	@echo "All secrets and configurations will be permanently lost!"
	@read -p "Are you sure you want to continue? Type 'yes' to confirm: " confirm && \
	if [ "$$confirm" = "yes" ]; then \
		terraform destroy -var-file="$(TERRAFORM_VAR_FILE)"; \
	else \
		echo "Destruction cancelled."; \
	fi

# Development targets
fmt: ## Format Terraform code
	terraform fmt -recursive

# AKS Setup targets
aks-quick-oidc: ## Quick OIDC extraction from AKS (requires RESOURCE_GROUP and CLUSTER_NAME)
	@if [ -z "$(RESOURCE_GROUP)" ] || [ -z "$(CLUSTER_NAME)" ]; then \
		echo "Usage: make aks-quick-oidc RESOURCE_GROUP=myRG CLUSTER_NAME=myCluster"; \
		exit 1; \
	fi
	$(SCRIPT_DIR)/aks-setup/quick-oidc.sh "$(RESOURCE_GROUP)" "$(CLUSTER_NAME)"

aks-get-config: ## Get complete AKS configuration (requires RESOURCE_GROUP and CLUSTER_NAME)
	@if [ -z "$(RESOURCE_GROUP)" ] || [ -z "$(CLUSTER_NAME)" ]; then \
		echo "Usage: make aks-get-config RESOURCE_GROUP=myRG CLUSTER_NAME=myCluster [OUTPUT_FILE=aks-config.tf]"; \
		exit 1; \
	fi
	@if [ -n "$(OUTPUT_FILE)" ]; then \
		$(SCRIPT_DIR)/aks-setup/get-aks-info.sh -g "$(RESOURCE_GROUP)" -n "$(CLUSTER_NAME)" -f terraform -o "$(OUTPUT_FILE)"; \
	else \
		$(SCRIPT_DIR)/aks-setup/get-aks-info.sh -g "$(RESOURCE_GROUP)" -n "$(CLUSTER_NAME)" -f terraform; \
	fi

aks-enable-oidc: ## Enable OIDC on AKS cluster (requires RESOURCE_GROUP and CLUSTER_NAME)
	@if [ -z "$(RESOURCE_GROUP)" ] || [ -z "$(CLUSTER_NAME)" ]; then \
		echo "Usage: make aks-enable-oidc RESOURCE_GROUP=myRG CLUSTER_NAME=myCluster"; \
		exit 1; \
	fi
	$(SCRIPT_DIR)/aks-setup/enable-oidc.sh "$(RESOURCE_GROUP)" "$(CLUSTER_NAME)"

docs: ## Generate/update documentation
	@echo "Documentation is manually maintained in the docs/ directory"
	@echo "Please review and update:"
	@echo "  - README.md"
	@echo "  - docs/vault-secrets-operator-guide.md"
	@echo "  - docs/multi-namespace-onboarding.md"

check-prerequisites: ## Check if all required tools are installed
	@command -v terraform >/dev/null 2>&1 || { echo "terraform is required but not installed."; exit 1; }
	@command -v kubectl >/dev/null 2>&1 || { echo "kubectl is required but not installed."; exit 1; }
	@command -v vault >/dev/null 2>&1 || { echo "vault CLI is required but not installed."; exit 1; }
	@command -v helm >/dev/null 2>&1 || { echo "helm is required but not installed."; exit 1; }
	@command -v jq >/dev/null 2>&1 || { echo "jq is required but not installed."; exit 1; }
	@echo "All prerequisites are installed ✓"

setup-config: ## Copy and setup configuration file
	@if [ ! -f "$(TERRAFORM_VAR_FILE)" ]; then \
		cp terraform.tfvars.example $(TERRAFORM_VAR_FILE); \
		echo "Configuration file created: $(TERRAFORM_VAR_FILE)"; \
		echo "Please edit this file with your specific values before running 'make deploy'"; \
	else \
		echo "Configuration file already exists: $(TERRAFORM_VAR_FILE)"; \
	fi

# Monitoring and troubleshooting
status: ## Show status of all components
	@echo "=== HCP Vault Status ==="
	@if command -v vault >/dev/null 2>&1; then \
		eval $$($(SCRIPT_DIR)/deploy.sh vault-info 2>/dev/null) && vault status 2>/dev/null || echo "Vault not accessible"; \
	else \
		echo "Vault CLI not installed"; \
	fi
	@echo ""
	@echo "=== Vault Secrets Operator Status ==="
	@kubectl get pods -n vault-secrets-operator-system 2>/dev/null || echo "VSO not found"
	@echo ""
	@echo "=== Configured Namespaces ==="
	@if [ -f ".terraform/terraform.tfstate" ]; then \
		terraform output -json configured_namespaces 2>/dev/null | jq -r 'keys[]' || echo "No namespaces configured"; \
	else \
		echo "Terraform not applied yet"; \
	fi

logs-vso: ## Show Vault Secrets Operator logs
	kubectl logs -n vault-secrets-operator-system deployment/vault-secrets-operator --tail=100 -f

# Example deployments
deploy-example: ## Deploy sample application
	kubectl apply -f examples/sample-app-deployment.yaml

remove-example: ## Remove sample application
	kubectl delete -f examples/sample-app-deployment.yaml --ignore-not-found=true