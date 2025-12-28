# 🚀 Deployment Quick Reference

## One-Command Setup

```bash
cd backend
./setup_cloud.sh    # Set up Google Cloud (15 min)
./deploy.sh         # Deploy to Cloud Run (5 min)
```

---

## Essential Commands

### Deploy Backend
```bash
cd backend
./deploy.sh
```

### View Logs
```bash
gcloud run services logs tail budgetinsight-backend --region=us-central1
```

### Test Health
```bash
curl https://YOUR_CLOUD_RUN_URL/health
```

### Setup Gmail
```bash
python3 setup_gmail_push.py --email your.email@gmail.com
```

### Setup Auto-Renewal
```bash
./setup_auto_renewal.sh
```

### Check Gmail Watch Status
```bash
python3 setup_gmail_push.py --test
```

---

## Required Files

### Must Have (create these)
- `backend/credentials.json` - Service account key
- `backend/credentials_oauth.json` - OAuth client for Gmail
- `backend/apns_cert.pem` - APNs certificate
- `backend/apns_key.pem` - APNs private key
- `backend/.env` - Environment variables

### Auto-Generated
- `backend/Dockerfile` - ✅ Created
- `backend/.env.example` - ✅ Created
- `backend/.gitignore` - ✅ Updated
- `backend/.gcloudignore` - ✅ Created

---

## Environment Variables (.env)

```bash
# Google Cloud
GOOGLE_APPLICATION_CREDENTIALS=credentials.json
GOOGLE_CLOUD_PROJECT=your-project-id
PUBSUB_TOPIC=gmail-notifications

# APNs
APNS_CERT_PATH=apns_cert.pem
APNS_KEY_PATH=apns_key.pem
APNS_BUNDLE_ID=com.yourcompany.BudgetInsight
APNS_USE_SANDBOX=true

# Server
PORT=8080
FLASK_ENV=production
SECRET_KEY=auto-generated-by-setup-script
```

---

## Service URLs

After deployment, you'll get:

**Cloud Run URL:**
`https://budgetinsight-backend-XXXXX-uc.a.run.app`

**API Endpoints:**
- Health: `GET /health`
- Webhook: `POST /webhooks/gmail`
- Register: `POST /api/users/register`
- Transactions: `GET/POST /api/users/{user_id}/transactions`
- Alerts: `GET /api/users/{user_id}/transaction-alerts`
- Budget: `GET/POST /api/users/{user_id}/budget`

---

## Firestore Collections

- `users` - User accounts and device tokens
- `budgets` - Budget allocations and income
- `transactions` - Transaction history
- `transaction_alerts` - Parsed email alerts
- `gmail_watches` - Gmail watch metadata

---

## APNs Certificate Setup

### Quick Convert
```bash
cd backend

# From .p12 file:
openssl pkcs12 -in cert.p12 -out apns_cert.pem -clcerts -nokeys
openssl pkcs12 -in cert.p12 -out apns_key.pem -nocerts -nodes
```

### Get from Apple
1. developer.apple.com → Certificates
2. Create → APNs Certificate
3. Download .cer → Export as .p12
4. Convert using commands above

---

## Common Issues & Fixes

| Issue | Fix |
|-------|-----|
| "Permission denied" | `gcloud auth login` |
| "Firestore not found" | Create database in Native mode |
| "No Gmail notifications" | Check Pub/Sub subscription webhook URL |
| "APNs error" | Verify bundle ID and certificate match |
| "Deployment fails" | Check `gcloud config get-value project` |

---

## iOS App Update

Edit `BackendService.swift`:
```swift
private let baseURL = "https://YOUR_CLOUD_RUN_URL/api"
```

Enable in Xcode:
- Push Notifications capability
- Background Modes → Remote notifications

---

## Cost Estimate

- Firestore: **FREE** (under 50K reads/day)
- Cloud Run: **FREE** or ~$1-2/month
- Pub/Sub: **FREE** (under 10GB/month)
- Cloud Scheduler: **$0.10/month**

**Total: $0.10 - $2/month**

---

## Support Files

- `CLOUD_RUN_DEPLOYMENT.md` - Full deployment guide
- `FIRESTORE_STRUCTURE.md` - Data schema
- `GMAIL_PUSH_SETUP_GUIDE.md` - Gmail details
- `backend/README.md` - Backend docs

---

**Quick Help:**
```bash
# Check project
gcloud config get-value project

# List services
gcloud run services list

# Check Firestore
open https://console.cloud.google.com/firestore

# Check logs
gcloud run services logs tail budgetinsight-backend --region=us-central1
```
