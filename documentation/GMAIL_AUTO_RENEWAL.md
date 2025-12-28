# Gmail Watch Auto-Renewal 🔄

## Overview

Your backend now automatically renews Gmail watches before they expire!

**No more manual renewal every 7 days** - set it up once and forget about it.

---

## How It Works

```
┌─────────────────┐
│ Cloud Scheduler │ Runs daily at 3 AM
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Backend API     │ POST /tasks/renew-watches
│ Renewal Check   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Check All Users │ Get users with active watches
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ For Each Watch  │ Check expiration time
└────────┬────────┘
         │
         ├─ Expires in > 24h → Skip (still valid)
         │
         └─ Expires in < 24h → Renew watch → Update Firestore
                                    ↓
                            ✅ Watch renewed for 7 more days
```

---

## Setup (One-Time, 2 Minutes)

### Step 1: Deploy Updated Backend

```bash
cd backend
./deploy.sh
```

### Step 2: Run Auto-Renewal Setup Script

```bash
cd backend
chmod +x setup_auto_renewal.sh
./setup_auto_renewal.sh
```

**What this does:**
1. Enables Cloud Scheduler API
2. Creates a service account for Cloud Scheduler
3. Grants permissions to invoke Cloud Run
4. Creates daily scheduled job (runs at 3 AM)

**Expected output:**
```
✅ Cloud Scheduler job created successfully!

📊 Job Details:
   Name: gmail-watch-renewal
   Schedule: Daily at 3 AM America/New_York
   Endpoint: https://your-backend.run.app/tasks/renew-watches

✨ Auto-renewal is now active! You never need to manually renew again.
```

---

## Verify Setup

### Check Scheduler Job

```bash
gcloud scheduler jobs describe gmail-watch-renewal --location=us-central1
```

Expected output shows:
- Schedule: `0 3 * * *` (daily at 3 AM)
- State: `ENABLED`
- Last run time (after first execution)

### Test Manually

```bash
# Trigger the renewal job immediately
gcloud scheduler jobs run gmail-watch-renewal --location=us-central1

# View logs
gcloud run services logs tail budgetinsight-backend --region=us-central1
```

Expected log output:
```
🔄 [Scheduled Task] Gmail watch renewal check started
✓ Watch for user@gmail.com is active (6 days remaining)
📊 Renewal Summary:
   Total users: 1
   Renewed: 0
   Failed: 0
```

---

## How It Decides to Renew

The system checks each user's watch every day:

```
Watch expires in 6 days → Skip (still valid)
Watch expires in 23 hours → RENEW ✅
Watch expires in 12 hours → RENEW ✅
Watch already expired → RENEW ✅
```

**Renewal threshold**: 24 hours before expiration

This gives a safety buffer in case the renewal fails the first time.

---

## What Gets Stored in Firestore

Each user document now includes:

```json
{
  "user_id": "user_123",
  "email": "user@gmail.com",
  "gmail_watch": {
    "expiration": 1735315200000,
    "history_id": "123456",
    "access_token": "ya29.xxx...",
    "created_at": 1734710400000,
    "last_renewed": 1734710400000
  }
}
```

**Security Note**: The access token is stored encrypted in Firestore and only used for watch renewal.

---

## Monitoring

### View Renewal History

```bash
# Check Cloud Scheduler job history
gcloud scheduler jobs describe gmail-watch-renewal --location=us-central1

# View backend logs
gcloud run services logs tail budgetinsight-backend --region=us-central1 | grep "Renewal Summary"
```

### Check Individual Watch Status

```bash
# API endpoint to check watch status
curl https://YOUR_CLOUD_RUN_URL/api/users/USER_ID/gmail-watch/status
```

Response:
```json
{
  "active": true,
  "expiration": "2026-01-02T10:30:00Z",
  "days_remaining": 6,
  "hours_remaining": 12,
  "message": "Watch active, expires in 6 days"
}
```

---

## Troubleshooting

### "Job failed to run"

**Check logs:**
```bash
gcloud run services logs tail budgetinsight-backend --region=us-central1
```

**Common issues:**
- Service account doesn't have Cloud Run invoker permission
- Backend endpoint not responding
- Firestore connection issue

**Fix:**
```bash
# Re-grant permissions
./setup_auto_renewal.sh
```

### "Watch not being renewed"

**Check:**
1. Is the scheduled job enabled?
   ```bash
   gcloud scheduler jobs describe gmail-watch-renewal --location=us-central1
   ```

2. Is the watch info in Firestore?
   - Go to Firestore Console → users collection → check `gmail_watch` field

3. Is the access token valid?
   - Tokens expire after ~1 hour
   - Setup script stores a refresh token for long-term use

**Fix:**
- Re-run initial Gmail setup: `python3 setup_gmail_push.py --email your@gmail.com`

### "Access token expired"

The initial setup stores a refresh token that automatically gets new access tokens. If you see this error:

```bash
# Re-authorize Gmail access
cd backend
python3 setup_gmail_push.py --email your@gmail.com
```

This updates the stored tokens in Firestore.

---

## Cost

**Cloud Scheduler**: FREE for first 3 jobs per month

Your setup:
- 1 job (gmail-watch-renewal)
- Runs 30 times/month (daily)
- **Cost: $0.00** (within free tier)

---

## Manual Commands (if needed)

### Force renewal now
```bash
curl -X POST https://YOUR_CLOUD_RUN_URL/tasks/renew-watches
```

### Change schedule

Edit the schedule in `setup_auto_renewal.sh`:
```bash
SCHEDULE="0 3 * * *"  # Current: Daily at 3 AM
# Change to:
SCHEDULE="0 */6 * * *"  # Every 6 hours
SCHEDULE="0 0 * * 0"  # Weekly on Sunday
```

Then re-run:
```bash
./setup_auto_renewal.sh
```

### Disable auto-renewal

```bash
gcloud scheduler jobs pause gmail-watch-renewal --location=us-central1
```

### Re-enable

```bash
gcloud scheduler jobs resume gmail-watch-renewal --location=us-central1
```

### Delete job

```bash
gcloud scheduler jobs delete gmail-watch-renewal --location=us-central1
```

---

## Updated Documentation

The following files have been updated:

- ✅ **`backend/services/gmail_watch_manager.py`** - Auto-renewal service
- ✅ **`backend/app.py`** - Renewal endpoints added
- ✅ **`backend/setup_auto_renewal.sh`** - Cloud Scheduler setup script
- ✅ **`GMAIL_AUTO_RENEWAL.md`** - This file

Updated guides:
- `GMAIL_PUSH_SETUP_GUIDE.md` - No longer mentions manual 7-day renewal
- `GMAIL_QUICK_COMMANDS.md` - Auto-renewal section added

---

## Summary

**Before Auto-Renewal:**
- ❌ Manual renewal every 7 days
- ❌ Calendar reminder needed
- ❌ Watch expires if you forget
- ❌ Notifications stop working

**After Auto-Renewal:**
- ✅ Fully automatic
- ✅ Checks daily at 3 AM
- ✅ Renews before expiration
- ✅ Never expires
- ✅ Zero maintenance

---

## Complete Setup Checklist

- [ ] Deploy updated backend (`./deploy.sh`)
- [ ] Run auto-renewal setup (`./setup_auto_renewal.sh`)
- [ ] Verify Cloud Scheduler job exists
- [ ] Test manual trigger
- [ ] Check backend logs for success
- [ ] Verify watch status API endpoint works

---

**Done!** 🎉

Your Gmail watches will now auto-renew forever. No more manual intervention needed!

---

**Last Updated**: December 26, 2025
