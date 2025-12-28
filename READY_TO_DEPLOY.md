# ✅ Ready to Deploy!

## What I've Done For You

I've set up everything needed to deploy your backend to Cloud Run with Firestore. Here's what's ready:

### ✅ Files Created

1. **`backend/Dockerfile`** - Container configuration for Cloud Run
2. **`backend/.env.example`** - Environment variable template
3. **`backend/.gcloudignore`** - Files to exclude from deployment
4. **`backend/setup_cloud.sh`** - Automated Google Cloud setup script
5. **`backend/deploy.sh`** - Updated deployment script (Cloud Run optimized)
6. **`backend/.gitignore`** - Updated to protect credentials
7. **`CLOUD_RUN_DEPLOYMENT.md`** - Complete deployment guide (30 pages)
8. **`DEPLOYMENT_QUICK_REFERENCE.md`** - Quick command reference
9. **`backend/DEPLOYMENT_CHECKLIST.md`** - Printable checklist

### ✅ Files Already Existing (Created Earlier)

- `backend/app.py` - Flask server with Firestore integration
- `backend/services/firestore_service.py` - Firestore database operations
- `backend/services/gmail_service.py` - Gmail API integration
- `backend/services/transaction_parser.py` - Email parsing logic
- `backend/setup_gmail_push.py` - Gmail setup script
- `backend/setup_auto_renewal.sh` - Auto-renewal script

---

## 🚀 What You Need To Do

### Part 1: Things I CAN'T Do (You Must Do)

These require your Google Cloud account and Apple Developer account:

#### 1. Run Cloud Setup Script (15 minutes)
```bash
cd backend
./setup_cloud.sh
```

This will:
- Enable Google Cloud APIs
- Prompt you to create Firestore database manually
- Create service account and download credentials
- Create Pub/Sub topic
- Generate .env file

**Manual step in the script:** When prompted, go to [Firestore Console](https://console.cloud.google.com/firestore) and create database in **Native mode**, location **us-central1**.

#### 2. Get APNs Certificates (5 minutes)

From [Apple Developer Portal](https://developer.apple.com/account):
1. Create APNs certificate for your app
2. Download and export as .p12
3. Convert to PEM:
```bash
cd backend
openssl pkcs12 -in cert.p12 -out apns_cert.pem -clcerts -nokeys
openssl pkcs12 -in cert.p12 -out apns_key.pem -nocerts -nodes
```

Update `backend/.env`:
```bash
APNS_BUNDLE_ID=com.yourcompany.BudgetInsight  # Your actual bundle ID
```

#### 3. Deploy Backend (5 minutes)
```bash
cd backend
./deploy.sh
```

Save the URL it outputs - you'll need it!

#### 4. Configure Pub/Sub Webhook (1 minute)
```bash
SERVICE_URL="https://your-cloud-run-url.run.app"  # From step 3

gcloud pubsub subscriptions create gmail-push-sub \
  --topic=gmail-notifications \
  --push-endpoint=$SERVICE_URL/webhooks/gmail \
  --ack-deadline=30
```

#### 5. Setup Gmail Push Notifications (3 minutes)

First, create OAuth credentials:
1. Go to [Google Cloud Console Credentials](https://console.cloud.google.com/apis/credentials)
2. Create OAuth client ID → Desktop app
3. Download JSON → Save as `backend/credentials_oauth.json`

Then run:
```bash
cd backend
python3 setup_gmail_push.py --email your.email@gmail.com
```

#### 6. Setup Auto-Renewal (1 minute)
```bash
cd backend
./setup_auto_renewal.sh
```

#### 7. Update iOS App (2 minutes)

Edit `BudgetInsight/BudgetInsight/Services/BackendService.swift`:
```swift
private let baseURL = "https://your-cloud-run-url.run.app/api"
```

In Xcode:
- Enable Push Notifications capability
- Enable Background Modes → Remote notifications

#### 8. Test Everything (5 minutes)

```bash
# Test backend
curl https://your-cloud-run-url.run.app/health

# Check logs
gcloud run services logs tail budgetinsight-backend --region=us-central1

# Make a test purchase or forward old Discover email
# Check that notification arrives in iOS app
```

---

## 📋 Step-by-Step Summary

**Total Time: ~30 minutes**

| Step | What | Time | You Do |
|------|------|------|--------|
| 1 | Run `./setup_cloud.sh` | 15 min | ✅ |
| 2 | Get APNs certificates | 5 min | ✅ |
| 3 | Run `./deploy.sh` | 5 min | ✅ |
| 4 | Create Pub/Sub subscription | 1 min | ✅ |
| 5 | Setup Gmail with OAuth | 3 min | ✅ |
| 6 | Setup auto-renewal | 1 min | ✅ |
| 7 | Update iOS app URL | 2 min | ✅ |
| 8 | Test end-to-end | 5 min | ✅ |

---

## 📚 Documentation Guide

**Start Here:**
1. Read: `DEPLOYMENT_CHECKLIST.md` - Print this out and check off as you go

**For Details:**
2. Read: `CLOUD_RUN_DEPLOYMENT.md` - Complete 30-page guide with troubleshooting

**Quick Reference:**
3. Keep open: `DEPLOYMENT_QUICK_REFERENCE.md` - All commands in one place

**If Issues:**
4. Check: Troubleshooting sections in `CLOUD_RUN_DEPLOYMENT.md`

---

## 🗂️ File Structure

```
backend/
├── app.py                          # Main Flask server ✅
├── requirements.txt                # Dependencies ✅
├── Dockerfile                      # NEW - Container config ✅
├── .env.example                    # NEW - Environment template ✅
├── .env                            # YOU CREATE - From setup script
├── .gitignore                      # UPDATED - Protects credentials ✅
├── .gcloudignore                   # NEW - Deployment excludes ✅
├── deploy.sh                       # UPDATED - Cloud Run optimized ✅
├── setup_cloud.sh                  # NEW - Automated setup ✅
├── setup_gmail_push.py             # Gmail setup script ✅
├── setup_auto_renewal.sh           # Auto-renewal script ✅
├── credentials.json                # YOU CREATE - From setup script
├── credentials_oauth.json          # YOU CREATE - OAuth for Gmail
├── apns_cert.pem                   # YOU CREATE - APNs certificate
├── apns_key.pem                    # YOU CREATE - APNs key
└── services/
    ├── firestore_service.py        # Firestore operations ✅
    ├── gmail_service.py            # Gmail API ✅
    ├── transaction_parser.py       # Email parsing ✅
    ├── pubsub_service.py           # Pub/Sub integration ✅
    ├── apns_service.py             # Push notifications ✅
    └── gmail_watch_manager.py      # Watch management ✅
```

---

## 🎯 What This Gives You

Once deployed, your system will:

1. **Monitor Gmail** for Discover transaction emails
2. **Parse transactions** automatically (amount, merchant, date)
3. **Save to Firestore** for persistent storage
4. **Send push notifications** to your iPhone
5. **Sync with iOS app** for manual entry review
6. **Auto-renew** Gmail watch every day (no manual intervention)

**All happening in real-time, automatically!**

---

## 💰 Cost

- **Firestore:** FREE (under 50K operations/day)
- **Cloud Run:** FREE or ~$1-2/month (under 100K requests)
- **Pub/Sub:** FREE (under 10GB/month)
- **Cloud Scheduler:** $0.10/month (auto-renewal)

**Total: $0.10 - $2/month**

---

## 🔒 Security

All sensitive files are in `.gitignore`:
- ✅ credentials.json
- ✅ credentials_oauth.json  
- ✅ apns_cert.pem
- ✅ apns_key.pem
- ✅ .env
- ✅ token.pickle

**Never commit these to git!**

---

## ✅ Pre-Flight Check

Before you start, make sure you have:

- [ ] Google Cloud account with billing enabled
- [ ] gcloud CLI installed: `gcloud --version`
- [ ] Logged in: `gcloud auth login`
- [ ] Apple Developer account
- [ ] Gmail account to monitor
- [ ] Physical iOS device (for testing push notifications)

---

## 🆘 If You Get Stuck

1. **Check the checklist:** `backend/DEPLOYMENT_CHECKLIST.md`
2. **Read troubleshooting:** Section in `CLOUD_RUN_DEPLOYMENT.md`
3. **Check logs:**
   ```bash
   gcloud run services logs tail budgetinsight-backend --region=us-central1
   ```
4. **Verify setup:**
   ```bash
   # Check project
   gcloud config get-value project
   
   # Check services
   gcloud run services list
   
   # Check Firestore
   open https://console.cloud.google.com/firestore
   ```

---

## 🎉 Next Steps

1. **Start with:** `backend/DEPLOYMENT_CHECKLIST.md` ← Print this!
2. **Run:** `cd backend && ./setup_cloud.sh`
3. **Follow the checklist** step by step
4. **Test everything** before considering it done

---

## Summary of What I Did vs What You Need To Do

### ✅ What I Did (Code & Configuration)
- Created Dockerfile for containerization
- Updated deploy.sh for Cloud Run
- Created automated setup script
- Generated environment template
- Protected credentials in .gitignore
- Wrote comprehensive documentation
- Created deployment checklist

### 👤 What You Need To Do (Cloud & Credentials)
- Run setup_cloud.sh (requires your Google account)
- Create Firestore database (manual click in console)
- Get APNs certificates (requires Apple Developer account)
- Deploy to Cloud Run (requires gcloud authentication)
- Setup Gmail OAuth (requires your Gmail account)
- Configure auto-renewal scheduler
- Update iOS app with backend URL
- Test end-to-end flow

---

**Your backend code is ready. Now it's time to deploy it!**

Start with: `cd backend && ./setup_cloud.sh`

Good luck! 🚀

---

**Created:** December 27, 2025  
**Status:** Ready to deploy  
**Estimated deployment time:** 30 minutes
