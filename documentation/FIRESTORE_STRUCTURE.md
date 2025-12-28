# Firestore Data Structure

## Overview

BudgetInsight uses Firestore to store only two main types of data:
1. **Transaction History** - All spending transactions
2. **Budget Allocation + Income** - User's budget categories and income info

This simplified structure keeps costs in the free tier and makes sync fast.

---

## Collections Structure

```
firestore/
├── users/
│   └── {user_id}/
│       └── data/
│           └── budget (document)
├── transactions/
│   └── {transaction_id} (documents)
└── transaction_alerts/
    └── {alert_id} (documents)
```

---

## 1. Users Collection

**Path**: `users/{user_id}`

### User Document
```json
{
  "user_id": "abc123",
  "email": "user@example.com",
  "device_tokens": ["apns_token_1", "apns_token_2"],
  "last_history_id": "12345",
  "created_at": "2025-12-26T12:00:00Z",
  "updated_at": "2025-12-26T13:30:00Z"
}
```

### Budget Subcollection
**Path**: `users/{user_id}/data/budget`

```json
{
  "user_id": "abc123",
  "annual_salary": 85000,
  "contribution_401k": 5000,
  "monthly_take_home": 5200,
  "categories": [
    {
      "name": "Food & Dining",
      "percentage": 15.0,
      "icon": "fork.knife",
      "color": "blue"
    },
    {
      "name": "Transportation",
      "percentage": 10.0,
      "icon": "car.fill",
      "color": "green"
    }
  ],
  "updated_at": "2025-12-26T12:00:00Z"
}
```

**Why subcollection?**: Keeps budget data nested under user, making it easy to fetch all user data at once.

---

## 2. Transactions Collection

**Path**: `transactions/{transaction_id}`

### Transaction Document
```json
{
  "transaction_id": "tx_123456",
  "user_id": "abc123",
  "amount": 45.67,
  "merchant": "Whole Foods",
  "category": "Food & Dining",
  "date": "2025-12-26T10:30:00Z",
  "linked_email_alert_id": "email_msg_123",
  "created_at": "2025-12-26T10:35:00Z"
}
```

**Note**: If `linked_email_alert_id` is `null`, the transaction was created manually. If it has a value, it was created from an email alert.

**Indexes**:
- `user_id` (for querying user's transactions)
- `date` (for sorting by date)

---

## 3. Transaction Alerts Collection

**Path**: `transaction_alerts/{alert_id}`

### Alert Document
```json
{
  "email_id": "email_msg_123",
  "user_id": "abc123",
  "amount": 45.67,
  "merchant": "Whole Foods",
  "date": "2025-12-26T10:30:00Z",
  "is_linked": false,
  "linked_transaction_id": null,
  "linked_at": null,
  "created_at": "2025-12-26T10:31:00Z"
}
```

**Purpose**: Stores email alerts from Gmail that haven't been converted to transactions yet.

**Indexes**:
- `user_id` + `is_linked` (for finding unlinked alerts)

---

## Queries Used by Backend

### Get User Budget
```python
db.collection("users").document(user_id).collection("data").document("budget").get()
```

### Get User Transactions
```python
db.collection("transactions") \
  .where("user_id", "==", user_id) \
  .order_by("date", direction=firestore.Query.DESCENDING) \
  .limit(1000) \
  .stream()
```

### Get Unlinked Alerts
```python
db.collection("transaction_alerts") \
  .where("user_id", "==", user_id) \
  .where("is_linked", "==", False) \
  .order_by("created_at", direction=firestore.Query.DESCENDING) \
  .stream()
```

### Save Transaction
```python
db.collection("transactions").document(transaction_id).set(transaction_data)
```

### Update Budget
```python
db.collection("users").document(user_id) \
  .collection("data").document("budget") \
  .set(budget_data, merge=True)
```

---

## Data Flow

### When Transaction Email Arrives:
1. Gmail → Pub/Sub → Backend webhook
2. Backend parses email → Creates alert document in `transaction_alerts`
3. Backend sends APNs push to iOS device
4. User sees notification → Opens app
5. App syncs transactions from backend
6. User creates transaction from alert
7. Backend creates transaction document in `transactions`
8. Backend marks alert as `is_linked: true`

### When User Updates Budget:
1. iOS app → Backend API
2. Backend updates `users/{user_id}/data/budget` document
3. Changes synced across devices instantly

---

## Free Tier Limits

Firestore Free Tier (per day):
- **Reads**: 50,000
- **Writes**: 20,000
- **Deletes**: 20,000
- **Storage**: 1 GB

**Estimated Usage**:
- 10 transactions/day = 10 writes
- 50 budget syncs/day = 50 writes
- 100 app opens (transaction queries) = 100 reads
- Total: ~150 operations/day = **Well within free tier!**

---

## Security Rules

To add security to your Firestore database:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Users can only read/write their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      match /data/{document=**} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }
    
    // Transactions can only be read/written by owner
    match /transactions/{transactionId} {
      allow read, write: if request.auth != null && 
                            resource.data.user_id == request.auth.uid;
    }
    
    // Transaction alerts same as transactions
    match /transaction_alerts/{alertId} {
      allow read, write: if request.auth != null && 
                            resource.data.user_id == request.auth.uid;
    }
  }
}
```

**Note**: These rules assume Firebase Authentication. For service account access (from your backend), you'll need to grant the service account the `Cloud Datastore User` role.

---

## Backup Strategy

### Automatic Backups
1. Go to [Firestore Console](https://console.cloud.google.com/firestore)
2. Settings → Import/Export
3. Set up scheduled exports to Cloud Storage bucket
4. Recommended: Daily exports at 2 AM

### Manual Backup
```bash
# Export entire database
gcloud firestore export gs://your-bucket-name/firestore-backups/$(date +%Y%m%d)
```

---

## Cost Optimization Tips

1. **Batch Reads**: Fetch multiple transactions in one query instead of individual reads
2. **Cache on iOS**: Store transactions locally and only sync changes
3. **Limit Query Results**: Use `.limit(1000)` to avoid fetching entire history
4. **Use Merge**: When updating budget, use `merge=True` to only write changed fields
5. **Delete Old Alerts**: Clean up linked alerts after 30 days to save storage

---

## Monitoring

### View Data in Console
- Go to [Firestore Console](https://console.cloud.google.com/firestore)
- Browse collections and documents
- View real-time updates

### Check Usage
- Firestore → Usage tab
- Monitor reads, writes, deletes per day
- Set up billing alerts if approaching limits

---

## Advantages of Firestore vs MongoDB

✅ **No separate database setup** - uses same Google Cloud credentials  
✅ **Serverless** - no server to manage or connect to  
✅ **Free tier** - 1GB storage + 50K reads/day  
✅ **Real-time sync** - automatic updates across devices  
✅ **Built-in indexes** - fast queries without configuration  
✅ **Google Cloud integration** - works seamlessly with Cloud Run  

---

## Example: Complete User Data

Here's what one user's data looks like in Firestore:

```
users/user_abc123/
  - email: "rachel@example.com"
  - device_tokens: ["apns_token_xyz"]
  - last_history_id: "12345"
  
  data/budget/
    - annual_salary: 85000
    - contribution_401k: 5000
    - monthly_take_home: 5200
    - categories: [...]

transactions/
  - tx_001 (user_id: "user_abc123", amount: 45.67, merchant: "Whole Foods")
  - tx_002 (user_id: "user_abc123", amount: 12.50, merchant: "Starbucks")
  - tx_003 (user_id: "user_abc123", amount: 89.99, merchant: "Amazon")

transaction_alerts/
  - alert_001 (user_id: "user_abc123", is_linked: true, ...)
  - alert_002 (user_id: "user_abc123", is_linked: false, ...)
```

**Total Storage**: ~5 KB per user with 100 transactions = Well under free tier!

---

**Last Updated**: December 26, 2025
