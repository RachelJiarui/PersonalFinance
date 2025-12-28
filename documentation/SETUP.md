# Quick Setup Guide - SimpleFin Edition

## Step 1: Get SimpleFin Setup Token (2 min)

### Option A: Use Your Provided Token (Fastest!)

You already have a setup token! Use this one:

```
aHR0cHM6Ly9iZXRhLWJyaWRnZS5zaW1wbGVmaW4ub3JnL3NpbXBsZWZpbi9jbGFpbS8yQzUxMTcyQTA4MDczM0ExM0Q0RTBBRjRGQTkxNTFENjc2QkY3QUNGOTIzNzdCQjlEQTA5MDM3RThCRDFDNTg4OUJBMzEzOTdBRDQyQ0FGMjNCNzRDQkM3MDc5OUI5Qzk2RTRCQ0Q4QkE5QTYyMzI0NEFCNUZCMjE2RDlGQTE0Mg==
```

**Important**: This token can only be claimed once. After you use it, it converts to an access URL saved in your Keychain.

### Option B: Generate a New Token

1. Go to **https://beta-bridge.simplefin.org/**
2. Sign up or log in
3. Connect your bank accounts (Discover, DCU, etc.)
4. Click "Create Setup Token"
5. Copy the base64-encoded token

**Cost**: $1.50/month or $15/year (much cheaper than Plaid!)

## Step 2: Open in Xcode (30 sec)

1. Open **BudgetInsight.xcodeproj** in Xcode
2. Select a simulator (iPhone 15 Pro) or your device
3. That's it - no environment variables needed!

## Step 3: Build and Run (30 sec)

1. Press **⌘R** or click the ▶️ Play button
2. Wait for the app to build and launch

## Step 4: Connect SimpleFin (1 min)
1. Tap **Connect SimpleFin**
2. Paste your setup token (the one above or your new one)
3. Tap **Connect**
4. Wait 5-10 seconds for sync

The app will:
- Claim your setup token
- Convert it to an access URL
- Save the URL securely in Keychain
- Fetch all your accounts and transactions
- Categorize transactions automatically
- Calculate your budgets

## Step 5: Explore Your Dashboard (30 sec)

You'll now see:
- 💰 Monthly cash flow summary
- 📊 Budget categories with progress bars
- 💡 Smart spending insights
- 🎯 What you can still spend

## You're Done!

### Daily Usage

1. Open the app
2. Pull down to refresh transactions
3. Check your budgets and insights

### Rate Limits

SimpleFin allows 24 API requests per day, which is more than enough for:
- Opening the app multiple times
- Manual refreshes
- Checking budgets throughout the day

### Your Accounts

If you connected Discover and DCU through SimpleFin, you'll see:
- All transactions from both banks
- Combined budget tracking
- Unified dashboard

## Tips

- **Refresh**: Pull down on the dashboard to sync new transactions
- **Menu**: Tap the `...` button for options
- **Disconnect**: Use the menu to disconnect and start over

## Troubleshooting

### "Invalid Setup Token"
- Make sure you copied the entire token (it's a long base64 string)
- Tokens can only be used once - generate a new one if needed

### "Failed to claim token"
- Check your internet connection
- Verify the token hasn't been used already
- Try generating a fresh token from SimpleFin

### No transactions showing
- Pull down to refresh
- Check that you connected banks in SimpleFin Bridge
- Verify SimpleFin Bridge shows transactions at beta-bridge.simplefin.org

### App crashes on launch
- Clean build (⌘⇧K)
- Rebuild and run

## Next Steps

- Customize budget limits in the code
- Check insights daily
- Track your spending trends
- Enjoy automatic transaction syncing!

## Why This Is Better Than Plaid

- ✅ **No environment variables** needed
- ✅ **No API credentials** to manage  
- ✅ **$1.50/month** vs $50+/month
- ✅ **Simple setup** - just paste a token
- ✅ **Privacy-focused** - your data isn't sold
- ✅ **Works with Discover and DCU** (and 11,000+ other institutions)

Enjoy your automatic budget tracker! 🎉
