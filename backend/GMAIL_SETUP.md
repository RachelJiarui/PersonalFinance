# Gmail API Integration Setup Guide

This guide walks you through setting up Gmail API integration with Pub/Sub for transaction alerts.

## Prerequisites

- Google Cloud Project: `personal-finance-482417`
- Gmail API enabled
- Cloud Pub/Sub API enabled
- Pub/Sub topic created: `projects/personal-finance-482417/topics/gmail-finance-notifs`

## Step 1: Create OAuth 2.0 Client ID

1. Go to [Google Cloud Console - Credentials](https://console.cloud.google.com/apis/credentials?project=personal-finance-482417)
2. Click **"+ CREATE CREDENTIALS"** → **"OAuth client ID"**
3. Choose **"Web application"**
4. Configure:
   - **Name:** `BudgetInsight Gmail Integration`
   - **Authorized redirect URIs:** 
     ```
     https://budgetinsight-backend-ofgbl6d3ea-uc.a.run.app/api/gmail/oauth/callback
     ```
5. Click **Create**
6. Download the credentials JSON or copy the Client ID and Client Secret

## Step 2: Add Credentials to Backend

Add these environment variables to your backend `.env` file:

```bash
GMAIL_CLIENT_ID=your-client-id-here.apps.googleusercontent.com
GMAIL_CLIENT_SECRET=your-client-secret-here
GMAIL_REDIRECT_URI=https://budgetinsight-backend-ofgbl6d3ea-uc.a.run.app/api/gmail/oauth/callback
```

Also add them to Cloud Run environment variables:

```bash
gcloud run services update budgetinsight-backend \
  --region us-central1 \
  --update-env-vars GMAIL_CLIENT_ID=your-client-id-here,GMAIL_CLIENT_SECRET=your-client-secret-here
```

## Step 3: Configure Pub/Sub Push Subscription

Gmail sends notifications to a Pub/Sub topic. You need to create a push subscription that forwards these notifications to your backend webhook.

1. Go to [Pub/Sub Subscriptions](https://console.cloud.google.com/cloudpubsub/subscription/list?project=personal-finance-482417)

2. Click **"CREATE SUBSCRIPTION"**

3. Configure:
   - **Subscription ID:** `gmail-notification-push`
   - **Select a Cloud Pub/Sub topic:** `gmail-finance-notifs`
   - **Delivery type:** Push
   - **Endpoint URL:** 
     ```
     https://budgetinsight-backend-ofgbl6d3ea-uc.a.run.app/api/gmail/pubsub/webhook
     ```
   - **Acknowledgment deadline:** 10 seconds
   - **Message retention duration:** 7 days
   - **Retry policy:** Exponential backoff

4. Click **CREATE**

## Step 4: Grant Gmail Permission to Pub/Sub Topic

Gmail needs permission to publish to your Pub/Sub topic:

```bash
# Get the Gmail API service account (it's always this format)
GMAIL_SERVICE_ACCOUNT="serviceAccount:gmail-api-push@system.gserviceaccount.com"

# Grant publish permission
gcloud pubsub topics add-iam-policy-binding gmail-finance-notifs \
  --member="$GMAIL_SERVICE_ACCOUNT" \
  --role="roles/pubsub.publisher" \
  --project=personal-finance-482417
```

## Step 5: Deploy Updated Backend

Deploy your backend with the new Gmail integration code:

```bash
cd backend
gcloud run deploy budgetinsight-backend \
  --source . \
  --region us-central1 \
  --project personal-finance-482417
```

## Step 6: Test Gmail OAuth Connection

1. Open your iOS app
2. Go to Dashboard → Menu (three dots) → **"Connect Gmail"**
3. You'll be redirected to Google OAuth consent screen
4. Sign in with `rachel.j.chen@gmail.com`
5. Grant permissions to read Gmail
6. You'll be redirected back to the app with URL scheme `budgetinsight://gmail-connected`

The backend will:
- Store your OAuth tokens in Firestore collection `gmail_credentials`
- Set up Gmail watch on your inbox
- Start receiving Pub/Sub notifications

## Step 7: Verify Setup

Check if Gmail watch is active:

```bash
# Check Firestore for stored credentials
# Go to Firestore console and check:
# - Collection: gmail_credentials
# - Document: rachel.j.chen@gmail.com

# Check for watch status
# - Collection: gmail_watch
# - Document: rachel.j.chen@gmail.com
```

## Testing Transaction Alerts

1. Make a transaction with your Discover card
2. Wait for Discover to send the email (usually instant)
3. Gmail will send a Pub/Sub notification to your topic
4. The push subscription will forward it to your webhook
5. The backend will:
   - Fetch the email from Gmail API
   - Parse the transaction details
   - Store as TransactionAlert in Firestore
6. View alerts in the app: Dashboard → Menu → **"Transaction Alerts"**

## Troubleshooting

### No notifications received

1. Check Pub/Sub subscription metrics in console
2. Check Cloud Run logs for webhook calls
3. Verify Gmail watch is still active (expires every 7 days)

### OAuth fails

1. Verify redirect URI matches exactly
2. Check that OAuth client is enabled
3. Verify environment variables are set correctly

### Emails not parsed

1. Check email subject is exactly "Transaction Alert"
2. Check sender is "discover@services.discover.com"
3. Check Cloud Run logs for parsing errors

## Gmail Watch Renewal

Gmail watch expires after 7 days. You'll need to renew it periodically. 

For now, you can manually renew by calling:
```bash
curl -X POST https://budgetinsight-backend-ofgbl6d3ea-uc.a.run.app/api/gmail/renew-watch
```

**TODO:** Implement automatic renewal with Cloud Scheduler.

## Security Notes

- OAuth tokens are stored securely in Firestore
- Only the user `rachel.j.chen@gmail.com` can authenticate
- Gmail API has read-only access (no sending/deleting emails)
- Pub/Sub webhook validates message authenticity
