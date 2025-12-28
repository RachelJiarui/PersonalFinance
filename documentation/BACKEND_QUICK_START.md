# Backend Quick Start Guide

## 🚀 Fast Track Setup (20 minutes)

### Step 1: Google Cloud Setup (10 min)
```bash
# Install gcloud CLI: https://cloud.google.com/sdk/docs/install

# Login
gcloud auth login

# Create project
gcloud projects create budgetinsight-backend
gcloud config set project budgetinsight-backend

# Enable APIs
gcloud services enable gmail.googleapis.com pubsub.googleapis.com run.googleapis.com firestore.googleapis.com

# Create service account
gcloud iam service-accounts create budgetinsight-backend
gcloud iam service-accounts keys create backend/credentials.json \
    --iam-account=budgetinsight-backend@budgetinsight-backend.iam.gserviceaccount.com

# Create Pub/Sub topic
gcloud pubsub topics create gmail-notifications

# Create Firestore database
# Go to console.cloud.google.com → Firestore → Create Database
# Choose "Native mode" and select location (e.g., us-central1)
```

### Step 2: APNs Certificate (5 min)
```bash
# 1. Go to https://developer.apple.com/account
# 2. Certificates → Create → APNs Certificate
# 3. Download .cer file
# 4. Convert:
openssl x509 -in aps.cer -inform DER -out backend/apns_cert.pem -outform PEM
openssl pkcs12 -in key.p12 -out backend/apns_key.pem -nodes -clcerts

# 5. Add to backend/.env:
echo 'APNS_CERT_PATH=apns_cert.pem' >> backend/.env
echo 'APNS_KEY_PATH=apns_key.pem' >> backend/.env
echo 'APNS_BUNDLE_ID=com.yourcompany.BudgetInsight' >> backend/.env
echo 'APNS_USE_SANDBOX=true' >> backend/.env
```

### Step 3: Deploy Backend (5 min)
```bash
cd backend
chmod +x deploy.sh
./deploy.sh

# Get URL
gcloud run services describe budgetinsight-backend --region=us-central1 --format='value(status.url)'
# Example: https://budgetinsight-backend-abc123-uc.a.run.app
```

### Step 4: Update iOS App (5 min)
```swift
// In BudgetInsight/Services/BackendService.swift, change:
private let baseURL = "https://budgetinsight-backend-abc123-uc.a.run.app/api"

// In Xcode:
// 1. Add files to project:
//    - BackendService.swift
//    - AppDelegate.swift
//    - BackendRegistrationView.swift
// 2. Enable Push Notifications capability
// 3. Enable Background Modes → Remote notifications
```

### Step 5: Configure Pub/Sub Webhook
```bash
# Update push endpoint with your Cloud Run URL
gcloud pubsub subscriptions create gmail-push-sub \
    --topic=gmail-notifications \
    --push-endpoint=https://YOUR_CLOUD_RUN_URL/webhooks/gmail
```

### Step 6: Test
```bash
# Run app → Register with email → Send test transaction email → Check Dashboard
```

---

## 📁 Required Files

### Backend Files (All Created ✅)
```
backend/
├── app.py                          # Main Flask server
├── requirements.txt                # Python dependencies
├── Dockerfile                      # Container config
├── deploy.sh                       # Deployment script
├── setup.sh                        # Local setup
├── .env                           # Environment variables (YOU CREATE)
├── credentials.json               # GCP credentials (YOU CREATE)
├── apns_cert.pem                  # APNs certificate (YOU CREATE)
├── apns_key.pem                   # APNs key (YOU CREATE)
├── services/
│   ├── mongodb_service.py         # MongoDB operations
│   ├── pubsub_service.py          # Pub/Sub integration
│   ├── gmail_service.py           # Gmail API
│   ├── apns_service.py            # Push notifications
│   └── transaction_parser.py      # Email parsing
├── README.md                       # Full documentation
└── ARCHITECTURE.md                 # System design
```

### iOS Files (All Created ✅)
```
BudgetInsight/
├── Services/
│   └── BackendService.swift       # Backend API client
├── Views/
│   └── BackendRegistrationView.swift  # Registration UI
└── AppDelegate.swift               # Push notification handler
```

---

## 🔑 Environment Variables Template

Create `backend/.env`:
```bash
# Google Cloud (Firestore uses same credentials as other services)
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

---

## 🧪 Test Commands

### Test Backend Locally
```bash
cd backend
./setup.sh
python app.py
# Server runs on http://localhost:8080
```

### Test API Endpoints
```bash
# Health check
curl http://localhost:8080/api/health

# Register user
curl -X POST http://localhost:8080/api/users/register \
  -H "Content-Type: application/json" \
  -d '{"email": "test@example.com"}'

# Upload transaction
curl -X POST http://localhost:8080/api/users/USER_ID/transactions \
  -H "Content-Type: application/json" \
  -d '{"amount": 50.00, "merchant": "Test Store", "date": "2025-12-26T12:00:00Z"}'
```

### Setup Gmail Watch
```python
# In Python:
from services.gmail_service import GmailService
gmail = GmailService()
gmail.setup_watch('your.email@gmail.com')
```

---

## 🐛 Common Issues

| Issue | Solution |
|-------|----------|
| "Module not found" error | Run `pip install -r requirements.txt` |
| "Cannot connect to Firestore" | Check GOOGLE_APPLICATION_CREDENTIALS path |
| "APNs certificate error" | Verify .pem files exist and are valid |
| "Pub/Sub permission denied" | Grant pubsub.editor role to service account |
| "Push notifications not working" | Use physical device, not simulator |
| "Backend URL not found" | Update BackendService.swift with Cloud Run URL |

---

## 📊 How It Works

```
┌─────────────┐
│   Gmail     │ New transaction email
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  Pub/Sub    │ Webhook trigger
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  Flask API  │ Parse & save to MongoDB
└──────┬──────┘
       │
       ▼
┌─────────────┐
│    APNs     │ Send push notification
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  iOS App    │ Sync & update dashboard
└─────────────┘
```

---

## 💰 Monthly Cost

- Firestore: **FREE** (1GB storage, 50K reads, 20K writes per day)
- Google Cloud Run: **~$5-10** (100K requests)
- Google Pub/Sub: **~$1** (1M messages)
- APNs: **FREE**
- **Total: $5-15/month** (likely FREE tier for most users)

---

## ✅ Pre-Flight Checklist

Before deploying to production:

- [ ] Google Cloud project created
- [ ] Firestore database created in Native mode
- [ ] Service account credentials downloaded
- [ ] Pub/Sub topic and subscription created
- [ ] APNs certificate generated and converted
- [ ] Backend .env file complete
- [ ] Backend deployed to Cloud Run
- [ ] iOS app updated with Cloud Run URL
- [ ] Push notification capability enabled in Xcode
- [ ] App tested on physical device
- [ ] Gmail watch configured

---

## 📚 Documentation

- **Full Setup Guide**: `INTEGRATION_GUIDE.md`
- **Backend Architecture**: `backend/ARCHITECTURE.md`
- **Backend README**: `backend/README.md`
- **API Documentation**: See backend/ARCHITECTURE.md

---

## 🆘 Need Help?

1. Check logs:
   ```bash
   # Backend logs
   gcloud run services logs tail budgetinsight-backend --region=us-central1
   
   # iOS logs
   # Enable verbose logging in Xcode console
   ```

2. Verify services:
   ```bash
   # Check Cloud Run status
   gcloud run services list
   
   # Check Pub/Sub
   gcloud pubsub subscriptions describe gmail-push-sub
   
   # Check Firestore
   # Go to console.cloud.google.com/firestore
   ```

3. Review documentation:
   - `INTEGRATION_GUIDE.md` - Detailed setup
   - `backend/README.md` - Backend specifics
   - `backend/ARCHITECTURE.md` - System design

---

**Ready to go!** 🎉

Start with Step 1 and work your way through. The entire setup takes about 20 minutes with Firestore!
