# PowerShell deployment script for Windows
# Run with: .\deploy-windows.ps1

Write-Host "🚀 Starting Auth0 Flask App deployment (Windows)..." -ForegroundColor Green

# Check if Azure CLI is installed
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Azure CLI is not installed" -ForegroundColor Red
    Write-Host "Please install from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli" -ForegroundColor Yellow
    exit 1
}

# Check if logged into Azure
$account = az account show 2>$null
if (-not $account) {
    Write-Host "❌ Not logged into Azure. Please run 'az login'" -ForegroundColor Red
    exit 1
}

# Configuration
$RESOURCE_GROUP = "rg-auth0-security-lab"
$LOCATION = "canadacentral" 
$APP_SERVICE_PLAN = "asp-auth0-security-lab"
$WEBAPP_NAME = "auth0-security-lab-93823-202507062302"  # Using your existing name
$WORKSPACE_NAME = "law-auth0-security-lab"

Write-Host "📋 Deployment Information:" -ForegroundColor Cyan
Write-Host "Resource Group: $RESOURCE_GROUP"
Write-Host "Web App Name: $WEBAPP_NAME"
Write-Host "Location: $LOCATION"

# Create deployment package using PowerShell
Write-Host "📦 Creating deployment package..." -ForegroundColor Yellow

# Create temp directory
$tempDir = "temp_deploy_$(Get-Date -Format 'yyyyMMddHHmmss')"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

# Copy files to temp directory
$filesToCopy = @(
    "server.py",
    "startup.py", 
    "requirements.txt"
)

foreach ($file in $filesToCopy) {
    if (Test-Path $file) {
        Copy-Item $file $tempDir
        Write-Host "✅ Copied $file" -ForegroundColor Green
    } else {
        Write-Host "⚠️ File not found: $file" -ForegroundColor Yellow
    }
}

# Copy templates directory if it exists
if (Test-Path "templates") {
    Copy-Item "templates" $tempDir -Recurse
    Write-Host "✅ Copied templates directory" -ForegroundColor Green
} else {
    Write-Host "⚠️ templates directory not found" -ForegroundColor Yellow
}

# Create ZIP archive using PowerShell
$zipPath = "deploy.zip"
if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
}

Write-Host "🗜️ Creating ZIP archive..." -ForegroundColor Yellow
Compress-Archive -Path "$tempDir\*" -DestinationPath $zipPath -Force

if (Test-Path $zipPath) {
    Write-Host "✅ ZIP archive created successfully" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to create ZIP archive" -ForegroundColor Red
    exit 1
}

# Deploy to Azure
Write-Host "☁️ Deploying to Azure..." -ForegroundColor Yellow

$deployResult = az webapp deploy --resource-group $RESOURCE_GROUP --name $WEBAPP_NAME --src-path $zipPath --type zip 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Deployment successful!" -ForegroundColor Green
} else {
    Write-Host "❌ Deployment failed!" -ForegroundColor Red
    Write-Host $deployResult -ForegroundColor Red
}

# Clean up temporary files
Remove-Item $tempDir -Recurse -Force
Remove-Item $zipPath -Force

# Configure monitoring if not already done
Write-Host "🔍 Configuring monitoring..." -ForegroundColor Yellow

$webappId = az webapp show --resource-group $RESOURCE_GROUP --name $WEBAPP_NAME --query id --output tsv
$workspaceId = az monitor log-analytics workspace show --resource-group $RESOURCE_GROUP --workspace-name $WORKSPACE_NAME --query id --output tsv 2>$null

if ($workspaceId) {
    Write-Host "✅ Log Analytics workspace found" -ForegroundColor Green
    
    # Create diagnostic settings
    $diagnosticResult = az monitor diagnostic-settings create --name "auth0-security-monitoring" --resource $webappId --workspace $workspaceId --logs '[{"category":"AppServiceConsoleLogs","enabled":true},{"category":"AppServiceHTTPLogs","enabled":true}]' 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Monitoring configured" -ForegroundColor Green
    } else {
        Write-Host "⚠️ Monitoring configuration may already exist" -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠️ Log Analytics workspace not found" -ForegroundColor Yellow
}

Write-Host "🎉 Deployment process completed!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Next Steps:" -ForegroundColor Cyan
Write-Host "1. Configure Auth0 environment variables in Azure Portal:"
Write-Host "   https://portal.azure.com -> App Services -> $WEBAPP_NAME -> Configuration"
Write-Host ""
Write-Host "2. Add these application settings:"
Write-Host "   - AUTH0_CLIENT_ID: <your_auth0_client_id>"
Write-Host "   - AUTH0_CLIENT_SECRET: <your_auth0_client_secret>"
Write-Host "   - AUTH0_DOMAIN: <your_auth0_domain>"
Write-Host "   - APP_SECRET_KEY: <generate_random_secret_key>"
Write-Host ""
Write-Host "3. Update Auth0 callback URL to:"
Write-Host "   https://$WEBAPP_NAME.azurewebsites.net/callback"
Write-Host ""
Write-Host "4. Test application:"
Write-Host "   https://$WEBAPP_NAME.azurewebsites.net"
Write-Host ""
Write-Host "5. Restart web app after adding environment variables"