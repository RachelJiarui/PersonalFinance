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
│  Flask Server   │─────→│   MongoDB   │
│  (Cloud Run)    │      │   (Atlas)   │
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
6. Server saves transaction alert to MongoDB
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
3. Server saves user to MongoDB
4. Server calls Gmail API to setup watch
5. Gmail starts monitoring user's inbox
```

### 3. Data Sync Flow

```
1. iOS app sends transaction to POST /api/users/{user_id}/transactions
2. Server saves to MongoDB
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

### MongoDB Collections

**users**
```javascript
{
  _id: ObjectId,
  user_id: String,
  email: String,
  device_tokens: [String],
  gmail_access_token: String,
  last_history_id: String,
  created_at: DateTime,
  updated_at: DateTime
}
```

**transaction_alerts**
```javascript
{
  _id: ObjectId,
  user_id: String,
  email_id: String,
  merchant: String,
  amount: Number,
  date: DateTime,
  raw_email_body: String,
  is_linked: Boolean,
  linked_transaction_id: String,
  created_at: DateTime
}
```

**transactions**
```javascript
{
  _id: ObjectId,
  user_id: String,
  amount: Number,
  merchant: String,
  date: DateTime,
  category: [String],
  pending: Boolean,
  linked_email_alert_id: String, // null if manually created, otherwise email alert ID
  created_at: DateTime
}
```

**budgets**
```javascript
{
  _id: ObjectId,
  user_id: String,
  income: {
    annualSalary: Number,
    contribution401k: Number,
    federalTax: Number,
    socialSecurityTax: Number,
    medicareTax: Number,
    nyStateTax: Number,
    nycTax: Number
  },
  allocation: {
    categories: [{
      id: String,
      name: String,
      percentage: Number,
      icon: String,
      color: String,
      currentMonthSpent: Number
    }],
    emergencyBufferId: String
  },
  updated_at: DateTime
}
```

**snapshots**
```javascript
{
  _id: ObjectId,
  user_id: String,
  year: Number,
  month: Number, // null for yearly
  period_type: String, // "monthly" or "yearly"
  monthlyTakeHome: Number,
  totalSpending: Number,
  savings: Number,
  transactionCount: Number,
  created_at: DateTime
}
```

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

**MongoDBService** (`services/mongodb_service.py`)
- User CRUD operations
- Transaction CRUD operations
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
2. **Token Storage**: OAuth tokens encrypted in MongoDB
3. **Pub/Sub Verification**: Verify webhook requests from Google
4. **Rate Limiting**: Prevent API abuse (TODO)

### Privacy

1. **Email Content**: Only store first 500 chars of email body
2. **User Data**: Stored in user's own MongoDB instance
3. **Token Expiry**: Gmail access tokens refreshed automatically

## Scaling

### Current Capacity

- **Concurrent Users**: 100-1000
- **Requests/Second**: ~100
- **Database**: 512MB (free tier)

### Scaling Strategy

1. **Horizontal Scaling**: Cloud Run auto-scales instances
2. **Database Sharding**: Use MongoDB sharding for 10k+ users
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

### MongoDB Atlas

- Free Tier: $0 (512MB)
- M2 Shared: $9/month (2GB)
- M10 Dedicated: $57/month (10GB)

**Estimate**: $0-9/month for 100 users

### Total: $5-25/month

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
