# 🚀 Cloud Run + Firestore Deployment Guide

Complete guide to deploy your BudgetInsight backend on Google Cloud Run with Firestore for persistent storage of Discover transactions.

## 📋 Prerequisites

- Google Cloud account with billing enabled
- gcloud CLI installed ([Install here](https://cloud.google.com/sdk/docs/install))
- Apple Developer account (for APNs certificates)
- Gmail account for transaction monitoring

---

## 🎯 Quick Deployment (30 minutes)

### Phase 1: Google Cloud Setup (15 minutes)

#### Step 1: Run the automated setup script

```bash
cd backend
./setup_cloud.sh
```

This script will automatically:
- Enable all required Google Cloud APIs
- Create Firestore database (you'll need to confirm in console)
- Create service account with proper IAM roles
- Download service account credentials
- Create Pub/Sub topic for Gmail notifications
- Generate `.env` file from template

#### Step 2: Verify Firestore Database

The script will prompt you to create the Firestore database manually:

1. Go to [Firestore Console](https://console.cloud.google.com/firestore)
2. Click **"Create Database"**
3. Select **"Native mode"** (critical - NOT Datastore mode)
4. Choose location: **us-central1**
5. Click **"Create"**

> **Why Native mode?** It supports real-time updates, better querying, and is the recommended mode for new projects.

---

### Phase 2: APNs Certificate Setup (5 minutes)

You need Apple Push Notification certificates to send notifications to your iOS app.

#### Option A: If you have existing APNs certificate

```bash
# Convert .p12 certificate to PEM format
cd backend

# Extract certificate
openssl pkcs12 -in your_cert.p12 -out apns_cert.pem -clcerts -nokeys

# Extract private key
openssl pkcs12 -in your_cert.p12 -out apns_key.pem -nocerts -nodes
```

#### Option B: Create new APNs certificate

1. Go to [Apple Developer Portal](https://developer.apple.com/account)
2. Certificates, Identifiers & Profiles → Certificates
3. Click **+** to create new certificate
4. Choose **Apple Push Notification service SSL (Sandbox & Production)**
5. Select your App ID (com.yourcompany.BudgetInsight)
6. Download the certificate (.cer file)
7. Open in Keychain Access
8. Export as .p12 file
9. Convert to PEM using Option A above

#### Update .env file

```bash
# Edit backend/.env and update:
APNS_BUNDLE_ID=com.yourcompany.BudgetInsight  # Your actual bundle ID
APNS_USE_SANDBOX=true  # Use 'false' for production
```

---

### Phase 3: Deploy to Cloud Run (5 minutes)

```bash
cd backend
./deploy.sh
```

The deployment script will:
1. Build Docker container using Cloud Build
2. Deploy to Cloud Run with proper configuration
3. Set up environment variables
4. Configure service account
5. Output your backend URL

**Save the Service URL** - you'll need it for:
- iOS app configuration
- Pub/Sub webhook endpoint
- Testing

Example URL: `https://budgetinsight-backend-abc123-uc.a.run.app`

---

### Phase 4: Configure Pub/Sub Webhook (2 minutes)

After deployment, create the Pub/Sub subscription:

```bash
# Use the URL from the deployment output
SERVICE_URL="YOUR_CLOUD_RUN_URL"  # e.g., https://budgetinsight-backend-abc123-uc.a.run.app

gcloud pubsub subscriptions create gmail-push-sub \
  --topic=gmail-notifications \
  --push-endpoint=$SERVICE_URL/webhooks/gmail \
  --ack-deadline=30
```

---

### Phase 5: Set Up Gmail Push Notifications (3 minutes)

#### Create OAuth Credentials

1. Go to [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
2. Click **Create Credentials** → **OAuth client ID**
3. Application type: **Desktop app**
4. Name it: "BudgetInsight Gmail Setup"
5. Click **Create**
6. Download JSON file
7. Save as `backend/credentials_oauth.json`

> **Note:** This is different from `credentials.json` (service account). You need both!

#### Run Gmail Setup

```bash
cd backend
python3 setup_gmail_push.py --email your.email@gmail.com
```

A browser will open:
1. Sign in to your Gmail account
2. Grant permission to access Gmail
3. Script will set up watch for Discover transaction emails

The watch expires every 7 days and needs renewal (we'll automate this next).

---

### Phase 6: Set Up Auto-Renewal (2 minutes)

```bash
cd backend
./setup_auto_renewal.sh
```

This creates a Cloud Scheduler job that runs daily at 3 AM to automatically renew Gmail watches before they expire.

---

## ✅ Verification & Testing

### Test 1: Health Check

```bash
curl https://YOUR_CLOUD_RUN_URL/health
```

Expected response:
```json
{
  "status": "healthy",
  "timestamp": "2025-12-27T...",
  "services": {
    "firestore": true,
    "pubsub": true
  }
}
```

### Test 2: Check Firestore

1. Go to [Firestore Console](https://console.cloud.google.com/firestore)
2. You should see collections (may be empty until first use):
   - `users`
   - `transactions`
   - `transaction_alerts`

### Test 3: Backend Logs

```bash
gcloud run services logs tail budgetinsight-backend --region=us-central1
```

Look for:
- `🚀 Starting BudgetInsight Backend Server`
- No error messages

### Test 4: Send Test Email

Forward an old Discover transaction email to yourself, or make a small purchase.

Check logs for:
```
📧 Received Gmail notification: ...
📬 Found 1 new messages
💰 Parsed 1 transaction alerts
```

---

## 📱 iOS App Configuration

### Update Backend URL

Edit `BudgetInsight/BudgetInsight/Services/BackendService.swift`:

```swift
private let baseURL = "https://YOUR_CLOUD_RUN_URL/api"
```

### Add Required Files to Xcode

If not already added:
1. `Services/BackendService.swift`
2. `AppDelegate.swift`
3. `Views/BackendRegistrationView.swift`

### Enable Push Notifications

1. In Xcode, select your project
2. Select target → **Signing & Capabilities**
3. Click **+ Capability**
4. Add **Push Notifications**
5. Add **Background Modes** → Check **Remote notifications**

### Test on Device

1. Build and run on physical device (not simulator)
2. App should prompt for notification permission
3. Register with your email in the app
4. Make a test purchase with Discover card
5. You should receive push notification

---

## 🗂️ Firestore Data Structure

Your data will be organized as follows:

### Collections

#### `users`
```
users/{user_id}
├── email: string
├── device_tokens: array
├── last_history_id: string
├── created_at: timestamp
└── updated_at: timestamp
```

#### `budgets`
```
budgets/{user_id}
├── user_id: string
├── annual_salary: number
├── k401_contribution: number
├── monthly_take_home: number
├── categories: array
└── updated_at: timestamp
```

#### `transactions`
```
transactions/{transaction_id}
├── user_id: string
├── amount: number
├── merchant: string
├── category: string
├── date: timestamp
├── linked_email_alert_id: string (optional)
└── created_at: timestamp
```

#### `transaction_alerts`
```
transaction_alerts/{alert_id}
├── user_id: string
├── email_id: string
├── amount: number
├── merchant: string
├── date: timestamp
├── is_linked: boolean
├── linked_transaction_id: string (optional)
└── created_at: timestamp
```

#### `gmail_watches`
```
gmail_watches/{user_id}
├── user_id: string
├── email: string
├── history_id: string
├── expiration: timestamp
├── is_active: boolean
├── last_renewed_at: timestamp
└── created_at: timestamp
```

---

## 💰 Cost Breakdown

### Firestore
- **Free Tier:** 1 GB storage, 50K reads, 20K writes per day
- **Your usage:** ~100 operations/day = **FREE**

### Cloud Run
- **Free Tier:** 2 million requests/month, 360,000 GB-seconds
- **Your usage:** ~10K requests/month = **FREE** (or $1-2 if exceeded)

### Pub/Sub
- **Free Tier:** 10 GB/month
- **Your usage:** ~1 MB/month = **FREE**

### Cloud Scheduler (for auto-renewal)
- **Cost:** $0.10/job/month = **$0.10/month**

### Cloud Build
- **Free Tier:** 120 build-minutes/day
- **Your usage:** 1 build every few weeks = **FREE**

**Total Monthly Cost: $0.10 - $2.00** (mostly free!)

---

## 🔒 Security Best Practices

### Credentials Management

✅ **DO:**
- Keep `credentials.json` in `.gitignore`
- Use environment variables for secrets
- Rotate service account keys annually
- Use least-privilege IAM roles

❌ **DON'T:**
- Commit credentials to git
- Share credentials via email/Slack
- Use same credentials for dev/prod
- Give overly broad IAM permissions

### API Security

Current setup: `--allow-unauthenticated` (for webhooks)

For production, consider:
- Add API key authentication for user endpoints
- Verify Pub/Sub webhook requests (already implemented)
- Rate limiting on endpoints
- HTTPS only (enforced by Cloud Run)

---

## 🛠️ Maintenance

### Daily (Automated)
- ✅ Gmail watch auto-renewal at 3 AM

### Weekly
- Check Cloud Run logs for errors
- Monitor Firestore usage in console

### Monthly
- Review Cloud billing
- Check for Cloud SDK updates: `gcloud components update`

### As Needed
- Update backend: `./deploy.sh`
- Update dependencies: `pip install -U -r requirements.txt`

---

## 🐛 Troubleshooting

### Issue: Deployment fails with "permission denied"

**Solution:**
```bash
# Ensure you're authenticated
gcloud auth login

# Set correct project
gcloud config set project YOUR_PROJECT_ID

# Verify service account has roles
gcloud projects get-iam-policy YOUR_PROJECT_ID
```

### Issue: "Firestore not initialized"

**Solution:**
1. Verify database created in **Native mode**
2. Check service account has `roles/datastore.user`
3. Verify `GOOGLE_APPLICATION_CREDENTIALS` points to valid credentials.json

### Issue: No Gmail notifications received

**Solution:**
```bash
# Check Gmail watch status
python3 setup_gmail_push.py --test

# Verify Pub/Sub subscription
gcloud pubsub subscriptions describe gmail-push-sub

# Check backend logs
gcloud run services logs tail budgetinsight-backend --region=us-central1
```

### Issue: Push notifications not working on iOS

**Solution:**
1. ✅ Using physical device (not simulator)
2. ✅ Push Notifications capability enabled
3. ✅ Correct APNs certificate for environment (sandbox vs production)
4. ✅ Bundle ID matches certificate
5. ✅ Device token successfully registered with backend

### Issue: "429 Too Many Requests" from Gmail API

**Solution:**
- You've hit Gmail API quota (unlikely with normal use)
- Wait a few minutes for quota reset
- Check [quota usage](https://console.cloud.google.com/apis/api/gmail.googleapis.com/quotas)

---

## 📚 Additional Resources

### Documentation
- [Firestore Documentation](https://cloud.google.com/firestore/docs)
- [Cloud Run Documentation](https://cloud.google.com/run/docs)
- [Gmail Push Notifications](https://developers.google.com/gmail/api/guides/push)
- [APNs Documentation](https://developer.apple.com/documentation/usernotifications)

### Your Project Files
- `FIRESTORE_STRUCTURE.md` - Detailed data schema
- `GMAIL_PUSH_SETUP_GUIDE.md` - Gmail setup details
- `BACKEND_QUICK_START.md` - Quick reference
- `backend/README.md` - Backend architecture

### Support Scripts
- `backend/setup_cloud.sh` - Automated cloud setup
- `backend/deploy.sh` - Deployment script
- `backend/setup_gmail_push.py` - Gmail configuration
- `backend/setup_auto_renewal.sh` - Auto-renewal setup

---

## ✅ Deployment Checklist

Use this checklist to ensure everything is set up correctly:

### Pre-Deployment
- [ ] gcloud CLI installed and authenticated
- [ ] Google Cloud project created with billing enabled
- [ ] Apple Developer account for APNs

### Cloud Setup
- [ ] All Google Cloud APIs enabled
- [ ] Firestore database created in Native mode
- [ ] Service account created with IAM roles
- [ ] Service account credentials downloaded (credentials.json)
- [ ] Pub/Sub topic created (gmail-notifications)
- [ ] Gmail API permissions granted

### Certificates & Credentials
- [ ] APNs certificate obtained from Apple
- [ ] APNs certificate converted to PEM format
- [ ] OAuth credentials created for Gmail
- [ ] All files in backend/.gitignore

### Backend Configuration
- [ ] .env file created from .env.example
- [ ] Environment variables updated with project ID
- [ ] APNs bundle ID set correctly
- [ ] Secret key generated

### Deployment
- [ ] Backend deployed to Cloud Run successfully
- [ ] Service URL obtained and saved
- [ ] Pub/Sub subscription created with webhook endpoint
- [ ] Health check endpoint returns 200 OK

### Gmail Setup
- [ ] OAuth credentials downloaded
- [ ] Gmail watch configured for your email
- [ ] Auto-renewal Cloud Scheduler job created
- [ ] Test email triggers webhook successfully

### iOS App
- [ ] Backend URL updated in BackendService.swift
- [ ] Push Notifications capability enabled
- [ ] Background Modes enabled
- [ ] APNs bundle ID matches backend configuration
- [ ] App tested on physical device
- [ ] Push notifications working

### Verification
- [ ] Firestore collections visible in console
- [ ] Backend logs show no errors
- [ ] Gmail webhook receiving notifications
- [ ] Transactions saved to Firestore
- [ ] iOS app receives push notifications
- [ ] End-to-end flow tested with real purchase

---

## 🎉 You're Done!

Your BudgetInsight backend is now running on Cloud Run with Firestore!

**What happens now:**

1. **Discover sends transaction email** → Gmail receives it
2. **Gmail API sends notification** → Pub/Sub webhook triggered
3. **Backend processes email** → Parses amount, merchant, date
4. **Data saved to Firestore** → Persistent storage in `transaction_alerts`
5. **Push notification sent** → iOS app receives alert
6. **User creates transaction** → Linked to email alert in Firestore
7. **Dashboard updates** → Real-time sync with backend

All of this happens automatically!

---

**Last Updated:** December 27, 2025
**Cloud Run Region:** us-central1
**Firestore Mode:** Native
