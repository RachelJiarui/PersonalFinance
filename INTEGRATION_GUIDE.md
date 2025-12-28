# BudgetInsight Backend Integration Guide

This guide walks you through integrating the Python Flask backend with your iOS BudgetInsight app to enable Gmail push notifications, cloud sync, and persistent storage.

## Overview

The integration consists of:
1. **Python Flask Backend** - Handles Gmail webhooks, Firestore storage, APNs push notifications
2. **iOS App Updates** - BackendService, AppDelegate, push notification handling
3. **Google Cloud Setup** - Pub/Sub, Cloud Run deployment, Firestore database
4. **APNs Setup** - Apple Push Notification certificates

---

## Prerequisites

- Google Cloud Platform account (free tier works)
- Apple Developer Program membership
- Xcode 14+ with iOS 16+ deployment target

---

## Part 1: Google Cloud Setup

### 1.1 Create Google Cloud Project

```bash
# Set project ID
export PROJECT_ID="budgetinsight-backend"

# Create project
gcloud projects create $PROJECT_ID

# Set as active project
gcloud config set project $PROJECT_ID

# Enable billing (required)
# Go to: https://console.cloud.google.com/billing
```

### 1.2 Enable Required APIs

```bash
# Enable APIs
gcloud services enable gmail.googleapis.com
gcloud services enable pubsub.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable containerregistry.googleapis.com
```

### 1.3 Create Service Account

```bash
# Create service account
gcloud iam service-accounts create budgetinsight-backend \
    --display-name="BudgetInsight Backend Service Account"

# Grant permissions
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:budgetinsight-backend@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/pubsub.editor"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:budgetinsight-backend@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/gmail.readonly"

# Download credentials
gcloud iam service-accounts keys create credentials.json \
    --iam-account=budgetinsight-backend@$PROJECT_ID.iam.gserviceaccount.com

# Move to backend directory
mv credentials.json backend/credentials.json
```

### 1.4 Create Pub/Sub Topic and Subscription

```bash
# Create topic for Gmail notifications
gcloud pubsub topics create gmail-notifications

# Create push subscription (update URL after deploying backend)
gcloud pubsub subscriptions create gmail-push-sub \
    --topic=gmail-notifications \
    --push-endpoint=https://YOUR_CLOUD_RUN_URL/webhooks/gmail
```

### 1.5 Create Firestore Database

```bash
# Enable Firestore API
gcloud services enable firestore.googleapis.com

# Firestore setup via Console (easier than CLI)
# 1. Go to https://console.cloud.google.com/firestore
# 2. Click "Create Database"
# 3. Choose "Native mode" (NOT Datastore mode)
# 4. Select location: us-central1 (or closest to you)
# 5. Click "Create"
```

**Important**: Choose "Native mode" for real-time updates and better querying.

### 1.6 Configure Gmail OAuth

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Navigate to "APIs & Services" → "Credentials"
3. Click "Create Credentials" → "OAuth 2.0 Client ID"
4. Choose "iOS" application type
5. Add your app's Bundle ID: `com.yourcompany.BudgetInsight`
6. Download the OAuth client configuration

---

## Part 2: APNs Setup (Apple Push Notifications)

### 2.1 Create APNs Certificate

1. Go to [Apple Developer Portal](https://developer.apple.com/account)
2. Navigate to "Certificates, Identifiers & Profiles"
3. Click "+" to create new certificate
4. Select "Apple Push Notification service SSL (Sandbox & Production)"
5. Choose your App ID
6. Follow CSR instructions to generate certificate
7. Download the `.cer` file

### 2.2 Convert Certificate to .pem

```bash
# Convert .cer to .pem
openssl x509 -in aps_development.cer -inform DER -out cert.pem -outform PEM

# Export private key from Keychain Access
# File → Export Items → Save as .p12 file

# Convert .p12 to .pem
openssl pkcs12 -in key.p12 -out key.pem -nodes -clcerts

# Move to backend directory
mv cert.pem backend/apns_cert.pem
mv key.pem backend/apns_key.pem
```

### 2.3 Configure Backend

Add APNs settings to `backend/.env`:
```bash
APNS_CERT_PATH=apns_cert.pem
APNS_KEY_PATH=apns_key.pem
APNS_BUNDLE_ID=com.yourcompany.BudgetInsight
APNS_USE_SANDBOX=true  # Set to false for production
```

---

## Part 3: Deploy Backend to Google Cloud Run

### 3.1 Build and Deploy

```bash
cd backend

# Make deploy script executable
chmod +x deploy.sh

# Deploy to Cloud Run
./deploy.sh
```

### 3.2 Get Cloud Run URL

```bash
# Get the deployed service URL
gcloud run services describe budgetinsight-backend --region=us-central1 --format='value(status.url)'
```

Example output: `https://budgetinsight-backend-abc123-uc.a.run.app`

### 3.3 Update Pub/Sub Subscription

```bash
# Update the push endpoint with your Cloud Run URL
gcloud pubsub subscriptions update gmail-push-sub \
    --push-endpoint=https://YOUR_CLOUD_RUN_URL/webhooks/gmail
```

---

## Part 4: Configure iOS App

### 4.1 Add Push Notification Capability

1. Open BudgetInsight in Xcode
2. Select your target → "Signing & Capabilities"
3. Click "+ Capability"
4. Add "Push Notifications"
5. Add "Background Modes" and enable:
   - Remote notifications
   - Background fetch

### 4.2 Update BackendService Base URL

Edit `BudgetInsight/Services/BackendService.swift`:

```swift
// Replace this line:
private let baseURL = "http://localhost:8080/api"

// With your Cloud Run URL:
private let baseURL = "https://budgetinsight-backend-abc123-uc.a.run.app/api"
```

### 4.3 Add New Files to Xcode Project

The following files need to be added to your Xcode project:

1. `BudgetInsight/Services/BackendService.swift` ✅ Created
2. `BudgetInsight/AppDelegate.swift` ✅ Created
3. `BudgetInsight/Views/BackendRegistrationView.swift` ✅ Created

**To add them:**
1. In Xcode, right-click on the appropriate folder
2. Select "Add Files to BudgetInsight..."
3. Navigate to the file location
4. Ensure "Copy items if needed" is checked
5. Click "Add"

---

## Part 5: Test the Integration

### 5.1 Local Backend Testing

```bash
# Start local backend
cd backend
./setup.sh
python app.py
```

The server will run on `http://localhost:8080`

### 5.2 Test User Registration

1. Run the iOS app
2. You should see the "Connect to Backend" screen
3. Enter an email address
4. Click "Register"
5. Check backend logs for registration confirmation

### 5.3 Test Gmail Webhooks

```bash
# In your backend, run the Gmail setup
python -c "from services.gmail_service import GmailService; GmailService().setup_watch('YOUR_EMAIL@gmail.com')"
```

This sets up Gmail to send push notifications to your Pub/Sub topic.

### 5.4 Test Transaction Sync

1. Send yourself a test Discover transaction email
2. Backend receives webhook from Gmail
3. Backend parses transaction and saves to Firestore
4. Backend sends APNs push notification to iOS device
5. iOS app receives notification and syncs transaction
6. Check Dashboard for new transaction

---

## Part 6: Environment Variables Summary

### Backend `.env` file:

```bash
# Google Cloud (Firestore uses same credentials)
GOOGLE_APPLICATION_CREDENTIALS=credentials.json
GOOGLE_CLOUD_PROJECT=budgetinsight-backend
PUBSUB_TOPIC=gmail-notifications

# APNs
APNS_CERT_PATH=apns_cert.pem
APNS_KEY_PATH=apns_key.pem
APNS_BUNDLE_ID=com.yourcompany.BudgetInsight
APNS_USE_SANDBOX=true

# Server
PORT=8080
FLASK_ENV=production
```

**Note**: Firestore doesn't require a separate connection string - it uses `GOOGLE_APPLICATION_CREDENTIALS` automatically!

---

## Part 7: Monitoring and Debugging

### 7.1 View Cloud Run Logs

```bash
# Stream logs
gcloud run services logs tail budgetinsight-backend --region=us-central1

# View in Cloud Console
# https://console.cloud.google.com/run
```

### 7.2 View Pub/Sub Metrics

```bash
# Check subscription status
gcloud pubsub subscriptions describe gmail-push-sub
```

### 7.3 iOS Debug Logs

Enable verbose logging in Xcode console to see:
- Device token registration
- Push notification receipt
- Backend sync operations
- Transaction updates

---

## Part 8: Production Checklist

Before going to production:

- [ ] Switch APNs to production certificate (`APNS_USE_SANDBOX=false`)
- [ ] Set up Firestore security rules
- [ ] Enable Cloud Run authentication
- [ ] Set up monitoring and alerting
- [ ] Configure Firestore backup exports
- [ ] Set up domain with SSL for Cloud Run
- [ ] Review and optimize Cloud Run scaling settings
- [ ] Implement rate limiting on API endpoints
- [ ] Add proper error tracking (e.g., Sentry)
- [ ] Test on physical iOS device (not simulator)

---

## Cost Estimates

Based on typical usage:

- **MongoDB Atlas**: Free tier (512MB storage)
- **Google Cloud Run**: ~$5-10/month (100K requests)
- **Google Pub/Sub**: ~$1/month (1M messages)
- **Cloud Storage**: ~$1/month
- **APNs**: Free
- **Total**: ~$5-15/month

---

## Troubleshooting

### "Failed to register for remote notifications"

- Check that Push Notifications capability is enabled
- Verify you're using a physical device (simulator doesn't support APNs)
- Confirm your provisioning profile includes push notifications

### "Backend connection failed"

- Verify Cloud Run URL is correct in BackendService.swift
- Check Cloud Run logs for errors
- Ensure Firestore is enabled and credentials are valid
- Test backend endpoint with curl:
  ```bash
  curl https://YOUR_CLOUD_RUN_URL/api/health
  ```

### "Gmail webhooks not working"

- Verify Pub/Sub topic exists
- Check push subscription endpoint URL
- Run `setup_watch()` to re-register Gmail notifications
- Check Cloud Console Pub/Sub metrics for messages

### "Push notifications not received"

- Verify APNs certificate is valid
- Check device token is uploaded to backend
- Test notification delivery:
  ```bash
  curl -X POST https://YOUR_CLOUD_RUN_URL/api/test-push \
    -H "Content-Type: application/json" \
    -d '{"user_id": "YOUR_USER_ID"}'
  ```

---

## Next Steps

Once everything is working:

1. Set up CI/CD for automatic backend deployments
2. Implement user authentication (OAuth, JWT)
3. Add data encryption for sensitive information
4. Set up monitoring dashboards
5. Implement offline support with sync queue
6. Add multi-device support
7. Implement data export/import features

---

## Support

For issues and questions:
- Check backend logs: `gcloud run services logs tail budgetinsight-backend`
- Review iOS console logs in Xcode
- Check Firestore console for data
- Review Google Cloud Console for API errors

---

**Last Updated**: December 26, 2025
