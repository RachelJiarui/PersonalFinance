# Gmail Push Notifications - Quick Command Reference

## One-Time Setup (5 minutes)

```bash
# 1. Enable Gmail API
gcloud services enable gmail.googleapis.com

# 2. Grant Gmail permission to publish to Pub/Sub
PROJECT_ID=$(gcloud config get-value project)
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member=serviceAccount:gmail-api-push@system.gserviceaccount.com \
    --role=roles/pubsub.publisher

# 3. Create OAuth credentials
# Go to console.cloud.google.com → APIs & Services → Credentials
# Create OAuth 2.0 Client ID → Desktop app
# Download JSON → Save as backend/credentials.json

# 4. Run setup script
cd backend
python3 setup_gmail_push.py --email your.email@gmail.com

# Follow browser prompts to authorize Gmail access
```

---

## Test Commands

```bash
# Test Gmail API connection
python3 setup_gmail_push.py --test

# List recent Discover emails
python3 setup_gmail_push.py --list-emails

# Full setup (renew watch)
python3 setup_gmail_push.py --email your.email@gmail.com
```

---

## Verify Setup

```bash
# Check Pub/Sub topic exists
gcloud pubsub topics list | grep gmail-notifications

# Check subscription exists and has correct endpoint
gcloud pubsub subscriptions describe gmail-push-sub

# View backend logs
gcloud run services logs tail budgetinsight-backend --region=us-central1

# Check Firestore for alerts
# Go to console.cloud.google.com/firestore → transaction_alerts collection
```

---

## Renew Gmail Watch (Every 7 Days)

```bash
cd backend
python3 setup_gmail_push.py --email your.email@gmail.com
```

Set a calendar reminder!

---

## Troubleshooting

### Check if watch is active
```bash
# Look for expiration timestamp in last setup output
# Or check backend logs for watch expiration warnings
```

### Manually trigger a test
```bash
# Send yourself an old Discover email
# Or make a small purchase with Discover card
# Check backend logs for webhook activity
```

### Reset everything
```bash
# Stop current watch (optional)
# This requires running from Python with credentials

# Delete and recreate subscription
gcloud pubsub subscriptions delete gmail-push-sub
CLOUD_RUN_URL=$(gcloud run services describe budgetinsight-backend --region=us-central1 --format='value(status.url)')
gcloud pubsub subscriptions create gmail-push-sub \
    --topic=gmail-notifications \
    --push-endpoint=$CLOUD_RUN_URL/webhooks/gmail

# Run setup again
python3 setup_gmail_push.py --email your.email@gmail.com
```

---

## Environment Variables

Add to `backend/.env`:

```bash
# Gmail configuration
GMAIL_WATCH_TOPIC=projects/YOUR_PROJECT_ID/topics/gmail-notifications
GMAIL_WATCH_LABEL_IDS=INBOX
EMAIL_FROM_FILTER=discover@services.discover.com
```

---

## What Happens When You Get a Discover Email

1. 📧 Discover sends "Transaction Alert" email
2. 📬 Gmail receives it in your inbox
3. 🔔 Gmail pushes notification to Pub/Sub
4. 🌐 Pub/Sub triggers webhook on Cloud Run
5. 🔍 Backend fetches email and parses it
6. 💾 Backend saves alert to Firestore (is_linked: false)
7. 📱 Backend sends APNs push to your iPhone
8. 📲 You see: "New transaction: $45.67 at Whole Foods"
9. ✅ You open app and create transaction from alert

---

## Files Created

- `backend/setup_gmail_push.py` - Setup script
- `backend/credentials.json` - OAuth credentials (YOU CREATE)
- `backend/token.pickle` - Saved Gmail access token (AUTO-CREATED)
- `backend/last_history_id.txt` - Last processed message (AUTO-CREATED)

**Important**: Add to `.gitignore`:
```bash
echo "credentials.json" >> backend/.gitignore
echo "token.pickle" >> backend/.gitignore
echo "last_history_id.txt" >> backend/.gitignore
```

---

## Expected Email Format from Discover

```
From: discover@services.discover.com
Subject: Transaction Alert

Purchase of $45.67 at Whole Foods on 12/26/2025.

If you did not make this purchase, contact us immediately.
```

Parsed to:
- Amount: $45.67
- Merchant: Whole Foods
- Date: 12/26/2025

---

**Quick Start**: Follow `GMAIL_PUSH_SETUP_GUIDE.md` for detailed instructions!
