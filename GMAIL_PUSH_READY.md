# ✅ Gmail Push Notifications - Ready to Set Up!

## What's Been Created

I've set up everything you need for Gmail push notifications from Discover transaction alerts.

### Files Created

1. **`backend/setup_gmail_push.py`** ✅
   - Complete setup script for Gmail push notifications
   - Handles OAuth flow automatically
   - Tests connection and lists recent emails
   - Sets up Gmail watch (7-day expiration)

2. **`GMAIL_PUSH_SETUP_GUIDE.md`** ✅
   - Complete step-by-step setup guide
   - Troubleshooting section
   - Flow diagram
   - All commands included

3. **`GMAIL_QUICK_COMMANDS.md`** ✅
   - Quick command reference
   - Copy-paste ready commands
   - Renewal instructions

### Backend Already Configured

- ✅ Gmail service (`backend/services/gmail_service.py`)
- ✅ Transaction parser (`backend/services/transaction_parser.py`)
- ✅ Pub/Sub webhook (`backend/app.py` line 60-80)
- ✅ Firestore integration
- ✅ APNs push notifications

---

## Quick Setup (5 Minutes)

### Step 1: Enable Gmail API & Permissions
```bash
# Enable API
gcloud services enable gmail.googleapis.com

# Grant permissions
PROJECT_ID=$(gcloud config get-value project)
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member=serviceAccount:gmail-api-push@system.gserviceaccount.com \
    --role=roles/pubsub.publisher
```

### Step 2: Create OAuth Credentials
1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. APIs & Services → Credentials
3. Create OAuth 2.0 Client ID → **Desktop app**
4. Download JSON → Save as `backend/credentials.json`

### Step 3: Run Setup Script
```bash
cd backend
python3 setup_gmail_push.py --email your.email@gmail.com
```

A browser will open - sign in and grant Gmail access.

### Step 4: Test
Send yourself an old Discover email (or wait for a new transaction), then check:
```bash
# View backend logs
gcloud run services logs tail budgetinsight-backend --region=us-central1

# Check Firestore
# Go to console.cloud.google.com/firestore → transaction_alerts
```

---

## How It Works

```
📧 Discover Email (Subject: "Transaction Alert")
    ↓
📬 Gmail API Watch (monitors your inbox)
    ↓
🔔 Pub/Sub Notification (webhook triggered)
    ↓
🌐 Cloud Run Backend (/webhooks/gmail)
    ↓
🔍 Parse Email (extract $amount, merchant, date)
    ↓
💾 Save to Firestore (transaction_alerts collection)
    ↓
📱 APNs Push Notification
    ↓
📲 iOS App (shows banner: "1 transaction needs entry")
    ↓
✅ You create transaction from alert
```

---

## What Gets Extracted from Emails

Example Discover email:
```
Subject: Transaction Alert
Body: Purchase of $45.67 at Whole Foods on 12/26/2025
```

Parsed transaction alert:
```json
{
  "email_id": "msg_123",
  "amount": 45.67,
  "merchant": "Whole Foods",
  "date": "2025-12-26T00:00:00Z",
  "is_linked": false,
  "created_at": "2025-12-26T10:30:00Z"
}
```

---

## Important Notes

### Gmail Watch Auto-Renewal ✅
- **Auto-renewal is now built-in!**
- Cloud Scheduler runs daily at 3 AM
- Automatically renews watches before they expire
- **No manual intervention needed**
- Setup once with: `./setup_auto_renewal.sh`

### Security
Add to `.gitignore`:
```bash
echo "credentials.json" >> backend/.gitignore
echo "token.pickle" >> backend/.gitignore
echo "last_history_id.txt" >> backend/.gitignore
```

### Email Filtering
The backend automatically filters for:
- ✅ Emails from `discover@services.discover.com`
- ✅ Subject contains "Transaction Alert" or "Purchase"
- ❌ Ignores other emails (marketing, statements, etc.)

---

## Testing Your Setup

### 1. Test Gmail Connection
```bash
python3 setup_gmail_push.py --test
```

Expected output:
```
✅ Gmail API connection successful!
   Email: your.email@gmail.com
   Messages: 1,234
```

### 2. List Recent Discover Emails
```bash
python3 setup_gmail_push.py --list-emails
```

Expected output:
```
📨 Searching for recent Discover emails...
   Found 3 recent transaction alerts:

   • Transaction Alert
     Date: Mon, 25 Dec 2025 10:30:00
     ID: msg_abc123
```

### 3. Full Setup
```bash
python3 setup_gmail_push.py --email your.email@gmail.com
```

Expected output:
```
✅ Gmail watch successfully configured!
   History ID: 123456789
   Expiration: 1735315200000
   Expires at: 2026-01-02 10:30:00
```

### 4. Enable Auto-Renewal
```bash
./setup_auto_renewal.sh
```

Expected output:
```
✅ Cloud Scheduler job created successfully!
✨ Auto-renewal is now active! You never need to manually renew again.
```

### 5. Make a Test Purchase
Use your Discover card for any purchase, then:
- Wait 1-2 minutes for email
- Check backend logs for webhook
- Check Firestore for new alert
- Check iOS app for push notification

---

## Troubleshooting Quick Reference

| Issue | Solution |
|-------|----------|
| "Insufficient Permission" | Run: `gcloud projects add-iam-policy-binding...` (see Step 1) |
| "credentials.json not found" | Download OAuth credentials from Console |
| "Topic not found" | Run: `gcloud pubsub topics create gmail-notifications` |
| No webhooks received | Check subscription: `gcloud pubsub subscriptions describe gmail-push-sub` |
| Watch expired | Re-run setup script |

---

## Complete Checklist

### One-Time Setup
- [ ] Enable Gmail API
- [ ] Grant Pub/Sub permissions to Gmail
- [ ] Create OAuth 2.0 credentials (Desktop app)
- [ ] Download credentials.json
- [ ] Run setup script
- [ ] Authorize Gmail access in browser
- [ ] Verify watch is configured
- [ ] **Run auto-renewal setup script**
- [ ] Test with real Discover email

### No Maintenance Needed! ✅
- ✅ Auto-renewal handles everything
- ✅ Watches never expire
- ✅ Zero manual intervention

### After Each Transaction
- [ ] Receive email from Discover
- [ ] Get push notification on iPhone
- [ ] Open BudgetInsight app
- [ ] See banner: "1 transaction needs entry"
- [ ] Create transaction from alert
- [ ] Alert marked as linked in Firestore

---

## Cost

**Gmail API**: FREE (within quota)
- 1 billion quota units/day
- Each watch setup = ~50 units
- Each email fetch = ~5 units
- Your usage: ~100 units/day = 0.00001% of quota

**Additional costs**: None! Uses existing Pub/Sub and Cloud Run

---

## Next Steps

1. **Read**: `GMAIL_PUSH_SETUP_GUIDE.md` for detailed instructions
2. **Run**: Setup commands above
3. **Test**: Make a Discover purchase or forward old email
4. **Verify**: Check logs, Firestore, and iOS app
5. **Set Reminder**: Renew watch every 7 days

---

## Support Files

- **`GMAIL_PUSH_SETUP_GUIDE.md`** - Complete setup guide with troubleshooting
- **`GMAIL_QUICK_COMMANDS.md`** - Quick command reference
- **`backend/setup_gmail_push.py`** - Setup script
- **`GMAIL_PUSH_READY.md`** - This file

---

**You're all set!** 🎉

Run the setup commands above and you'll have real-time Gmail push notifications working in 5 minutes!

When Discover sends "Transaction Alert" emails, your app will automatically:
1. Parse the transaction details
2. Save to Firestore
3. Send push notification
4. Show banner in app

No more manual entry - just review and confirm!

---

**Last Updated**: December 26, 2025
