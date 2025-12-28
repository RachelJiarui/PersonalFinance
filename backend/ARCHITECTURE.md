# BudgetInsight Backend Architecture

## System Overview

```
┌─────────────────┐
│  Discover Bank  │
└────────┬────────┘
         │ (sends email)
         ↓
┌─────────────────┐
│     Gmail       │
└────────┬────────┘
         │ (push notification)
         ↓
┌─────────────────┐
│ Google Pub/Sub  │
└────────┬────────┘
         │ (webhook)
         ↓
┌─────────────────┐      ┌─────────────┐
│  Flask Server   │─────→│  Firestore  │
│  (Cloud Run)    │      │             │
└────────┬────────┘      └─────────────┘
         │ (push notification)
         ↓
┌─────────────────┐
│      APNs       │
└────────┬────────┘
         │
         ↓
┌─────────────────┐
│   iOS App       │
│ (BudgetInsight) │
└─────────────────┘
```

## Data Flow

### 1. Transaction Alert Flow

```
1. Discover sends transaction email to user's Gmail
2. Gmail triggers push notification to Pub/Sub topic
3. Pub/Sub sends webhook POST to /webhooks/gmail
4. Server fetches email history from Gmail API
5. Server parses transaction from email body
6. Server saves transaction alert to Firestore
7. Server sends push notification to user's iOS device
8. iOS app shows "Needs Entry" banner
```

### 2. User Registration Flow

```
1. iOS app authenticates with Gmail OAuth
2. iOS app calls POST /api/users/register with:
   - user_id
   - email
   - device_token (APNs)
   - gmail_access_token
3. Server saves user to Firestore
4. Server calls Gmail API to setup watch
5. Gmail starts monitoring user's inbox
```

### 3. Data Sync Flow

```
1. iOS app sends transaction to POST /api/users/{user_id}/transactions
2. Server saves to Firestore
3. iOS app periodically fetches GET /api/users/{user_id}/transactions
4. iOS app syncs budget data via POST /api/users/{user_id}/budget
```

## Components

### Flask Server (`app.py`)

**Endpoints:**
- `GET /health` - Health check
- `POST /webhooks/gmail` - Gmail push notification receiver
- `POST /api/users/register` - Register new user
- `PUT /api/users/{user_id}/device-token` - Update device token
- `GET /api/users/{user_id}/transactions` - Get transactions
- `POST /api/users/{user_id}/transactions` - Save transaction
- `GET /api/users/{user_id}/budget` - Get budget
- `POST /api/users/{user_id}/budget` - Save budget
- `GET /api/users/{user_id}/snapshots` - Get snapshots

### Firestore Collections

See [FIRESTORE_STRUCTURE.md](../FIRESTORE_STRUCTURE.md) for complete data structure documentation.

**Summary:**
- `users/{user_id}` - User profile and metadata
- `users/{user_id}/data/budget` - Budget allocation and income
- `transactions/{transaction_id}` - All spending transactions
- `transaction_alerts/{alert_id}` - Email alerts from Gmail
- `snapshots/{snapshot_id}` - Monthly/yearly aggregated data (optional)

### Services

**GmailService** (`services/gmail_service.py`)
- `setup_watch()` - Set up Gmail push notifications
- `get_message_history()` - Fetch new messages since last history ID
- `get_message()` - Get full message details
- `is_from_sender()` - Check if message is from Discover

**PubSubService** (`services/pubsub_service.py`)
- `verify_push_request()` - Verify webhook is from Google
- `create_topic()` - Create Pub/Sub topic
- `create_subscription()` - Create push subscription
- `get_topic_path()` - Get topic path for Gmail watch

**FirestoreService** (`services/firestore_service.py`)
- User CRUD operations
- Transaction CRUD operations
- Transaction alert CRUD operations
- Budget CRUD operations
- Snapshot CRUD operations

**APNsService** (`services/apns_service.py`)
- `send_notification()` - Send push notification to iOS
- `send_silent_notification()` - Send background update

**TransactionParser** (`services/transaction_parser.py`)
- `parse_discover_email()` - Extract transaction from email

## Security

### Authentication

1. **Gmail OAuth**: User authenticates via OAuth 2.0
2. **Service Account**: Server uses service account for Pub/Sub
3. **APNs Token Auth**: Server uses .p8 key for push notifications

### Data Protection

1. **HTTPS Only**: All endpoints require HTTPS
2. **Token Storage**: OAuth tokens stored in Firestore
3. **Pub/Sub Verification**: Verify webhook requests from Google
4. **Rate Limiting**: Prevent API abuse (TODO)

### Privacy

1. **Email Content**: Only store first 500 chars of email body
2. **User Data**: Stored in Firestore with security rules
3. **Token Expiry**: Gmail access tokens refreshed automatically

## Scaling

### Current Capacity

- **Concurrent Users**: 100-1000
- **Requests/Second**: ~100
- **Database**: 1GB storage, 50K reads/day (free tier)

### Scaling Strategy

1. **Horizontal Scaling**: Cloud Run auto-scales instances
2. **Database Scaling**: Firestore scales automatically
3. **Caching**: Add Redis for frequently accessed data
4. **CDN**: Use Cloud CDN for static assets
5. **Load Balancing**: Cloud Run handles automatically

## Monitoring

### Metrics to Track

1. **Request Latency**: API response times
2. **Error Rate**: 4xx and 5xx responses
3. **Pub/Sub Messages**: Message delivery rate
4. **APNs Success**: Push notification delivery
5. **Database Performance**: Query times

### Alerts

1. **High Error Rate**: >5% errors in 5 minutes
2. **High Latency**: >2s response time
3. **Pub/Sub Backlog**: >100 undelivered messages
4. **Database Down**: Connection failures

## Cost Breakdown (Monthly)

### Google Cloud

- Cloud Run: $0-5 (free tier covers 2M requests)
- Pub/Sub: ~$0.40 per 1M messages
- Storage: ~$0.02 per GB

**Estimate**: $5-15/month for 100 users

### Firestore

- Free Tier: $0 (1GB storage, 50K reads/day, 20K writes/day)
- Pay-as-you-go: $0.18/GB storage, $0.06 per 100K reads, $0.18 per 100K writes

**Estimate**: $0/month for 100 users (well within free tier)

### Total: $5-15/month

## Performance Targets

- **API Response Time**: <200ms (p95)
- **Webhook Processing**: <500ms
- **Push Notification**: <2s end-to-end
- **Email to Alert**: <5s total
- **Database Query**: <50ms

## Future Enhancements

1. **Auto-renew Gmail Watch**: Automatically renew every 6 days
2. **Multi-bank Support**: Parse alerts from Chase, AmEx, etc.
3. **Webhook Retry**: Retry failed webhook deliveries
4. **Analytics**: Track spending patterns
5. **Budget Recommendations**: ML-powered budget suggestions
6. **Family Accounts**: Multi-user budget sharing
7. **Export Data**: CSV/PDF export functionality
8. **Audit Logs**: Track all data changes
