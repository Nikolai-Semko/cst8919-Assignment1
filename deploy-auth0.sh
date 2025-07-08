#!/bin/bash

# Azure deployment script for Auth0 Flask application
# Make sure Azure CLI is installed and you are logged in (az login)

# Colored output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Check Azure CLI
if ! command -v az &> /dev/null; then
    error "Azure CLI is not installed. Install it from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

# Check Azure login
if ! az account show &> /dev/null; then
    error "You are not logged into Azure. Run 'az login'"
    exit 1
fi

# Configuration (change these values as needed)
RESOURCE_GROUP="rg-auth0-security-lab"
LOCATION="canadacentral"
APP_SERVICE_PLAN="asp-auth0-security-lab"
WEBAPP_NAME="auth0-security-lab-$(whoami)-$(date +%Y%m%d%H%M)"
WORKSPACE_NAME="law-auth0-security-lab"

log "Starting Auth0 Flask App deployment..."
log "Resource Group: $RESOURCE_GROUP"
log "Location: $LOCATION"
log "Web App Name: $WEBAPP_NAME"

# Step 1: Create Resource Group
log "Creating Resource Group..."
az group create \
    --name $RESOURCE_GROUP \
    --location $LOCATION

if [ $? -eq 0 ]; then
    log "Resource Group created successfully"
else
    error "Error creating Resource Group"
    exit 1
fi

# Step 2: Create App Service Plan
log "Creating App Service Plan..."
az appservice plan create \
    --name $APP_SERVICE_PLAN \
    --resource-group $RESOURCE_GROUP \
    --sku B1 \
    --is-linux

if [ $? -eq 0 ]; then
    log "App Service Plan created successfully"
else
    error "Error creating App Service Plan"
    exit 1
fi

# Step 3: Create Web App
log "Creating Web App..."
az webapp create \
    --resource-group $RESOURCE_GROUP \
    --plan $APP_SERVICE_PLAN \
    --name $WEBAPP_NAME \
    --runtime "PYTHON|3.9"

if [ $? -eq 0 ]; then
    log "Web App created successfully"
else
    error "Error creating Web App"
    exit 1
fi

# Step 4: Configure startup file
log "Configuring startup file..."
az webapp config set \
    --resource-group $RESOURCE_GROUP \
    --name $WEBAPP_NAME \
    --startup-file "startup.py"

# Step 5: Create Log Analytics Workspace
log "Creating Log Analytics Workspace..."
az monitor log-analytics workspace create \
    --resource-group $RESOURCE_GROUP \
    --workspace-name $WORKSPACE_NAME \
    --location $LOCATION

if [ $? -eq 0 ]; then
    log "Log Analytics Workspace created successfully"
else
    error "Error creating Log Analytics Workspace"
    exit 1
fi

# Step 6: Configure environment variables for Auth0
warn "You need to configure Auth0 environment variables manually in Azure Portal:"
echo "Go to: https://portal.azure.com -> App Services -> $WEBAPP_NAME -> Configuration"
echo "Add these application settings:"
echo "- AUTH0_CLIENT_ID: <your_auth0_client_id>"
echo "- AUTH0_CLIENT_SECRET: <your_auth0_client_secret>"
echo "- AUTH0_DOMAIN: <your_auth0_domain>"
echo "- APP_SECRET_KEY: <generate_random_secret_key>"
echo ""

# Step 7: Code deployment
if [ -f "server.py" ]; then
    log "Creating ZIP archive for deployment..."
    
    # Create temporary folder for archive
    mkdir -p temp_deploy
    
    # Copy necessary files
    cp server.py temp_deploy/
    cp startup.py temp_deploy/
    cp requirements.txt temp_deploy/
    
    # Copy templates if they exist
    if [ -d "templates" ]; then
        cp -r templates temp_deploy/
    else
        warn "templates directory not found. Make sure to create home.html and protected.html"
    fi
    
    # Create ZIP archive
    cd temp_deploy
    zip -r ../deploy.zip .
    cd ..
    
    log "Deploying code to Azure..."
    az webapp deployment source config-zip \
        --resource-group $RESOURCE_GROUP \
        --name $WEBAPP_NAME \
        --src deploy.zip
    
    if [ $? -eq 0 ]; then
        log "Code deployed successfully"
    else
        error "Error deploying code"
        exit 1
    fi
    
    # Clean up temporary files
    rm -rf temp_deploy deploy.zip
else
    warn "server.py file not found. Code deployment skipped."
fi

# Step 8: Configure monitoring
log "Configuring monitoring..."

# Get resource IDs
WEBAPP_ID=$(az webapp show \
    --resource-group $RESOURCE_GROUP \
    --name $WEBAPP_NAME \
    --query id \
    --output tsv)

WORKSPACE_ID=$(az monitor log-analytics workspace show \
    --resource-group $RESOURCE_GROUP \
    --workspace-name $WORKSPACE_NAME \
    --query id \
    --output tsv)

# Create diagnostic setting
az monitor diagnostic-settings create \
    --name auth0-security-monitoring \
    --resource $WEBAPP_ID \
    --workspace $WORKSPACE_ID \
    --logs '[
        {
            "category": "AppServiceConsoleLogs",
            "enabled": true
        },
        {
            "category": "AppServiceHTTPLogs", 
            "enabled": true
        }
    ]'

if [ $? -eq 0 ]; then
    log "Monitoring configured successfully"
else
    warn "Possible issues with monitoring configuration"
fi

# Final information
log "Deployment completed!"
echo ""
echo "📋 Deployment Information:"
echo "=================================="
echo "Resource Group: $RESOURCE_GROUP"
echo "Web App Name: $WEBAPP_NAME"
echo "Web App URL: https://$WEBAPP_NAME.azurewebsites.net"
echo "Log Analytics Workspace: $WORKSPACE_NAME"
echo ""
echo "🔧 IMPORTANT: Configure Auth0 environment variables:"
echo "1. Go to Azure Portal -> App Services -> $WEBAPP_NAME -> Configuration"
echo "2. Add the Auth0 environment variables (see instructions above)"
echo "3. Restart the web app after adding environment variables"
echo ""
echo "🚀 Next steps:"
echo "1. Configure Auth0 environment variables in Azure Portal"
echo "2. Update Auth0 callback URL to: https://$WEBAPP_NAME.azurewebsites.net/callback"
echo "3. Test the application at: https://$WEBAPP_NAME.azurewebsites.net"
echo "4. Wait 5-10 minutes for logs to appear in Azure Monitor"
echo "5. Create Alert Rules using the provided KQL queries"
echo ""
echo "🔍 Useful commands:"
echo "View logs: az webapp log tail --resource-group $RESOURCE_GROUP --name $WEBAPP_NAME"
echo "App status: az webapp show --resource-group $RESOURCE_GROUP --name $WEBAPP_NAME --query state"
echo ""
echo "🗑️  To delete all resources:"
echo "az group delete --name $RESOURCE_GROUP --yes --no-wait"