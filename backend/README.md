# BudgetInsight Backend Server

Python Flask backend server for BudgetInsight iOS app with Gmail Push Notifications, Firestore storage, and Apple Push Notifications.

## Features

- 📧 **Gmail Push Notifications**: Real-time email alerts via Google Cloud Pub/Sub
- 💾 **Firestore Storage**: Serverless NoSQL database for transactions and budgets
- 📱 **Apple Push Notifications**: Send alerts to iOS devices
- 🔐 **OAuth Integration**: Secure Gmail API access
- ⚡ **Real-time Processing**: Instant transaction alert parsing

## Architecture

```
Discover Email → Gmail → Google Pub/Sub → Flask Server → Firestore
                                                ↓
                                           APNs → iOS App
```

## Setup Instructions

### 1. Prerequisites

- Python 3.9+
- Google Cloud Project (with Firestore enabled)
- Apple Developer Account (for APNs)

### 2. Install Dependencies

```bash
cd backend
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
```

### 3. Google Cloud Setup

#### a. Create Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create a new project: "budgetinsight-backend"
3. Enable the following APIs:
   - Gmail API
   - Cloud Pub/Sub API

#### b. Create Service Account

1. Go to IAM & Admin → Service Accounts
2. Create service account: "budgetinsight-server"
3. Grant roles:
   - Pub/Sub Admin
   - Pub/Sub Editor
4. Create key (JSON) and download
5. Save as `backend/credentials/service-account-key.json`

#### c. Set Up Pub/Sub

1. Go to Pub/Sub → Topics
2. Create topic: `gmail-notifications`
3. Note the full topic name: `projects/YOUR_PROJECT_ID/topics/gmail-notifications`

#### d. Create Push Subscription

```bash
# After deploying your server, create subscription
gcloud pubsub subscriptions create gmail-notifications-sub \
  --topic=gmail-notifications \
  --push-endpoint=https://YOUR_DOMAIN.com/webhooks/gmail
```

### 4. Firestore Setup

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Select your project
3. Navigate to Firestore Database
4. Click "Create Database"
5. Choose "Native mode" (not Datastore mode)
6. Select a location (e.g., us-central1)
7. Click "Create"

No additional configuration needed - Firestore uses the same service account credentials!

### 5. Apple Push Notifications Setup

1. Go to [Apple Developer Portal](https://developer.apple.com)
2. Certificates, Identifiers & Profiles → Keys
3. Create new key with APNs enabled
4. Download `.p8` file
5. Save as `backend/credentials/AuthKey_XXXXXXXXXX.p8`
6. Note Key ID and Team ID

### 6. Configure Environment

```bash
cp .env.example .env
# Edit .env with your credentials
```

**Important `.env` variables:**

```bash
# Google Cloud
GOOGLE_CLOUD_PROJECT=your-project-id
GOOGLE_APPLICATION_CREDENTIALS=./credentials/service-account-key.json
GMAIL_WATCH_TOPIC=projects/your-project-id/topics/gmail-notifications

# APNs
APNS_KEY_ID=ABC123XYZ
APNS_TEAM_ID=DEF456UVW
APNS_AUTH_KEY_PATH=./credentials/AuthKey_ABC123XYZ.p8
APNS_BUNDLE_ID=com.yourcompany.BudgetInsight
APNS_USE_SANDBOX=True  # False for production
```

Note: Firestore credentials use `GOOGLE_APPLICATION_CREDENTIALS` - no separate database configuration needed!

### 7. Run Server

#### Development

```bash
python app.py
```

#### Production (with Gunicorn)

```bash
gunicorn -w 4 -b 0.0.0.0:8080 app:app
```

## Deployment to Google Cloud Run

### 1. Create Dockerfile

```dockerfile
FROM python:3.9-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

CMD exec gunicorn --bind :$PORT --workers 1 --threads 8 --timeout 0 app:app
```

### 2. Build and Deploy

```bash
# Build container
gcloud builds submit --tag gcr.io/YOUR_PROJECT_ID/budgetinsight-backend

# Deploy to Cloud Run
gcloud run deploy budgetinsight-backend \
  --image gcr.io/YOUR_PROJECT_ID/budgetinsight-backend \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars MONGODB_URI=$MONGODB_URI
```

### 3. Update Pub/Sub Subscription

```bash
# Get your Cloud Run URL
CLOUD_RUN_URL=$(gcloud run services describe budgetinsight-backend \
  --region us-central1 --format 'value(status.url)')

# Update subscription
gcloud pubsub subscriptions update gmail-notifications-sub \
  --push-endpoint=$CLOUD_RUN_URL/webhooks/gmail
```

## API Endpoints

### Health Check

```
GET /health
```

### User Registration

```
POST /api/users/register
{
  "user_id": "uuid",
  "email": "user@gmail.com",
  "device_token": "apns-token",
  "gmail_access_token": "oauth-token"
}
```

### Transactions

```
GET /api/users/{user_id}/transactions
POST /api/users/{user_id}/transactions
```

### Budget Data

```
GET /api/users/{user_id}/budget
POST /api/users/{user_id}/budget
```

### Snapshots

```
GET /api/users/{user_id}/snapshots?type=monthly
```

## Gmail Watch Setup

The server automatically sets up Gmail watch when a user registers. Gmail watch expires after 7 days and needs to be renewed.

To manually renew:

```bash
# The server should auto-renew, but you can trigger manually via API
POST /api/users/{user_id}/renew-watch
```

## Testing

### Test MongoDB Connection

```bash
python -c "from services.mongodb_service import MongoDBService; m = MongoDBService(); print('✅ Connected' if m.is_connected() else '❌ Failed')"
```

### Test Pub/Sub

```bash
python -c "from services.pubsub_service import PubSubService; p = PubSubService(); print('✅ Connected' if p.is_connected() else '❌ Failed')"
```

### Test Gmail Webhook (Local)

```bash
# Use ngrok to expose local server
ngrok http 8080

# Update Pub/Sub subscription with ngrok URL
gcloud pubsub subscriptions update gmail-notifications-sub \
  --push-endpoint=https://YOUR_NGROK_URL.ngrok.io/webhooks/gmail
```

## Monitoring

### Logs

```bash
# Local
tail -f logs/app.log

# Google Cloud Run
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=budgetinsight-backend" --limit 50
```

### Pub/Sub Metrics

```bash
gcloud pubsub subscriptions describe gmail-notifications-sub
```

## Security Considerations

1. **Never commit credentials** - Keep `.env` and `credentials/` in `.gitignore`
2. **Use HTTPS** - Required for Pub/Sub push endpoints
3. **Verify requests** - Implement JWT verification for Pub/Sub pushes
4. **Rate limiting** - Add rate limiting to prevent abuse
5. **Input validation** - Validate all API inputs

## Troubleshooting

### Gmail watch not receiving notifications

1. Check Pub/Sub subscription is active
2. Verify push endpoint is HTTPS and accessible
3. Check Gmail watch hasn't expired (7-day limit)
4. Verify service account has correct permissions

### MongoDB connection failed

1. Check MongoDB is running: `brew services list`
2. Verify connection string in `.env`
3. For Atlas, check IP whitelist and credentials

### APNs notifications not working

1. Verify using correct environment (sandbox vs production)
2. Check device token is valid
3. Verify `.p8` key file exists and Key ID is correct
4. Check bundle ID matches your app

## Cost Estimation

### Google Cloud (per month)

- Cloud Run: Free tier (2M requests, 360k GB-seconds)
- Pub/Sub: ~$0.40 per 1M messages
- Estimated: $5-20/month for moderate usage

### MongoDB Atlas

- Free tier: 512MB storage
- Shared cluster: Free
- Dedicated: Starting at $57/month

## Next Steps

1. Set up monitoring and alerting
2. Implement auto-renewal of Gmail watch
3. Add user authentication for API endpoints
4. Set up CI/CD pipeline
5. Add comprehensive error tracking (Sentry)
6. Implement caching layer (Redis)

## Support

For issues and questions, contact: your-email@example.com
