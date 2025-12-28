# Frontend-Backend Integration Summary

## What Was Implemented

Your iOS app now automatically fetches data from your Google Cloud Run backend every time it starts up or becomes active.

### Data Fetched on App Startup

1. **Transaction Data** 
   - Endpoint: `GET /api/users/{user_id}/transactions`
   - Syncs all transactions stored in Firestore
   - Merges with local transactions (no duplicates)

2. **Unresolved Transaction Alerts**
   - Endpoint: `GET /api/users/{user_id}/transaction-alerts?status=unlinked`
   - Fetches email alerts that haven't been linked to transactions
   - Shows notifications for transactions that need manual entry

3. **Historical Data (Snapshots)**
   - Endpoints: 
     - `GET /api/users/{user_id}/snapshots?type=monthly`
     - `GET /api/users/{user_id}/snapshots?type=yearly`
   - Fetches monthly and yearly spending snapshots
   - Displays in history/analytics views

4. **Budget Data**
   - Endpoint: `GET /api/users/{user_id}/budget`
   - Fetches user income and budget category allocations
   - Updates budget calculations with latest data

### User Configuration

- **Hardcoded User**: `rachel.j.chen@gmail.com`
- **Auto-Registration**: App automatically registers on first launch
- **User ID**: Stored locally after registration for subsequent requests

## Code Changes

### 1. BackendService.swift

**Added/Updated:**
- Dynamic backend URL configuration (environment variable support)
- `quickSetup()` method for automatic registration
- `fetchSnapshots()` method to get historical data
- Improved initialization with Cloud Run URL support

**Configuration:**
```swift
// Environment variable (recommended)
BACKEND_URL=https://your-service.run.app/api

// Or hardcode in BackendService.swift init()
self.baseURL = "https://your-service.run.app/api"
```

### 2. DashboardViewModel.swift

**Added:**
- `fetchBackendData()` method - orchestrates all backend data fetching
- Integrated into `refreshData()` flow
- Called automatically on app startup and when app becomes active

**Features:**
- Graceful error handling (fails silently if backend unavailable)
- Duplicate detection (won't duplicate local data)
- Background operation (doesn't block UI)
- Cancellation support (stops when app goes to background)

### 3. SnapshotService.swift

**Added:**
- `addSnapshot()` method to manually add snapshots from backend
- Smart merging (only updates if backend data is newer)
- Maintains separation between monthly and yearly snapshots

### 4. ContentView.swift

**Already Configured:**
- Calls `refreshData()` on app startup via `.task` modifier
- Calls `refreshData()` when app becomes active
- Cancels operations when app goes to background

## Data Flow on App Startup

```
App Launch
    ↓
ContentView loads
    ↓
DashboardViewModel.refreshData() called
    ↓
1. fetchBackendData()
   ├─ quickSetup() - Register user if needed
   ├─ syncTransactions() - Fetch all transactions
   ├─ fetchTransactionAlerts(status: "unlinked") - Fetch unresolved alerts
   ├─ fetchSnapshots(type: "monthly") - Fetch monthly history
   ├─ fetchSnapshots(type: "yearly") - Fetch yearly history
   └─ fetchBudget() - Fetch budget data
    ↓
2. refreshEmailAlerts() - Check Gmail for new alerts
    ↓
3. Update budgets with current transactions
    ↓
4. Update category spending
    ↓
5. Update snapshots
    ↓
UI displays merged data
```

## Testing

### Prerequisites

1. **Backend deployed** to Google Cloud Run
2. **Backend URL** configured in app
3. **Firestore** contains data for `rachel.j.chen@gmail.com`

### Test Steps

1. **Clean build** the app in Xcode
2. **Run** on simulator or device
3. **Watch console** for log messages:

Expected logs:
```
☁️ [DashboardViewModel] Fetching data from backend...
✅ Already registered with user_id: rachel.j.chen@gmail.com
📥 [DashboardViewModel] Fetching transactions from backend...
✅ [DashboardViewModel] Fetched N transactions from backend
📥 [DashboardViewModel] Fetching unresolved alerts from backend...
✅ [DashboardViewModel] Fetched N unresolved alerts from backend
📥 [DashboardViewModel] Fetching historical data from backend...
✅ [DashboardViewModel] Fetched N monthly and N yearly snapshots from backend
📥 [DashboardViewModel] Fetching budget from backend...
✅ [DashboardViewModel] Fetched budget from backend
☁️ [DashboardViewModel] Backend data fetch complete
```

### Verify Data Synced

1. **Transactions View** - Should show transactions from Firestore
2. **Dashboard** - Should show unresolved alerts count
3. **History View** - Should show historical snapshots
4. **Budget View** - Should show budget from backend

## Configuration Guide

See [BACKEND_SETUP.md](BACKEND_SETUP.md) for detailed setup instructions.

**Quick Setup:**
1. Get your Cloud Run URL: `gcloud run services describe budgetinsight-backend --region=us-central1 --format='value(status.url)'`
2. Add to Xcode environment: `Product` → `Scheme` → `Edit Scheme...` → `Run` → `Arguments` → Environment Variables
3. Add: `BACKEND_URL` = `https://your-url.run.app/api`
4. Build and run

## Error Handling

The app handles backend failures gracefully:

- **Backend unavailable**: Logs warning, uses local data only
- **Network error**: Logs error, continues with local data
- **User not registered**: Automatically registers on next attempt
- **Invalid response**: Logs error, skips that data source

The app will **never crash** due to backend issues.

## Future Enhancements

- [ ] Sync local data to backend (currently one-way: backend → app)
- [ ] Real-time sync with Firestore listeners
- [ ] Conflict resolution for data that exists both locally and on backend
- [ ] Background sync (fetch data periodically without opening app)
- [ ] Sync status indicator in UI

## Troubleshooting

**No data appearing?**
- Check backend URL is correct
- Verify backend is deployed and healthy: `curl https://your-url.run.app/health`
- Check Xcode console for error messages
- Verify Firestore has data for `rachel.j.chen@gmail.com`

**"Not registered" errors?**
- App will auto-register on first launch
- Check backend logs: `gcloud run services logs tail budgetinsight-backend`
- Verify `/api/users/register` endpoint is working

**Duplicate transactions?**
- Check duplicate detection logic in `fetchBackendData()`
- May need to adjust matching criteria (merchant, amount, date)

---

**Status**: ✅ Complete  
**Last Updated**: 2024-12-27  
**Tested**: Pending user testing
