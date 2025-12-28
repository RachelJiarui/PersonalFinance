# 🎉 Gmail Push Notifications - Complete Setup Guide

## What You Have Now

✅ **Real-time Gmail push notifications** from Discover transaction alerts  
✅ **Automatic watch renewal** - no manual intervention needed  
✅ **Complete backend integration** with Firestore and APNs  
✅ **iOS app ready** to receive and process alerts  

---

## Quick Start (10 Minutes Total)

### Step 1: Gmail API Setup (2 min)
```bash
# Enable API and grant permissions
gcloud services enable gmail.googleapis.com
PROJECT_ID=$(gcloud config get-value project)
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member=serviceAccount:gmail-api-push@system.gserviceaccount.com \
    --role=roles/pubsub.publisher
```

### Step 2: OAuth Credentials (3 min)
1. Go to [console.cloud.google.com](https://console.cloud.google.com)
2. APIs & Services → Credentials
3. Create OAuth 2.0 Client ID → **Desktop app**
4. Download JSON → Save as `backend/credentials.json`

### Step 3: Initial Setup (2 min)
```bash
cd backend
python3 setup_gmail_push.py --email your.email@gmail.com
```
Browser opens → Sign in → Grant Gmail access → Done!

### Step 4: Deploy Backend (2 min)
```bash
./deploy.sh
```

### Step 5: Enable Auto-Renewal (1 min)
```bash
./setup_auto_renewal.sh
```

**That's it!** 🎉

---

## How It Works

```
📧 Discover Transaction Email
    ↓
📬 Gmail receives in inbox
    ↓
🔔 Gmail pushes to Pub/Sub
    ↓
🌐 Pub/Sub triggers webhook
    ↓
🔍 Backend parses email
    ↓
💾 Saves to Firestore (is_linked: false)
    ↓
📱 APNs push to iPhone
    ↓
📲 App shows: "1 transaction needs entry"
    ↓
✅ You create transaction from alert
```

---

## Auto-Renewal

**Problem Solved**: Gmail watches expire every 7 days

**Solution**: Cloud Scheduler runs daily at 3 AM and auto-renews

**You do**: Nothing! Set it up once, forget about it.

---

## Files Created

### Backend
- `backend/services/gmail_watch_manager.py` - Auto-renewal service
- `backend/setup_gmail_push.py` - Initial setup script
- `backend/setup_auto_renewal.sh` - Cloud Scheduler setup
- `backend/app.py` - Updated with renewal endpoints

### Documentation
- `GMAIL_PUSH_SETUP_GUIDE.md` - Complete setup instructions
- `GMAIL_AUTO_RENEWAL.md` - Auto-renewal details
- `GMAIL_QUICK_COMMANDS.md` - Command reference
- `GMAIL_PUSH_READY.md` - Quick start summary
- `AUTO_RENEWAL_COMPLETE.md` - Auto-renewal summary
- `GMAIL_SETUP_COMPLETE.md` - This file

---

## Testing

### Test Gmail Connection
```bash
python3 setup_gmail_push.py --test
```

### List Recent Discover Emails
```bash
python3 setup_gmail_push.py --list-emails
```

### Check Watch Status
```bash
curl https://YOUR_CLOUD_RUN_URL/api/users/USER_ID/gmail-watch/status
```

### View Renewal Logs
```bash
gcloud run services logs tail budgetinsight-backend --region=us-central1 | grep "Renewal"
```

### Trigger Renewal Manually
```bash
gcloud scheduler jobs run gmail-watch-renewal --location=us-central1
```

---

## What Gets Extracted

Example Discover email:
```
Subject: Transaction Alert
Body: Purchase of $45.67 at Whole Foods on 12/26/2025
```

Becomes:
```json
{
  "amount": 45.67,
  "merchant": "Whole Foods",
  "date": "2025-12-26",
  "is_linked": false
}
```

Saved to Firestore → Push notification sent → Shows in app

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| No webhooks received | Check Pub/Sub subscription: `gcloud pubsub subscriptions describe gmail-push-sub` |
| Watch expired | Re-run: `python3 setup_gmail_push.py` |
| Auto-renewal not working | Check Cloud Scheduler: `gcloud scheduler jobs describe gmail-watch-renewal` |
| Access token invalid | Re-authorize: `python3 setup_gmail_push.py` |

---

## Cost

Everything is **FREE** or very cheap:

- Gmail API: FREE (within quota)
- Pub/Sub: ~$1/month
- Cloud Scheduler: FREE (first 3 jobs)
- Cloud Run: ~$5-10/month
- Firestore: FREE (under quota)

**Total**: ~$5-15/month (mostly Cloud Run)

---

## Documentation Index

Start here based on what you need:

1. **Quick Setup**: `GMAIL_PUSH_READY.md`
2. **Detailed Guide**: `GMAIL_PUSH_SETUP_GUIDE.md`
3. **Auto-Renewal**: `GMAIL_AUTO_RENEWAL.md`
4. **Commands**: `GMAIL_QUICK_COMMANDS.md`
5. **This Summary**: `GMAIL_SETUP_COMPLETE.md`

---

## Next Steps

1. ✅ Follow Quick Start above
2. ✅ Make a Discover purchase (or forward old email)
3. ✅ Watch backend logs for webhook
4. ✅ Check Firestore for alert
5. ✅ See push notification on iPhone
6. ✅ Open app and create transaction

---

## Maintenance

**Required**: None! Auto-renewal handles everything.

**Optional monitoring**:
- Check logs weekly to verify renewals
- Monitor Firestore for alerts
- Review Cloud Scheduler job history

---

**You're all set!** 🚀

When Discover sends "Transaction Alert" emails, your app will automatically:
1. Parse transaction details
2. Save to Firestore  
3. Send push notification
4. Show in app for quick entry

And the Gmail watch will auto-renew forever - no manual intervention needed!

---

**Last Updated**: December 26, 2025
