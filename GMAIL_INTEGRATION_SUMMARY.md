# Gmail API Integration - Implementation Summary

## Overview

Successfully implemented Gmail API integration with Pub/Sub to automatically capture Discover card transaction emails and display them as alerts in the app.

## What Was Built

### Backend (Python/Flask)

1. **Gmail OAuth Service** (`backend/services/gmail_service.py`)
   - OAuth 2.0 flow for Gmail authentication
   - Token storage in Firestore
   - Gmail API message fetching
   - Push notification setup via Gmail watch API
   - Message parsing (headers and body extraction)

2. **Email Parser** (`backend/services/email_parser.py`)
   - Detects Discover transaction alert emails
   - Parses merchant, date, amount, and card details
   - Regex-based extraction from email body

3. **Pub/Sub Handler** (`backend/services/pubsub_handler.py`)
   - Receives Gmail push notifications
   - Processes new messages from inbox
   - Filters for Discover transaction alerts
   - Creates TransactionAlert documents

4. **Firestore Service Extensions** (`backend/services/firestore_service.py`)
   - TransactionAlert CRUD operations
   - Duplicate prevention via email_id
   - Query by resolution status

5. **API Endpoints** (`backend/app.py`)
   - `GET /api/gmail/auth/status` - Check authentication status
   - `GET /api/gmail/auth/start` - Start OAuth flow
   - `GET /api/gmail/oauth/callback` - Handle OAuth redirect
   - `POST /api/gmail/pubsub/webhook` - Receive Pub/Sub notifications
   - `GET /api/transaction-alerts` - List alerts
   - `GET /api/transaction-alerts/<id>` - Get specific alert
   - `PUT /api/transaction-alerts/<id>` - Update alert
   - `DELETE /api/transaction-alerts/<id>` - Delete alert

### Frontend (Swift/SwiftUI)

1. **TransactionAlert Model** (`BudgetInsight/Models/TransactionAlert.swift`)
   - Data model matching backend schema
   - Codable for API serialization
   - Resolution tracking

2. **TransactionAlertsView** (`BudgetInsight/Views/TransactionAlertsView.swift`)
   - List view showing unresolved and resolved alerts
   - Swipe-to-delete functionality
   - Pull-to-refresh
   - Empty state UI

3. **Dashboard Integration** (`BudgetInsight/Views/DashboardView.swift`)
   - "Connect Gmail" menu option
   - "Transaction Alerts" menu option
   - Sheet presentation for alerts view

4. **DashboardViewModel Extension** (`BudgetInsight/ViewModels/DashboardViewModel.swift`)
   - `connectGmail()` method to initiate OAuth
   - Opens Safari for authentication

## Data Model

### TransactionAlert Firestore Schema

```typescript
{
  email_id: string,              // Gmail message ID (unique)
  merchant: string,              // e.g., "PSPT BOSTON2 PRK"
  transaction_date: timestamp,   // Parsed from email
  amount: number,                // e.g., 2.35
  raw_email_body: string,        // Full email text
  card_last4: string?,           // e.g., "9520"
  received_at: timestamp,        // When alert was created
  is_resolved: boolean,          // Default false
  resolved_transaction_id: string?, // Link to Transaction doc
  created_at: timestamp,
  updated_at: timestamp
}
```

## How It Works

### Flow Diagram

```
1. User makes purchase with Discover card
   ↓
2. Discover sends email to rachel.j.chen@gmail.com
   ↓
3. Gmail triggers Pub/Sub notification
   ↓
4. Pub/Sub push subscription forwards to webhook
   ↓
5. Backend fetches email via Gmail API
   ↓
6. Parser extracts transaction details
   ↓
7. TransactionAlert stored in Firestore
   ↓
8. User opens "Transaction Alerts" in app
   ↓
9. App displays alert with merchant, date, amount
```

### Email Parsing Example

**Input Email:**
```
Subject: Transaction Alert
From: Discover Card <discover@services.discover.com>

A transaction above the limit you set has been initiated.

Merchant: PSPT BOSTON2 PRK
Date: December 30, 2025
Amount: $2.35
```

**Parsed Output:**
```json
{
  "merchant": "PSPT BOSTON2 PRK",
  "transaction_date": "2025-12-30T00:00:00Z",
  "amount": 2.35,
  "card_last4": "9520"
}
```

## Files Created/Modified

### Backend
- ✅ `backend/requirements.txt` - Added Gmail API packages
- ✅ `backend/services/gmail_service.py` - New
- ✅ `backend/services/email_parser.py` - New
- ✅ `backend/services/pubsub_handler.py` - New
- ✅ `backend/services/firestore_service.py` - Added TransactionAlert methods
- ✅ `backend/app.py` - Added Gmail and TransactionAlert endpoints
- ✅ `backend/GMAIL_SETUP.md` - Setup documentation

### Frontend
- ✅ `BudgetInsight/Models/TransactionAlert.swift` - New model
- ✅ `BudgetInsight/Views/TransactionAlertsView.swift` - New view
- ✅ `BudgetInsight/Views/DashboardView.swift` - Added menu items
- ✅ `BudgetInsight/ViewModels/DashboardViewModel.swift` - Added connectGmail()

## What You Need to Do

### 1. Complete OAuth Setup

Follow the steps in `backend/GMAIL_SETUP.md`:

1. Create OAuth Client ID in Google Cloud Console
   - Redirect URI: `https://budgetinsight-backend-ofgbl6d3ea-uc.a.run.app/api/gmail/oauth/callback`
   
2. Add credentials to backend `.env`:
   ```bash
   GMAIL_CLIENT_ID=your-client-id.apps.googleusercontent.com
   GMAIL_CLIENT_SECRET=your-client-secret
   ```

3. Deploy environment variables to Cloud Run:
   ```bash
   gcloud run services update budgetinsight-backend \
     --region us-central1 \
     --update-env-vars GMAIL_CLIENT_ID=xxx,GMAIL_CLIENT_SECRET=xxx
   ```

### 2. Configure Pub/Sub Push Subscription

```bash
# Create push subscription
gcloud pubsub subscriptions create gmail-notification-push \
  --topic=gmail-notification \
  --push-endpoint=https://budgetinsight-backend-ofgbl6d3ea-uc.a.run.app/api/gmail/pubsub/webhook \
  --ack-deadline=10 \
  --project=personal-finance-482417

# Grant Gmail permission to publish
gcloud pubsub topics add-iam-policy-binding gmail-notification \
  --member="serviceAccount:gmail-api-push@system.gserviceaccount.com" \
  --role="roles/pubsub.publisher" \
  --project=personal-finance-482417
```

### 3. Deploy Backend

```bash
cd backend
gcloud run deploy budgetinsight-backend \
  --source . \
  --region us-central1 \
  --project personal-finance-482417
```

### 4. Test the Integration

1. Open iOS app
2. Dashboard → Menu (⋯) → "Connect Gmail"
3. Authorize Gmail access
4. Make a test transaction with Discover card
5. Wait for email (~instant)
6. Dashboard → Menu → "Transaction Alerts"
7. Verify alert appears

## Future Enhancements (Not Implemented)

These were intentionally left out per your requirements:

- ❌ Resolving alerts by creating transactions
- ❌ Linking alerts to existing transactions
- ❌ Historical email scraping
- ❌ Multi-user support
- ❌ Automatic Gmail watch renewal (expires every 7 days)
- ❌ Push notifications to iOS when alert received
- ❌ Batch processing multiple cards

## Security Considerations

- OAuth tokens stored securely in Firestore
- Gmail API has read-only scope
- Pub/Sub webhook validates message format
- Single-user system (rachel.j.chen@gmail.com only)

## Monitoring

Check these for health:

1. **Cloud Run Logs** - View webhook calls and errors
2. **Pub/Sub Metrics** - Monitor message delivery
3. **Firestore Console** - Check `transaction_alerts` collection
4. **Gmail Watch Status** - Check `gmail_watch` collection for expiry

## Cost Impact

- Gmail API: Free (quota: 1B requests/day)
- Pub/Sub: ~$0.40/million messages (you'll have <100/month)
- Firestore: Minimal (small documents, low write volume)

**Estimated monthly cost: < $0.01**

---

## Quick Reference

### Test OAuth locally
```bash
# Start backend locally
cd backend
python app.py

# Visit in browser
open http://localhost:8080/api/gmail/auth/start
```

### Check if Gmail is connected
```bash
curl https://budgetinsight-backend-ofgbl6d3ea-uc.a.run.app/api/gmail/auth/status
```

### Manually trigger webhook (for testing)
```bash
curl -X POST https://budgetinsight-backend-ofgbl6d3ea-uc.a.run.app/api/gmail/pubsub/webhook \
  -H "Content-Type: application/json" \
  -d '{"message": {"data": "eyJlbWFpbEFkZHJlc3MiOiJyYWNoZWwuai5jaGVuQGdtYWlsLmNvbSIsImhpc3RvcnlJZCI6IjEyMzQ1In0="}}'
```

---

**Status: Implementation Complete ✅**  
**Next Steps: Follow setup guide in `backend/GMAIL_SETUP.md`**
