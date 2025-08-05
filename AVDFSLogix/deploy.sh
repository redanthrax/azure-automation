#!/bin/bash

# Azure Virtual Desktop with FSLogix Deployment Script (Azure CLI)
# This script deploys AVD resources with FSLogix storage and backup

set -e

# Variables (update these as needed)
SUBSCRIPTION_ID=""
PARAMETERS_FILE="main.parameters.json"
LOCATION="eastus2"
DEPLOYMENT_NAME="avd-fslogix-deployment-$(date +%Y%m%d-%H%M%S)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${CYAN}$1${NC}"
}

print_success() {
    echo -e "${GREEN}$1${NC}"
}

print_warning() {
    echo -e "${YELLOW}$1${NC}"
}

print_error() {
    echo -e "${RED}$1${NC}"
}

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    print_error "Azure CLI is not installed. Please install it first."
    exit 1
fi

# Login to Azure if not already logged in
if ! az account show &> /dev/null; then
    print_warning "Not logged in to Azure. Logging in..."
    az login
fi

# Set subscription if provided
if [ ! -z "$SUBSCRIPTION_ID" ]; then
    print_status "Setting subscription context to: $SUBSCRIPTION_ID"
    az account set --subscription "$SUBSCRIPTION_ID"
fi

# Get current subscription info
CURRENT_SUB=$(az account show --query "name" -o tsv)
CURRENT_SUB_ID=$(az account show --query "id" -o tsv)
print_success "Deploying to subscription: $CURRENT_SUB ($CURRENT_SUB_ID)"

# Validate parameters file exists
if [ ! -f "$PARAMETERS_FILE" ]; then
    print_error "Parameters file '$PARAMETERS_FILE' not found!"
    exit 1
fi

# Deploy the Bicep template
print_status ""
print_status "Starting deployment: $DEPLOYMENT_NAME"
print_status "Template: main.bicep"
print_status "Parameters: $PARAMETERS_FILE"
print_status "Location: $LOCATION"
print_status ""

echo "Deploying resources..."
if az deployment sub create \
    --name "$DEPLOYMENT_NAME" \
    --location "$LOCATION" \
    --template-file "main.bicep" \
    --parameters "@$PARAMETERS_FILE"; then
    
    print_success ""
    print_success "✅ Deployment completed successfully!"
    
    # Get deployment outputs
    OUTPUTS=$(az deployment sub show --name "$DEPLOYMENT_NAME" --query "properties.outputs" -o json 2>/dev/null || echo "{}")
    
    if [ "$OUTPUTS" != "{}" ]; then
        print_status ""
        print_status "📋 Deployment Outputs:"
        echo "$OUTPUTS" | jq -r 'to_entries[] | "  \(.key): \(.value.value)"' 2>/dev/null || echo "  (outputs available in Azure portal)"
    fi
    
    print_status ""
    print_status "📝 Next Steps:"
    echo "1. Configure FSLogix RBAC permissions for user access"
    echo "2. Add users to the application group in Azure portal"
    echo "3. Test AVD connection with FSLogix profile redirection"
    echo "4. Verify backup is working for the file share"
    
else
    print_error "Deployment failed!"
    exit 1
fi
