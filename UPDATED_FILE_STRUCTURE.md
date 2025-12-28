# Complete File Structure (Updated for Firestore)

## Backend Files ✅ All Complete

```
backend/
├── app.py                              ✅ Updated to use FirestoreService
├── requirements.txt                    ✅ Updated (Firestore instead of MongoDB)
├── Dockerfile                          ✅ Ready
├── deploy.sh                           ✅ Ready
├── setup.sh                            ✅ Ready
├── .env                                ⚠️  YOU CREATE (see template below)
├── credentials.json                    ⚠️  YOU CREATE (from Google Cloud)
├── apns_cert.pem                       ⚠️  YOU CREATE (from Apple Developer)
├── apns_key.pem                        ⚠️  YOU CREATE (from Apple Developer)
├── services/
│   ├── __init__.py                     ✅ Ready
│   ├── firestore_service.py            ✅ NEW (replaces mongodb_service.py)
│   ├── pubsub_service.py               ✅ Ready
│   ├── gmail_service.py                ✅ Ready
│   ├── apns_service.py                 ✅ Ready
│   └── transaction_parser.py           ✅ Ready
├── README.md                           ✅ Updated for Firestore
└── ARCHITECTURE.md                     ✅ Ready
```

## iOS App Files ✅ All Complete

```
BudgetInsight/
├── BudgetInsightApp.swift              ✅ Updated with AppDelegate
├── AppDelegate.swift                   ✅ NEW (push notifications)
├── Models/
│   ├── UserIncome.swift                ✅ Complete
│   ├── BudgetCategory.swift            ✅ Complete
│   ├── BudgetAllocation.swift          ✅ Complete
│   └── PeriodSnapshot.swift            ✅ Complete
├── Services/
│   ├── BudgetService.swift             ✅ Refactored
│   ├── TaxService.swift                ✅ Complete
│   ├── SnapshotService.swift           ✅ Complete
│   └── BackendService.swift            ✅ NEW (API client)
├── ViewModels/
│   ├── DashboardViewModel.swift        ✅ Updated with backend sync
│   ├── BudgetViewModel.swift           ✅ Updated with backend sync
│   └── HistoryViewModel.swift          ✅ Complete
├── Views/
│   ├── ContentView.swift               ✅ Updated with backend registration
│   ├── MainTabView.swift               ✅ Complete (3 tabs)
│   ├── DashboardView.swift             ✅ Redesigned with circular rings
│   ├── MyBudgetView.swift              ✅ Complete
│   ├── GrandSchemeView.swift           ✅ Complete
│   ├── BackendRegistrationView.swift   ✅ NEW (user registration)
│   └── Components/
│       ├── CircularProgressRing.swift  ✅ Complete
│       ├── DashboardCategoryCard.swift ✅ Complete
│       ├── CalendarView.swift          ✅ Complete
│       └── GraphView.swift             ✅ Complete
```

## Documentation Files ✅ All Complete

```
/
├── INTEGRATION_GUIDE.md                ✅ Updated for Firestore
├── BACKEND_QUICK_START.md              ✅ Updated for Firestore (20 min setup)
├── FIRESTORE_STRUCTURE.md              ✅ NEW (data structure docs)
├── FIRESTORE_MIGRATION_SUMMARY.md      ✅ NEW (migration guide)
└── UPDATED_FILE_STRUCTURE.md           ✅ THIS FILE
```

---

## Environment Variables Template

### Create `backend/.env`:

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

---

## Files to Add to Xcode Project

These files need to be manually added to Xcode:

1. **BudgetInsight/Services/BackendService.swift**
2. **BudgetInsight/AppDelegate.swift**
3. **BudgetInsight/Views/BackendRegistrationView.swift**

**How to add:**
1. Right-click folder in Xcode
2. "Add Files to BudgetInsight..."
3. Select the file
4. Ensure "Copy items if needed" is checked
5. Click "Add"

---

## Xcode Capabilities to Enable

1. **Push Notifications**
   - Target → Signing & Capabilities
   - Click "+ Capability"
   - Add "Push Notifications"

2. **Background Modes**
   - Click "+ Capability"
   - Add "Background Modes"
   - Enable: "Remote notifications"

---

## What You Need to Create

### 1. Google Cloud Credentials (credentials.json)
```bash
gcloud iam service-accounts keys create backend/credentials.json \
    --iam-account=budgetinsight-backend@PROJECT_ID.iam.gserviceaccount.com
```

### 2. APNs Certificate (apns_cert.pem)
```bash
# Download .cer from Apple Developer Portal
openssl x509 -in aps.cer -inform DER -out backend/apns_cert.pem -outform PEM
```

### 3. APNs Key (apns_key.pem)
```bash
# Export private key from Keychain as .p12
openssl pkcs12 -in key.p12 -out backend/apns_key.pem -nodes -clcerts
```

### 4. Firestore Database
```bash
# Enable API
gcloud services enable firestore.googleapis.com

# Create database in console
# Go to console.cloud.google.com/firestore
# Click "Create Database" → "Native mode" → Choose location
```

---

## Deployment Checklist

- [ ] Google Cloud project created
- [ ] Firestore database created (Native mode)
- [ ] Service account credentials downloaded (credentials.json)
- [ ] Pub/Sub topic created
- [ ] APNs certificate created (apns_cert.pem)
- [ ] APNs key created (apns_key.pem)
- [ ] backend/.env file configured
- [ ] Backend deployed to Cloud Run
- [ ] Pub/Sub subscription configured with Cloud Run URL
- [ ] iOS app files added to Xcode project
- [ ] Push Notifications capability enabled
- [ ] Background Modes enabled
- [ ] BackendService.swift updated with Cloud Run URL
- [ ] App tested on physical device

---

## Quick Setup Commands

```bash
# 1. Setup Google Cloud
gcloud projects create budgetinsight-backend
gcloud config set project budgetinsight-backend
gcloud services enable firestore.googleapis.com gmail.googleapis.com pubsub.googleapis.com run.googleapis.com

# 2. Create Firestore database
# Go to console.cloud.google.com/firestore → Create Database → Native mode

# 3. Create service account
gcloud iam service-accounts create budgetinsight-backend
gcloud iam service-accounts keys create backend/credentials.json \
    --iam-account=budgetinsight-backend@budgetinsight-backend.iam.gserviceaccount.com

# 4. Create Pub/Sub topic
gcloud pubsub topics create gmail-notifications

# 5. Deploy backend
cd backend
chmod +x deploy.sh
./deploy.sh

# 6. Get Cloud Run URL
gcloud run services describe budgetinsight-backend --region=us-central1 --format='value(status.url)'

# 7. Create Pub/Sub subscription
gcloud pubsub subscriptions create gmail-push-sub \
    --topic=gmail-notifications \
    --push-endpoint=https://YOUR_CLOUD_RUN_URL/webhooks/gmail
```

---

## Testing Commands

```bash
# Test backend health
curl https://YOUR_CLOUD_RUN_URL/health

# Register user
curl -X POST https://YOUR_CLOUD_RUN_URL/api/users/register \
  -H "Content-Type: application/json" \
  -d '{"email": "test@example.com"}'

# Upload transaction
curl -X POST https://YOUR_CLOUD_RUN_URL/api/users/USER_ID/transactions \
  -H "Content-Type: application/json" \
  -d '{"amount": 50.00, "merchant": "Test Store", "date": "2025-12-26T12:00:00Z"}'
```

---

## Next Steps

1. **Follow BACKEND_QUICK_START.md** for step-by-step setup
2. **Add iOS files to Xcode** as listed above
3. **Enable Xcode capabilities** as listed above
4. **Deploy backend** using deploy.sh
5. **Update BackendService.swift** with your Cloud Run URL
6. **Test on physical device** (simulator doesn't support push notifications)

---

**All files are ready!** 🎉

Follow the quick start guide and you'll have a fully functional backend with Firestore in ~20 minutes.

---

**Last Updated**: December 26, 2025
