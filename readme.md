# Assignment 1: Securing and Monitoring an Authenticated Flask App

## Overview

This project combines Auth0 authentication (Lab 1) with Azure monitoring capabilities (Lab 2) to create a production-ready secure Flask application with comprehensive logging and threat detection.

## 🎯 YouTube Demo

🔗 **[YouTube Demo Link](https://youtu.be/czheHCp6_ZI)**

## 🏗️ Architecture

```
User → Auth0 (SSO) → Flask App (Azure App Service) → Azure Monitor/Log Analytics
                                     ↓
                              Structured Logging
                                     ↓
                            KQL Queries & Alerts
```

## 🔧 Setup Instructions

### Prerequisites

- Azure CLI installed and configured (`az login`)
- Auth0 account with application configured
- Python 3.9+
- Git

### 1. Clone and Configure

```bash
git clone <your-repo-url>
cd <your-repo-name>
```

### 2. Auth0 Configuration

1. Create an Auth0 application at [auth0.com](https://auth0.com)
2. Configure the following in your Auth0 application:
   - **Application Type**: Regular Web Application
   - **Allowed Callback URLs**: `https://your-app-name.azurewebsites.net/callback`
   - **Allowed Logout URLs**: `https://your-app-name.azurewebsites.net/`

### 3. Environment Variables

Create a `.env` file locally for testing:

```bash
AUTH0_CLIENT_ID=your_auth0_client_id
AUTH0_CLIENT_SECRET=your_auth0_client_secret
AUTH0_DOMAIN=your_auth0_domain
APP_SECRET_KEY=your_random_secret_key
FLASK_DEBUG=True
```

### 4. Local Development

```bash
# Install dependencies
pip install -r requirements.txt

# Run locally
python server.py
```

### 5. Azure Deployment

```bash
# Make deployment script executable
chmod +x deploy-auth0.sh

# Deploy to Azure
./deploy-auth0.sh
```

**Important**: After deployment, configure environment variables in Azure Portal:
1. Go to Azure Portal → App Services → Your App → Configuration
2. Add all Auth0 environment variables
3. Restart the web app

## 📊 Logging Strategy

### Structured Logging Implementation

The application logs the following user activities as structured JSON:

```json
{
  "timestamp": "2025-07-06T12:00:00Z",
  "activity_type": "protected_route_access",
  "user_id": "auth0|user123",
  "user_email": "user@example.com",
  "source_ip": "192.168.1.1",
  "endpoint": "/protected",
  "url": "https://app.azurewebsites.net/protected"
}
```

### Logged Activities

1. **Login Attempts** - Every Auth0 login initiation
2. **Login Success** - Successful authentication callbacks
3. **Login Failures** - Failed authentication attempts
4. **Protected Route Access** - Access to `/protected` endpoint
5. **Unauthorized Access** - Attempts to access protected routes without authentication
6. **Logout Events** - User logout activities

## 🔍 Detection Logic

### Primary Alert: Excessive Protected Route Access

**Trigger**: Any user accessing `/protected` route more than **10 times** in **15 minutes**

**Business Justification**: 
- Normal user behavior shouldn't require frequent access to the same protected resource
- Could indicate automated attacks, session hijacking, or credential stuffing
- Early detection prevents potential data exfiltration

### KQL Query for Alert

```kql
AppServiceConsoleLogs
| where TimeGenerated > ago(15m)
| where ResultDescription contains "USER_ACTIVITY"
| where ResultDescription contains "protected_route_access"
| extend LogData = parse_json(extract("USER_ACTIVITY: ({.*})", 1, ResultDescription))
| extend user_id = tostring(LogData.user_id)
| extend user_email = tostring(LogData.user_email)
| where user_id != "unknown"
| summarize AccessCount = count() by user_id, user_email
| where AccessCount > 10
```

## 🚨 Azure Alert Configuration

### Alert Rule Settings

- **Name**: "Excessive Protected Route Access"
- **Scope**: Log Analytics Workspace
- **Condition**: Table rows > 0
- **Evaluation Frequency**: 5 minutes
- **Aggregation Granularity**: 15 minutes
- **Severity**: 3 (Low)

### Action Group

- **Type**: Email notification
- **Recipients**: Your email address
- **Subject**: "Security Alert: Suspicious Activity Detected"

## 🧪 Testing the Application

### Using test-app.http

1. Update `@base_url` in `test-app.http` with your Azure app URL
2. Use VS Code with REST Client extension
3. Execute requests to test functionality

### Simulating Alert Conditions

1. Login to the application via Auth0
2. Access `/protected` route multiple times rapidly (>10 times in 15 minutes)
3. Monitor Azure Log Analytics for the activity
4. Wait for email alert notification

### Manual Testing Steps

```bash
# 1. Test basic functionality
curl https://your-app-name.azurewebsites.net/health

# 2. Access home page
curl https://your-app-name.azurewebsites.net/

# 3. Try protected route (should redirect to Auth0)
curl -L https://your-app-name.azurewebsites.net/protected
```

## 📈 Monitoring Queries

### Additional KQL Queries

1. **Login Activity Analysis**
```kql
AppServiceConsoleLogs
| where TimeGenerated > ago(1h)
| where ResultDescription contains "login"
| extend LogData = parse_json(extract("USER_ACTIVITY: ({.*})", 1, ResultDescription))
| summarize LoginAttempts = count() by tostring(LogData.user_email)
```

2. **Failed Authentication Attempts**
```kql
AppServiceConsoleLogs
| where TimeGenerated > ago(2h)
| where ResultDescription contains "login_failure"
| extend LogData = parse_json(extract("USER_ACTIVITY: ({.*})", 1, ResultDescription))
| summarize Failures = count() by tostring(LogData.source_ip)
```

3. **Unauthorized Access Attempts**
```kql
AppServiceConsoleLogs
| where TimeGenerated > ago(2h)
| where ResultDescription contains "unauthorized_access_attempt"
| extend LogData = parse_json(extract("USER_ACTIVITY: ({.*})", 1, ResultDescription))
| project TimeGenerated, tostring(LogData.source_ip), tostring(LogData.target_route)
```

## 🔐 Security Features

### Implemented Security Measures

1. **SSO Authentication** - Centralized authentication via Auth0
2. **Session Management** - Secure session handling with Flask
3. **Activity Logging** - Comprehensive structured logging
4. **Real-time Monitoring** - Azure Monitor integration
5. **Automated Alerting** - Proactive threat detection
6. **IP Tracking** - Source IP logging for forensics

### Route Protection

- `/` - Public home page
- `/login` - Auth0 authentication initiation
- `/callback` - Auth0 callback handler
- `/logout` - Secure logout with Auth0
- `/protected` - **Authenticated users only**
- `/api/activity` - **Authenticated users only**

## 🛠️ Technical Stack

- **Backend**: Python Flask 2.3.3
- **Authentication**: Auth0 (Authlib 1.2.1)
- **Cloud Platform**: Azure App Service
- **Monitoring**: Azure Monitor + Log Analytics
- **Query Language**: KQL (Kusto Query Language)
- **Deployment**: Azure CLI + Bash scripts

## 📝 Lessons Learned

### What Worked Well

1. **Structured Logging**: JSON-formatted logs made parsing in Azure Monitor straightforward
2. **Auth0 Integration**: Seamless SSO implementation with minimal custom code
3. **Azure Deployment**: Automated deployment scripts reduced manual configuration
4. **KQL Queries**: Powerful analytics capabilities for security monitoring

### Challenges Faced

1. **Environment Variables**: Ensuring all Auth0 credentials were properly configured in Azure
2. **Log Parsing**: Initial difficulties with extracting JSON from Azure log format
3. **Alert Timing**: Fine-tuning alert thresholds to minimize false positives
4. **CORS Issues**: Handling cross-origin requests during testing

### Real-World Improvements

1. **Enhanced Alerting**: Implement multiple severity levels based on threat types
2. **Machine Learning**: Use Azure Sentinel for advanced threat detection
3. **Rate Limiting**: Implement application-level rate limiting
4. **Audit Trails**: Extended logging for compliance requirements
5. **Geographic Analysis**: IP geolocation for suspicious activity detection

## 🔄 Continuous Improvement

### Future Enhancements

1. **Multi-Factor Authentication**: Add MFA requirement for sensitive operations
2. **Role-Based Access Control**: Implement granular permissions
3. **API Rate Limiting**: Prevent API abuse
4. **Advanced Analytics**: Machine learning-based anomaly detection
5. **Compliance Reporting**: Automated security compliance reports

## 📞 Support

For issues or questions:
1. Check Azure App Service logs: `az webapp log tail --resource-group rg-auth0-security-lab --name your-app-name`
2. Verify Auth0 configuration in the Auth0 dashboard
3. Review Azure Monitor logs with provided KQL queries
4. Ensure all environment variables are properly set

## 🧹 Cleanup

To remove all Azure resources:

```bash
az group delete --name rg-auth0-security-lab --yes --no-wait
```

---

**Assignment completed by**: [Your Name]  
**Course**: CST8919  
**Date**: July 6, 2025