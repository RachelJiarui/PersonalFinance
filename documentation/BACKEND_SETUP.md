# Backend Setup Guide

This guide will help you connect your iOS frontend app to the Google Cloud Run backend.

## Overview

The app now fetches data from your backend on startup:
- **Transaction data** - All transactions stored in Firestore
- **Transaction alerts** - Unresolved email alerts from Discover Bank
- **Historical data** - Monthly and yearly snapshots
- **Budget data** - User income and category allocations

## Configuration Steps

### 1. Update the Backend URL

The backend URL is currently set to `http://localhost:8080/api` for development. To connect to your Cloud Run backend:

**Option A: Environment Variable (Recommended)**
1. In Xcode, go to `Product` → `Scheme` → `Edit Scheme...`
2. Select `Run` in the left sidebar
3. Go to the `Arguments` tab
4. Under `Environment Variables`, add:
   - **Name**: `BACKEND_URL`
   - **Value**: `https://your-cloud-run-url.run.app/api`

Replace `your-cloud-run-url` with your actual Cloud Run service URL.

**Option B: Hardcode the URL**
1. Open `BudgetInsight/Services/BackendService.swift`
2. Find the `init()` method (around line 12)
3. Change the default URL:
   ```swift
   } else {
       // Default to your Cloud Run URL
       self.baseURL = "https://your-cloud-run-url.run.app/api"
   }
   ```

### 2. Get Your Cloud Run URL

If you don't know your Cloud Run URL:

```bash
cd backend
gcloud run services describe budgetinsight-backend --region=us-central1 --format='value(status.url)'
```

This will output something like:
```
https://budgetinsight-backend-abc123-uc.a.run.app
```

### 3. User Registration

The app is configured to automatically register the user `rachel.j.chen@gmail.com` on first launch.

When the app starts:
1. It calls `BackendService.quickSetup()` 
2. This registers the user with the backend if not already registered
3. The user ID is stored locally for future requests

### 4. What Happens on App Startup

Every time the app starts or becomes active, it:

1. **Registers with backend** (if not already registered)
   ```
   POST /api/users/register
   ```

2. **Fetches transactions**
   ```
   GET /api/users/{user_id}/transactions
   ```

3. **Fetches unresolved alerts**
   ```
   GET /api/users/{user_id}/transaction-alerts?status=unlinked
   ```

4. **Fetches historical snapshots**
   ```
   GET /api/users/{user_id}/snapshots?type=monthly
   GET /api/users/{user_id}/snapshots?type=yearly
   ```

5. **Fetches budget data**
   ```
   GET /api/users/{user_id}/budget
   ```

All fetched data is merged with local data (no duplicates).

## Testing the Connection

### 1. Check Backend Health

First, verify your backend is running:

```bash
curl https://your-cloud-run-url.run.app/health
```

You should see:
```json
{
  "status": "healthy",
  "timestamp": "2024-01-15T12:00:00.000000",
  "services": {
    "firestore": true,
    "pubsub": true
  }
}
```

### 2. Test in Xcode

1. Build and run the app in Xcode
2. Watch the console output
3. Look for these log messages:

```
☁️ [DashboardViewModel] Fetching data from backend...
✅ Already registered with user_id: rachel.j.chen@gmail.com
📥 [DashboardViewModel] Fetching transactions from backend...
✅ [DashboardViewModel] Fetched 0 transactions from backend
📥 [DashboardViewModel] Fetching unresolved alerts from backend...
✅ [DashboardViewModel] Fetched 0 unresolved alerts from backend
📥 [DashboardViewModel] Fetching historical data from backend...
✅ [DashboardViewModel] Fetched 0 monthly and 0 yearly snapshots from backend
📥 [DashboardViewModel] Fetching budget from backend...
ℹ️ [DashboardViewModel] No budget found on backend
☁️ [DashboardViewModel] Backend data fetch complete
```

### 3. Common Issues

**Issue**: `Failed to fetch from backend: The Internet connection appears to be offline`
- **Solution**: Check that the backend URL is correct and the service is deployed

**Issue**: `Not registered with backend - skipping backend sync`
- **Solution**: This is normal on first launch before registration completes

**Issue**: `Invalid response from backend server`
- **Solution**: Check backend logs for errors:
  ```bash
  gcloud run services logs tail budgetinsight-backend --region=us-central1
  ```

**Issue**: `URLSession errors with localhost`
- **Solution**: If testing with localhost, you need to:
  1. Run the backend locally: `cd backend && python app.py`
  2. Make sure iOS simulator can access localhost

## Data Flow

```
┌─────────────┐
│   iOS App   │
│   (Startup) │
└──────┬──────┘
       │
       │ 1. Register/Connect
       ▼
┌─────────────────┐
│  Cloud Run API  │
│  (Flask Server) │
└────────┬────────┘
         │
         │ 2. Query Data
         ▼
┌─────────────────┐
│   Firestore     │
│   (Database)    │
└─────────────────┘
         │
         │ 3. Return Data
         ▼
┌─────────────────┐
│   iOS App       │
│ (Display Data)  │
└─────────────────┘
```

## Network Security

For production deployment:

1. **Enable App Transport Security (ATS)**
   - Xcode requires HTTPS by default
   - Your Cloud Run URL uses HTTPS ✓

2. **API Authentication** (Future Enhancement)
   - Currently the app uses user_id for all requests
   - Consider adding API keys or OAuth tokens for production

3. **Firestore Security Rules**
   - Already configured to only allow access for rachel.j.chen@gmail.com
   - Service account has full access for backend operations

## Troubleshooting Commands

**View backend logs:**
```bash
gcloud run services logs tail budgetinsight-backend --region=us-central1 --limit=50
```

**Check Firestore data:**
```bash
# List all users
gcloud firestore documents list users

# Get specific user
gcloud firestore documents get users/rachel.j.chen@gmail.com
```

**Test backend endpoint directly:**
```bash
# Health check
curl https://your-cloud-run-url.run.app/health

# Get transactions (requires user to be registered first)
curl https://your-cloud-run-url.run.app/api/users/rachel.j.chen@gmail.com/transactions
```

## Next Steps

Once connected:

1. **Test data sync** - Add a transaction on backend, verify it appears in app
2. **Test alerts** - Send a test Discover email, verify it appears in app
3. **Monitor logs** - Watch both Xcode console and Cloud Run logs
4. **Set up push notifications** - Configure APNs for real-time alerts

## Support

If you encounter issues:

1. Check the Xcode console for detailed error messages
2. Check Cloud Run logs for backend errors
3. Verify Firestore security rules allow access
4. Ensure the backend is deployed and running

---

**Status**: ✅ Backend integration complete  
**User**: rachel.j.chen@gmail.com  
**Auto-sync**: Enabled on app startup
