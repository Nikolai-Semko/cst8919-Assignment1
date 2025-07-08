# Azure Alert Setup Guide

## Creating the Alert Rule for Excessive Protected Route Access

### Step 1: Navigate to Azure Monitor

1. Go to [Azure Portal](https://portal.azure.com)
2. Search for "Monitor" and select "Azure Monitor"
3. In the left sidebar, click on "Alerts"
4. Click "+ Create" → "Alert rule"

### Step 2: Configure Scope

1. Click "Select scope"
2. Filter by "Resource type" → "Log Analytics workspaces"
3. Select your workspace (e.g., `law-auth0-security-lab`)
4. Click "Done"

### Step 3: Configure Condition

1. Click "Select condition"
2. Search for "Custom log search" and select it
3. In the "Search query" field, paste this KQL query:

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

4. Configure the alert logic:
   - **Based on**: Table rows
   - **Operator**: Greater than
   - **Threshold value**: 0
   - **Aggregation granularity (Period)**: 15 minutes
   - **Frequency of evaluation**: 5 minutes

5. Click "Done"

### Step 4: Create Action Group

1. Click "Select action group" → "+ Create action group"
2. **Basics tab**:
   - **Action group name**: `ag-security-alerts`
   - **Display name**: `Security Alerts`
   - **Resource group**: Same as your app (e.g., `rg-auth0-security-lab`)
3. **Actions tab**:
   - **Action type**: Email/SMS message/Push/Voice
   - **Name**: `Email Security Team`
   - **Email**: Your email address
   - Check "Email" and enter your email
4. Click "Review + create" → "Create"

### Step 5: Configure Alert Details

1. **Alert rule details**:
   - **Alert rule name**: `Excessive Protected Route Access`
   - **Description**: `Detects when any user accesses /protected route more than 10 times in 15 minutes`
   - **Severity**: 3 (Low)
   - **Enable alert rule upon creation**: Yes

2. Click "Review + create" → "Create"

## Testing the Alert

### Method 1: Automated Testing Script

Create a bash script to test the alert:

```bash
#!/bin/bash
APP_URL="https://your-app-name.azurewebsites.net"

echo "Testing alert by accessing /protected route 15 times..."
for i in {1..15}; do
    echo "Request $i..."
    curl -L -b cookies.txt -c cookies.txt "$APP_URL/protected"
    sleep 2
done
```

### Method 2: Manual Testing

1. Login to your application
2. Access `/protected` route manually 12+ times within 15 minutes
3. Use browser refresh or the test-app.http file

### Method 3: Using test-app.http

1. Open VS Code with REST Client extension
2. Update the `@base_url` in test-app.http
3. Execute the multiple `/protected` requests rapidly

## Monitoring Alert Status

### Check Alert History

1. Go to Azure Monitor → Alerts
2. View "Alert history" to see triggered alerts
3. Check the "Fired alerts" section

### View Alert Logs

```kql
// Check if alerts are firing
AlertsManagementResources
| where type == "microsoft.alertsmanagement/alerts"
| where properties.essentials.alertRule contains "Excessive"
| project 
    AlertName = properties.essentials.alertRule,
    State = properties.essentials.alertState,
    Severity = properties.essentials.severity,
    FiredTime = properties.essentials.startDateTime,
    Description = properties.essentials.description
| order by FiredTime desc
```

## Troubleshooting

### Alert Not Triggering

1. **Check logs are being generated**:
   ```kql
   AppServiceConsoleLogs
   | where TimeGenerated > ago(1h)
   | where ResultDescription contains "protected_route_access"
   | limit 10
   ```

2. **Verify query syntax**:
   - Test the KQL query directly in Log Analytics
   - Ensure it returns results when conditions are met

3. **Check alert rule configuration**:
   - Verify the scope includes the correct Log Analytics workspace
   - Confirm the threshold and time windows are correct

### Email Not Received

1. **Check Action Group**:
   - Verify email address is correct
   - Check spam/junk folder
   - Test the action group manually

2. **Check email settings**:
   - Go to Action Groups → Your group → Test
   - Send a test notification

### Logs Not Appearing

1. **Verify diagnostic settings**:
   ```bash
   az monitor diagnostic-settings list \
     --resource-id /subscriptions/.../your-webapp
   ```

2. **Check App Service logs**:
   ```bash
   az webapp log tail \
     --resource-group rg-auth0-security-lab \
     --name your-app-name
   ```

## Alert Rule Variations

### High Frequency Alert (More Sensitive)

```kql
AppServiceConsoleLogs
| where TimeGenerated > ago(5m)
| where ResultDescription contains "protected_route_access"
| extend LogData = parse_json(extract("USER_ACTIVITY: ({.*})", 1, ResultDescription))
| extend user_id = tostring(LogData.user_id)
| where user_id != "unknown"
| summarize AccessCount = count() by user_id
| where AccessCount > 5
```

### Failed Login Attempts Alert

```kql
AppServiceConsoleLogs
| where TimeGenerated > ago(10m)
| where ResultDescription contains "login_failure"
| extend LogData = parse_json(extract("USER_ACTIVITY: ({.*})", 1, ResultDescription))
| extend source_ip = tostring(LogData.source_ip)
| summarize FailedAttempts = count() by source_ip
| where FailedAttempts > 3
```

### Unauthorized Access Attempts Alert

```kql
AppServiceConsoleLogs
| where TimeGenerated > ago(30m)
| where ResultDescription contains "unauthorized_access_attempt"
| extend LogData = parse_json(extract("USER_ACTIVITY: ({.*})", 1, ResultDescription))
| extend source_ip = tostring(LogData.source_ip)
| summarize Attempts = count() by source_ip
| where Attempts > 5
```