# Budget Insight

A minimalistic iOS finance tracking app that automatically captures transaction emails from your bank and helps you manage your budget with real-time notifications.

## Features

- **Automatic Email Parsing**: Receive transaction alerts from Discover Bank via Gmail
- **Real-Time Push Notifications**: Get notified instantly when transactions occur
- **At-a-Glance Dashboard**: See your financial status instantly on the home screen
- **Smart Budget Tracking**: Monitor monthly and yearly budgets by category
- **Cloud Sync**: Backend powered by Google Cloud (Cloud Run + Firestore)
- **Auto-Sync on Startup**: Fetches transactions, alerts, and historical data from backend
- **Minimalistic Design**: Clean, Apple-inspired interface
- **Privacy First**: Your data, your control with Firestore security rules

## How It Works

### System Architecture

```
Discover Bank → Gmail → Google Pub/Sub → Cloud Run Backend → iOS App
                                              ↓
                                          Firestore
```

1. **Transaction happens** at Discover Bank
2. **Email alert sent** to your Gmail
3. **Gmail push notification** triggers Google Pub/Sub
4. **Cloud Run backend** parses the email and extracts transaction details
5. **Push notification sent** to your iOS device
6. **Transaction saved** to Firestore
7. **iOS app syncs** and displays the transaction

## Tech Stack

### iOS App
- **Language**: Swift 5.9
- **UI Framework**: SwiftUI
- **Minimum iOS**: 16.0
- **Architecture**: MVVM
- **Push Notifications**: Apple Push Notification Service (APNs)

### Backend (Cloud Run)
- **Framework**: Flask (Python)
- **Database**: Google Cloud Firestore
- **Email Integration**: Gmail API
- **Push Notifications**: Google Cloud Pub/Sub
- **Hosting**: Google Cloud Run (serverless)
- **Authentication**: OAuth 2.0 + Service Accounts

## Project Structure

```
finance/
├── BudgetInsight/                    # iOS App
│   ├── Models/
│   │   ├── Transaction.swift
│   │   ├── Budget.swift
│   │   └── SpendingInsights.swift
│   ├── Views/
│   │   ├── DashboardView.swift
│   │   └── CategoryCard.swift
│   ├── ViewModels/
│   │   └── DashboardViewModel.swift
│   └── Services/
│       ├── BackendService.swift      # API client
│       └── KeychainService.swift
│
├── backend/                          # Cloud Run Backend
│   ├── app.py                        # Flask server
│   ├── services/
│   │   ├── firestore_service.py      # Database operations
│   │   ├── gmail_service.py          # Gmail API integration
│   │   ├── transaction_parser.py     # Email parsing
│   │   ├── apns_service.py          # Push notifications
│   │   └── pubsub_service.py        # Pub/Sub handling
│   ├── Dockerfile                    # Container config
│   └── requirements.txt
│
├── firestore.rules                   # Database security rules
└── firestore.indexes.json           # Database indexes
```

## Database Structure (Firestore)

### Collections:
1. **`users/{user_id}`** - User profile and metadata
   - Email, device tokens, last Gmail history ID

2. **`users/{user_id}/data/budget`** - Budget allocation
   - Annual salary, 401k, monthly take-home, categories

3. **`transactions/{transaction_id}`** - All spending transactions
   - Amount, merchant, category, date, linked alert

4. **`transaction_alerts/{alert_id}`** - Email alerts from Gmail
   - Email ID, amount, merchant, linking status

See [FIRESTORE_STRUCTURE.md](FIRESTORE_STRUCTURE.md) for complete schema.

## Setup Instructions

### Prerequisites

1. **Google Cloud Project** with billing enabled
2. **Xcode 15.0+** installed on your Mac
3. **iOS 16.0+** device (physical device required for push notifications)
4. **Apple Developer Account** (for APNs certificates)
5. **Gmail account** to monitor for transaction emails

### Backend Setup (Cloud Run)

1. **Install Google Cloud SDK**:
   ```bash
   brew install google-cloud-sdk
   gcloud auth login
   gcloud config set project YOUR_PROJECT_ID
   ```

2. **Deploy Firestore Security Rules**:
   ```bash
   firebase deploy --only firestore:rules
   firebase deploy --only firestore:indexes
   ```

3. **Deploy to Cloud Run**:
   ```bash
   cd backend
   ./deploy.sh
   ```
   
   Save the URL output (e.g., `https://budgetinsight-backend-xxx.run.app`)

4. **Setup Gmail Push Notifications**:
   ```bash
   cd backend
   python setup_gmail_push.py --email your.email@gmail.com
   ```

5. **Setup Auto-Renewal** (keeps Gmail watch active):
   ```bash
   ./setup_auto_renewal.sh
   ```

See [DEPLOYMENT_QUICK_REFERENCE.md](DEPLOYMENT_QUICK_REFERENCE.md) for detailed setup.

### iOS App Setup

1. **Update Backend URL** - See [BACKEND_SETUP.md](BACKEND_SETUP.md) for detailed instructions.

   **Quick Setup** - Add environment variable in Xcode:
   - Go to `Product` → `Scheme` → `Edit Scheme...` → `Run` → `Arguments`
   - Add environment variable:
     - Name: `BACKEND_URL`
     - Value: `https://your-cloud-run-url.run.app/api`

   Or update `BudgetInsight/Services/BackendService.swift` directly.

2. **Configure APNs** in Xcode:
   - Enable Push Notifications capability
   - Enable Background Modes → Remote notifications

3. **Build and Run**:
   - Open `BudgetInsight.xcodeproj`
   - Select your physical iOS device
   - Build and run (⌘R)

## API Endpoints

### User Management
- `POST /api/users/register` - Register new user with device token
- `PUT /api/users/{user_id}/device-token` - Update device token

### Transactions
- `GET /api/users/{user_id}/transactions` - Get all transactions
- `POST /api/users/{user_id}/transactions` - Create transaction
- `DELETE /api/transactions/{transaction_id}` - Delete transaction

### Budget
- `GET /api/users/{user_id}/budget` - Get budget data
- `POST /api/users/{user_id}/budget` - Save/update budget

### Transaction Alerts
- `GET /api/users/{user_id}/alerts` - Get unlinked email alerts
- `POST /api/alerts/{alert_id}/link` - Link alert to transaction

### Webhooks
- `POST /webhooks/gmail` - Gmail push notification receiver

## Cost Breakdown (Monthly)

### Google Cloud (for 100 users)
- **Cloud Run**: $0-5 (2M requests free tier)
- **Firestore**: $0 (1GB + 50K reads/day free tier)
- **Pub/Sub**: ~$0.40 per 1M messages
- **Cloud Scheduler**: $0.10/month (auto-renewal)

**Total: $0.50 - $6/month** (well within free tier for personal use)

### Development
- **Apple Developer**: $99/year
- **Domain (optional)**: ~$12/year

## Supported Banks

Currently supports:
- **Discover Bank** transaction emails

Email format expected:
```
Subject: Your Discover Purchase Alert
From: discover@services.discover.com

A purchase of $XX.XX was made at MERCHANT NAME on MM/DD/YYYY.
```

### Adding More Banks

To add support for other banks, update `backend/services/transaction_parser.py`:

```python
def parse_bank_email(message):
    # Add parsing logic for your bank's email format
    if 'chase' in sender:
        return parse_chase_email(message)
    elif 'amex' in sender:
        return parse_amex_email(message)
```

## Security Features

### Firestore Security Rules
- Only authenticated user (rachel.j.chen@gmail.com) can read/write
- Service account has full access for backend operations
- All other access denied

### Data Privacy
- No user data stored on external servers (besides Google Cloud)
- All calculations performed server-side or on-device
- Bank emails only store first 500 characters
- OAuth tokens stored securely in Firestore

## Testing

### Test Firestore Connection
```bash
cd backend
source venv/bin/activate
python test_firestore_write.py
python test_firestore_read.py
```

### Test Backend Health
```bash
curl https://your-cloud-run-url.run.app/health
```

### Test Push Notifications
Forward an old Discover transaction email to your monitored Gmail account and check if:
1. Backend parses it correctly (check Cloud Run logs)
2. Push notification arrives on iOS device
3. Transaction appears in app

## Troubleshooting

### Backend Issues

**Check Cloud Run Logs**:
```bash
gcloud run services logs tail budgetinsight-backend --region=us-central1
```

**Gmail Watch Expired**:
```bash
cd backend
python setup_gmail_push.py --email your.email@gmail.com
```

### iOS App Issues

**Push Notifications Not Working**:
- Ensure you're testing on a physical device (not simulator)
- Verify APNs certificates are valid
- Check device token is registered in Firestore

**Transactions Not Syncing**:
- Check backend URL is correct
- Verify internet connection
- Check Cloud Run logs for errors

### Firestore Issues

**Queries Failing**:
- Ensure indexes are deployed: `firebase deploy --only firestore:indexes`
- Check security rules: `firebase deploy --only firestore:rules`

## Future Enhancements

- [ ] Multi-bank support (Chase, AmEx, etc.)
- [ ] Custom budget categories
- [ ] Spending goals and milestones
- [ ] Export data to CSV
- [ ] Bill reminders
- [ ] Receipt scanning
- [ ] Budget sharing (family accounts)
- [ ] Advanced analytics and insights
- [ ] Dark mode support

## Resources

### Documentation
- [Firestore Structure](FIRESTORE_STRUCTURE.md) - Database schema
- [Architecture](backend/ARCHITECTURE.md) - System design
- [Deployment Guide](CLOUD_RUN_DEPLOYMENT.md) - Full setup walkthrough
- [Gmail Setup](GMAIL_PUSH_SETUP_GUIDE.md) - Gmail integration guide

### Google Cloud
- [Firestore Console](https://console.cloud.google.com/firestore)
- [Cloud Run Console](https://console.cloud.google.com/run)
- [Pub/Sub Console](https://console.cloud.google.com/cloudpubsub)

## License

This project is provided as-is for personal use.

## Acknowledgments

- **Google Cloud** for serverless infrastructure
- **Apple** for SwiftUI and APNs
- **Discover Bank** for consistent email formatting
