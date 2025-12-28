# Gmail Push Notification Setup Guide

This guide will help you set up real-time Gmail push notifications so that when Discover sends a "Transaction Alert" email, your app automatically creates a transaction alert that needs entry.

---

## Overview

```
Discover Email → Gmail → Pub/Sub Webhook → Backend → Parse Email → Save Alert → APNs → iOS App
```

When you receive a transaction email from Discover:
1. Gmail receives the email
2. Gmail pushes notification to Google Pub/Sub
3. Pub/Sub triggers your backend webhook
4. Backend parses the email and extracts transaction details
5. Backend saves transaction alert to Firestore
6. Backend sends push notification to your iOS device
7. You see alert on your phone and can create the transaction

---

## Prerequisites

- ✅ Google Cloud project created
- ✅ Firestore database enabled
- ✅ Backend deployed to Cloud Run
- ✅ Pub/Sub topic created (`gmail-notifications`)
- ✅ Gmail account with Discover transaction emails

---

## Part 1: Enable Gmail API

### Step 1: Enable the Gmail API

```bash
# Enable Gmail API
gcloud services enable gmail.googleapis.com

# Verify it's enabled
gcloud services list --enabled | grep gmail
```

### Step 2: Grant Pub/Sub Permissions to Gmail

Gmail needs permission to publish to your Pub/Sub topic:

```bash
# Get your project ID
PROJECT_ID=$(gcloud config get-value project)

# Grant Gmail permission to publish to Pub/Sub
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member=serviceAccount:gmail-api-push@system.gserviceaccount.com \
    --role=roles/pubsub.publisher
```

---

## Part 2: Create OAuth 2.0 Credentials

### Step 1: Create OAuth Client ID

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Select your project
3. Navigate to **APIs & Services** → **Credentials**
4. Click **"+ CREATE CREDENTIALS"** → **"OAuth client ID"**
5. Choose **"Desktop app"** as application type
6. Name it: `Gmail Push Notification Setup`
7. Click **"Create"**

### Step 2: Download Credentials

1. Click the download button (⬇️) next to your new OAuth client
2. Download the JSON file
3. Rename it to `credentials.json`
4. Move it to your `backend/` directory:
   ```bash
   mv ~/Downloads/client_secret_*.json backend/credentials.json
   ```

---

## Part 3: Run Setup Script

### Step 1: Install Python Dependencies

```bash
cd backend
pip install --upgrade google-auth-oauthlib google-auth-httplib2 google-api-python-client
```

### Step 2: Make Setup Script Executable

```bash
chmod +x setup_gmail_push.py
```

### Step 3: Run the Setup

```bash
python3 setup_gmail_push.py --email your.email@gmail.com
```

**What happens:**
1. A browser window opens for Gmail authorization
2. You'll see a Google sign-in page
3. Click your Gmail account
4. Grant permissions to access Gmail (read and modify)
5. You may see a warning about unverified app - click "Advanced" → "Go to Gmail Push Notification Setup (unsafe)"
6. Click "Allow" to grant permissions
7. The script will:
   - Test Gmail API connection
   - List recent Discover transaction emails (if any)
   - Set up Gmail push notifications
   - Save credentials for future use

**Expected output:**
```
✅ Gmail API connection successful!
   Email: your.email@gmail.com
   Messages: 1,234
   Threads: 890

📨 Searching for recent Discover emails...
   Found 3 recent transaction alerts:

   • Purchase Alert: $45.67
     Date: Mon, 25 Dec 2025 10:30:00 -0500

✅ Gmail watch successfully configured!
   History ID: 123456789
   Expiration: 1735315200000
   Expires at: 2026-01-02 10:30:00
```

---

## Part 4: Verify Pub/Sub Configuration

### Check Pub/Sub Topic

```bash
# List topics
gcloud pubsub topics list

# Should show: projects/YOUR_PROJECT/topics/gmail-notifications
```

### Check Subscription

```bash
# List subscriptions
gcloud pubsub subscriptions list

# Should show: projects/YOUR_PROJECT/subscriptions/gmail-push-sub
```

### Verify Subscription Endpoint

```bash
# Check the push endpoint
gcloud pubsub subscriptions describe gmail-push-sub

# Should show:
# pushConfig:
#   pushEndpoint: https://YOUR_CLOUD_RUN_URL/webhooks/gmail
```

If the subscription doesn't exist or has the wrong endpoint, create/update it:

```bash
# Get your Cloud Run URL
CLOUD_RUN_URL=$(gcloud run services describe budgetinsight-backend --region=us-central1 --format='value(status.url)')

# Create or update subscription
gcloud pubsub subscriptions create gmail-push-sub \
    --topic=gmail-notifications \
    --push-endpoint=$CLOUD_RUN_URL/webhooks/gmail \
    --ack-deadline=10
```

---

## Part 5: Test the Integration

### Method 1: Send Test Email

The easiest way to test is to make a real purchase with your Discover card, or forward an old transaction email to yourself.

### Method 2: Check Backend Logs

After you receive a Discover email:

```bash
# Stream Cloud Run logs
gcloud run services logs tail budgetinsight-backend --region=us-central1
```

You should see:
```
📧 Received Gmail notification: {'emailAddress': 'your@gmail.com', 'historyId': '123456'}
💰 Parsed transaction: Whole Foods - $45.67
✅ Transaction alert saved
📱 Push notification sent to iOS device
```

### Method 3: Check Firestore

Go to [Firestore Console](https://console.cloud.google.com/firestore) and check:
- `transaction_alerts` collection
- You should see new documents with `is_linked: false`

---

## Part 6: iOS App Integration

The iOS app is already set up to receive these alerts! Here's what happens:

1. **Backend sends APNs notification** when alert is created
2. **AppDelegate receives notification** (AppDelegate.swift:45)
3. **App syncs transactions** from backend
4. **DashboardView shows banner** with unlinked alerts count
5. **User taps banner** to create transaction from alert

---

## Troubleshooting

### "Insufficient Permission" Error

**Problem**: Gmail can't publish to Pub/Sub

**Solution**:
```bash
gcloud projects add-iam-policy-binding $(gcloud config get-value project) \
    --member=serviceAccount:gmail-api-push@system.gserviceaccount.com \
    --role=roles/pubsub.publisher
```

### "Credentials not found" Error

**Problem**: OAuth credentials.json file missing

**Solution**: Download credentials from Google Cloud Console (see Part 2)

### "Topic not found" Error

**Problem**: Pub/Sub topic doesn't exist

**Solution**:
```bash
gcloud pubsub topics create gmail-notifications
```

### "Watch already exists" Error

**Problem**: Gmail watch is already set up

**Solution**: This is actually fine! The watch will be renewed with a new expiration time.

### No Webhooks Received

**Problem**: Backend not receiving Pub/Sub notifications

**Checklist**:
1. Verify Cloud Run URL is publicly accessible:
   ```bash
   curl https://YOUR_CLOUD_RUN_URL/health
   ```

2. Check Pub/Sub subscription:
   ```bash
   gcloud pubsub subscriptions describe gmail-push-sub
   ```

3. Check backend logs:
   ```bash
   gcloud run services logs tail budgetinsight-backend
   ```

4. Verify Gmail watch is active (check expiration timestamp)

### Emails Not Being Parsed

**Problem**: Backend receives notification but doesn't parse email

**Check**:
1. Email is from `discover.com`
2. Subject contains "Transaction Alert" or "Purchase"
3. Backend logs show parsing attempt
4. Transaction parser regex patterns match email format

---

## Renewing Gmail Watch (Every 7 Days)

Gmail watch expires after 7 days. You'll need to renew it:

```bash
# Re-run the setup script
cd backend
python3 setup_gmail_push.py --email your.email@gmail.com
```

**Tip**: Set a calendar reminder for every 7 days!

**Future Enhancement**: Add auto-renewal to backend (check expiration, renew if < 1 day remaining)

---

## Testing Commands

### Test Gmail Connection
```bash
python3 setup_gmail_push.py --test
```

### List Recent Discover Emails
```bash
python3 setup_gmail_push.py --list-emails
```

### Full Setup
```bash
python3 setup_gmail_push.py --email your.email@gmail.com
```

---

## Environment Variables

Add to `backend/.env`:

```bash
# Gmail
GMAIL_WATCH_TOPIC=projects/budgetinsight-backend/topics/gmail-notifications
GMAIL_WATCH_LABEL_IDS=INBOX

# (Other vars remain the same)
```

---

## Email Parsing Details

### What Gets Extracted from Discover Emails:

- **Amount**: `$45.67`
- **Merchant**: `Whole Foods`
- **Date**: `12/26/2025`
- **Email ID**: Unique Gmail message ID

### Example Discover Email Format:

```
Subject: Purchase Alert: $45.67

You made a purchase of $45.67 at Whole Foods on 12/26/2025.

If you did not make this purchase, please contact us immediately.
```

The transaction parser uses regex to extract these fields and creates a transaction alert in Firestore.

---

## Security Notes

1. **OAuth Token Storage**: The `token.pickle` file contains your Gmail access token. Keep it secure!

2. **Credentials**: Never commit `credentials.json` to git. Add to `.gitignore`:
   ```bash
   echo "credentials.json" >> backend/.gitignore
   echo "token.pickle" >> backend/.gitignore
   ```

3. **Service Account**: The backend uses service account credentials, not your personal Gmail token

4. **Webhook Security**: Pub/Sub verifies webhook requests with tokens

---

## Quick Setup Checklist

- [ ] Enable Gmail API
- [ ] Grant Pub/Sub permissions to Gmail service account
- [ ] Create OAuth 2.0 credentials (Desktop app)
- [ ] Download credentials.json
- [ ] Run `python3 setup_gmail_push.py`
- [ ] Authorize Gmail access in browser
- [ ] Verify watch is set up successfully
- [ ] Check Pub/Sub subscription exists
- [ ] Test with real Discover email
- [ ] Verify alert appears in Firestore
- [ ] Check iOS app receives push notification

---

## Complete Flow Diagram

```
┌─────────────────┐
│  Discover       │ Sends "Transaction Alert" email
│  Card Issuer    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Gmail          │ Receives email in your inbox
│  (your account) │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Gmail API      │ Detects new message
│  Watch          │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Pub/Sub        │ Receives notification, triggers webhook
│  Topic          │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Cloud Run      │ /webhooks/gmail endpoint
│  Backend        │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Gmail Service  │ Fetches full email content
│                 │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Transaction    │ Parses email, extracts amount/merchant/date
│  Parser         │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Firestore      │ Saves transaction alert (is_linked: false)
│  Database       │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  APNs Service   │ Sends push notification
│                 │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  iOS Device     │ Receives notification
│  Your iPhone    │ "New transaction: $45.67 at Whole Foods"
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  BudgetInsight  │ User opens app, sees banner
│  App            │ "1 transaction needs entry"
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Manual Entry   │ User creates transaction, links to alert
│  View           │ Alert marked as is_linked: true
└─────────────────┘
```

---

**Last Updated**: December 26, 2025
