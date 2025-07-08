# Manual Deployment Guide for Windows

## Option 1: Using PowerShell Script (Recommended)

1. Save the `deploy-windows.ps1` script to your project directory
2. Open PowerShell as Administrator
3. Navigate to your project directory
4. Run the script:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
.\deploy-windows.ps1
```

## Option 2: Manual Deployment via Azure CLI

Since the infrastructure is already created, you just need to deploy the code:

### Step 1: Create ZIP Archive Manually

1. **Create a new folder** called `deploy_temp`
2. **Copy these files** to the folder:
   - `server.py`
   - `startup.py`
   - `requirements.txt`
   - `templates/` (entire folder with home.html and protected.html)

3. **Create ZIP archive**:
   - Right-click the `deploy_temp` folder
   - Select "Send to" → "Compressed (zipped) folder"
   - Rename to `deploy.zip`

### Step 2: Deploy via Azure CLI

```bash
az webapp deploy \
  --resource-group rg-auth0-security-lab \
  --name auth0-security-lab-93823-202507062302 \
  --src-path deploy.zip \
  --type zip
```

## Option 3: Deploy via Azure Portal

1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to your App Service: `auth0-security-lab-93823-202507062302`
3. Go to **Deployment Center**
4. Select **ZIP Deploy**
5. Upload your `deploy.zip` file
6. Click **Deploy**

## Configure Environment Variables

After deployment, you MUST configure environment variables:

### Via Azure Portal:

1. Go to your App Service in Azure Portal
2. Navigate to **Configuration** → **Application settings**
3. Click **+ New application setting** for each:

| Name | Value |
|------|-------|
| `AUTH0_CLIENT_ID` | Your Auth0 Client ID |
| `AUTH0_CLIENT_SECRET` | Your Auth0 Client Secret |
| `AUTH0_DOMAIN` | Your Auth0 Domain (e.g., `dev-example.us.auth0.com`) |
| `APP_SECRET_KEY` | Random secret key (generate with Python) |

### Via Azure CLI:

```bash
# Set Auth0 environment variables
az webapp config appsettings set \
  --resource-group rg-auth0-security-lab \
  --name auth0-security-lab-93823-202507062302 \
  --settings \
    AUTH0_CLIENT_ID="your_client_id" \
    AUTH0_CLIENT_SECRET="your_client_secret" \
    AUTH0_DOMAIN="your_domain.auth0.com" \
    APP_SECRET_KEY="your_random_secret_key"
```

### Generate APP_SECRET_KEY:

```python
import secrets
print(secrets.token_urlsafe(32))
```

## Update Auth0 Configuration

1. Go to [Auth0 Dashboard](https://manage.auth0.com)
2. Navigate to **Applications** → Your application
3. Update **Allowed Callback URLs**:
   ```
   https://auth0-security-lab-93823-202507062302.azurewebsites.net/callback
   ```
4. Update **Allowed Logout URLs**:
   ```
   https://auth0-security-lab-93823-202507062302.azurewebsites.net/
   ```

## Restart the Application

After setting environment variables:

```bash
az webapp restart \
  --resource-group rg-auth0-security-lab \
  --name auth0-security-lab-93823-202507062302
```

## Test the Application

1. **Open the application**:
   https://auth0-security-lab-93823-202507062302.azurewebsites.net

2. **Test authentication**:
   - Click "Login with Auth0"
   - Complete Auth0 login
   - Access protected routes

## Verify Logging

Check if logs are being generated:

```bash
# View real-time logs
az webapp log tail \
  --resource-group rg-auth0-security-lab \
  --name auth0-security-lab-93823-202507062302

# Check Log Analytics
# Go to Azure Portal → Log Analytics → law-auth0-security-lab → Logs
# Run: AppServiceConsoleLogs | where TimeGenerated > ago(1h)
```

## Troubleshooting

### Issue: Application not starting

**Check logs:**
```bash
az webapp log tail --resource-group rg-auth0-security-lab --name auth0-security-lab-93823-202507062302
```

**Common solutions:**
- Ensure all environment variables are set
- Verify `startup.py` is in the root directory
- Check `requirements.txt` format

### Issue: Auth0 redirect error

**Solutions:**
- Verify callback URLs in Auth0 dashboard
- Check AUTH0_DOMAIN format (no https://, no trailing slash)
- Ensure environment variables are correctly set

### Issue: Logs not appearing in Azure Monitor

**Solutions:**
- Wait 5-10 minutes for logs to appear
- Verify diagnostic settings are configured
- Check Log Analytics workspace connection

## File Structure Verification

Your deployment should have this structure:
```
deploy.zip
├── server.py
├── startup.py
├── requirements.txt
└── templates/
    ├── home.html
    └── protected.html
```