# QUICK FIX - Execute these commands in order

# 1. Create deployment folder and copy files
mkdir deploy_temp
cp server.py deploy_temp/
cp startup.py deploy_temp/
cp requirements.txt deploy_temp/
cp -r templates deploy_temp/ 2>/dev/null || echo "templates folder not found - create it manually"

# 2. Create ZIP using PowerShell (since zip command not available)
powershell "Compress-Archive -Path 'deploy_temp\*' -DestinationPath 'deploy.zip' -Force"

# 3. Deploy to Azure using the new deploy command
az webapp deploy \
  --resource-group rg-auth0-security-lab \
  --name auth0-security-lab-93823-202507062302 \
  --src-path deploy.zip \
  --type zip

# 4. Clean up
rm -rf deploy_temp
rm deploy.zip

# 5. Configure environment variables (REPLACE WITH YOUR VALUES)
echo "Now configure environment variables in Azure Portal:"
echo "https://portal.azure.com -> App Services -> auth0-security-lab-93823-202507062302 -> Configuration"
echo ""
echo "Add these application settings:"
echo "- AUTH0_CLIENT_ID: your_auth0_client_id"
echo "- AUTH0_CLIENT_SECRET: your_auth0_client_secret" 
echo "- AUTH0_DOMAIN: your_auth0_domain"
echo "- APP_SECRET_KEY: generate_random_key"