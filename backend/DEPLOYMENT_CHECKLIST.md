# ✅ BudgetInsight Deployment Checklist

Print this out or check off as you go!

---

## Phase 1: Google Cloud Setup

### Prerequisites
- [ ] Google Cloud account created
- [ ] Billing enabled on account
- [ ] gcloud CLI installed on computer
- [ ] Logged in: `gcloud auth login`

### Run Setup Script
- [ ] Navigate to backend directory: `cd backend`
- [ ] Run: `./setup_cloud.sh`
- [ ] Script completes without errors

### Manual Steps
- [ ] Firestore database created in Console
  - [ ] Selected **Native mode** (not Datastore)
  - [ ] Location: **us-central1**
  - [ ] Database status: **Active**

### Verify
- [ ] `credentials.json` exists in backend/
- [ ] `.env` file created in backend/
- [ ] Pub/Sub topic exists: `gcloud pubsub topics list`

---

## Phase 2: APNs Certificates

### Get Certificate from Apple
- [ ] Logged into developer.apple.com
- [ ] Created APNs certificate for app
- [ ] Downloaded .cer file
- [ ] Exported as .p12 from Keychain

### Convert to PEM
- [ ] Ran: `openssl pkcs12 -in cert.p12 -out apns_cert.pem -clcerts -nokeys`
- [ ] Ran: `openssl pkcs12 -in cert.p12 -out apns_key.pem -nocerts -nodes`
- [ ] Files exist: `apns_cert.pem` and `apns_key.pem`

### Update Configuration
- [ ] Edited `.env` file
- [ ] Set `APNS_BUNDLE_ID=com.yourcompany.BudgetInsight`
- [ ] Set `APNS_USE_SANDBOX=true` (for development)

---

## Phase 3: Deploy Backend

### Deploy to Cloud Run
- [ ] In backend directory
- [ ] Run: `./deploy.sh`
- [ ] Build completes successfully
- [ ] Deployment completes successfully
- [ ] Service URL displayed

### Record Information
- [ ] Service URL saved: `_________________________________`
- [ ] Project ID saved: `_________________________________`

### Test Deployment
- [ ] Run: `curl https://YOUR_URL/health`
- [ ] Response shows: `"status": "healthy"`
- [ ] Response shows: `"firestore": true`

---

## Phase 4: Pub/Sub Configuration

### Create Subscription
- [ ] Replaced YOUR_CLOUD_RUN_URL in command
- [ ] Run: `gcloud pubsub subscriptions create gmail-push-sub --topic=gmail-notifications --push-endpoint=YOUR_URL/webhooks/gmail --ack-deadline=30`
- [ ] Subscription created successfully

### Verify
- [ ] Run: `gcloud pubsub subscriptions describe gmail-push-sub`
- [ ] Shows correct push endpoint URL

---

## Phase 5: Gmail Setup

### Create OAuth Credentials
- [ ] Go to console.cloud.google.com/apis/credentials
- [ ] Create OAuth client ID
- [ ] Type: **Desktop app**
- [ ] Downloaded JSON file
- [ ] Saved as `backend/credentials_oauth.json`

### Configure Gmail Watch
- [ ] Run: `python3 setup_gmail_push.py --email your.email@gmail.com`
- [ ] Browser opened for authentication
- [ ] Granted Gmail access
- [ ] Watch configured successfully
- [ ] Expiration date noted: `_________________________________`

### Test Gmail Connection
- [ ] Run: `python3 setup_gmail_push.py --test`
- [ ] Shows: `✅ Gmail API connection successful!`

---

## Phase 6: Auto-Renewal

### Setup Cloud Scheduler
- [ ] Run: `./setup_auto_renewal.sh`
- [ ] Cloud Scheduler job created
- [ ] Scheduled for daily 3 AM renewal

### Verify
- [ ] Run: `gcloud scheduler jobs list`
- [ ] Job `gmail-watch-renewal` appears in list

---

## Phase 7: iOS App Configuration

### Update Backend URL
- [ ] Opened `BackendService.swift` in Xcode
- [ ] Updated `baseURL = "https://YOUR_URL/api"`
- [ ] Saved file

### Add Files to Xcode (if not already)
- [ ] `Services/BackendService.swift` added to project
- [ ] `AppDelegate.swift` added to project  
- [ ] `Views/BackendRegistrationView.swift` added to project

### Enable Capabilities
- [ ] Selected project in Xcode
- [ ] Selected target → Signing & Capabilities
- [ ] Added **Push Notifications** capability
- [ ] Added **Background Modes** capability
- [ ] Checked **Remote notifications** in Background Modes

### Build Settings
- [ ] Bundle Identifier matches: `com.yourcompany.BudgetInsight`
- [ ] Development team selected
- [ ] Provisioning profile includes Push Notifications

---

## Phase 8: Testing

### Test Backend
- [ ] Health endpoint returns healthy: `curl YOUR_URL/health`
- [ ] Firestore console shows database: console.cloud.google.com/firestore
- [ ] Backend logs show no errors: `gcloud run services logs tail budgetinsight-backend --region=us-central1`

### Test Gmail Integration
- [ ] Forwarded old Discover email to yourself
- [ ] Backend logs show: `📧 Received Gmail notification`
- [ ] Backend logs show: `💰 Parsed 1 transaction alerts`
- [ ] Firestore shows new entry in `transaction_alerts`

### Test iOS App
- [ ] App builds successfully
- [ ] App runs on physical device (not simulator)
- [ ] App prompts for notification permission
- [ ] Granted notification permission
- [ ] Registered user with email in app
- [ ] Device token sent to backend

### End-to-End Test
- [ ] Made test purchase with Discover card
- [ ] Received Discover transaction email
- [ ] Received push notification on iPhone
- [ ] Opened app and saw transaction alert
- [ ] Created transaction from alert
- [ ] Transaction appears in dashboard
- [ ] Alert marked as linked in Firestore

---

## Phase 9: Production Readiness

### Security Check
- [ ] `.env` file NOT in git
- [ ] `credentials.json` NOT in git
- [ ] APNs certificates NOT in git
- [ ] OAuth credentials NOT in git
- [ ] `.gitignore` properly configured

### Monitoring Setup
- [ ] Checked Cloud Run metrics: console.cloud.google.com/run
- [ ] Set up billing alerts: console.cloud.google.com/billing
- [ ] Bookmarked Firestore console
- [ ] Bookmarked Cloud Run logs

### Documentation
- [ ] Backend URL documented
- [ ] Service account email saved
- [ ] Project ID documented
- [ ] APNs expiration date noted
- [ ] Gmail OAuth refresh token location known

---

## Optional: Production Hardening

### Switch to Production APNs
- [ ] Changed `.env`: `APNS_USE_SANDBOX=false`
- [ ] Obtained production APNs certificate
- [ ] Converted production certificate to PEM
- [ ] Redeployed backend

### Enhanced Security
- [ ] Added API key authentication
- [ ] Implemented rate limiting
- [ ] Set up Cloud Armor (DDoS protection)
- [ ] Configured CORS properly

### Monitoring & Alerts
- [ ] Set up Cloud Monitoring alerts
- [ ] Configure Uptime checks
- [ ] Set up error reporting
- [ ] Enable Cloud Logging exports

---

## Troubleshooting Reference

If something doesn't work:

**Backend won't deploy:**
- Check: `gcloud auth list`
- Check: `gcloud config get-value project`
- Check: Service account has correct IAM roles

**Firestore errors:**
- Verify: Database created in Native mode
- Verify: Service account has `datastore.user` role
- Check: credentials.json file exists and is valid

**No Gmail notifications:**
- Check: Gmail watch status with `python3 setup_gmail_push.py --test`
- Check: Pub/Sub subscription webhook URL is correct
- Check: Gmail API push permission granted
- Review: Backend logs for errors

**Push notifications not working:**
- Verify: Using physical device, not simulator
- Verify: Push Notifications capability enabled
- Verify: APNs certificate matches environment (sandbox/prod)
- Verify: Bundle ID matches APNs certificate
- Check: Device token successfully sent to backend

**Backend logs show errors:**
- Run: `gcloud run services logs tail budgetinsight-backend --region=us-central1 --limit=100`
- Look for: Python tracebacks, API errors, auth failures

---

## 🎉 Success Criteria

You're done when:

✅ Backend deployed and healthy  
✅ Firestore database operational  
✅ Gmail notifications triggering webhook  
✅ Transactions being saved to Firestore  
✅ iOS app receiving push notifications  
✅ Full flow working: Email → Parse → Save → Notify → Create Transaction  

---

## Support Resources

- **Full Guide:** `CLOUD_RUN_DEPLOYMENT.md`
- **Quick Reference:** `DEPLOYMENT_QUICK_REFERENCE.md`
- **Gmail Setup:** `GMAIL_PUSH_SETUP_GUIDE.md`
- **Data Schema:** `FIRESTORE_STRUCTURE.md`
- **Backend Docs:** `backend/README.md`

---

**Deployment Date:** _______________  
**Backend URL:** _______________  
**Project ID:** _______________  
**Gmail Watch Expires:** _______________  

---

Good luck! 🚀
