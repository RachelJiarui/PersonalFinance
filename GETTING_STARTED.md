# Getting Started with Budget Insight (SimpleFin Edition)

## 🎯 What This App Does

Budget Insight is your personal finance assistant that:
- Connects to your bank accounts **once** via SimpleFin
- Automatically downloads and categorizes all your transactions
- Shows you exactly where your money is going
- Tells you what you can afford to spend right now
- Warns you when you're approaching budget limits
- Never requires you to log in again after initial setup
- **Costs only $1.50/month** (SimpleFin fee, not app fee)

## 📱 Quick Start (3 Minutes)

### Step 1: You Already Have a Setup Token! (0 min)

Your SimpleFin setup token:
```
aHR0cHM6Ly9iZXRhLWJyaWRnZS5zaW1wbGVmaW4ub3JnL3NpbXBsZWZpbi9jbGFpbS8yQzUxMTcyQTA4MDczM0ExM0Q0RTBBRjRGQTkxNTFENjc2QkY3QUNGOTIzNzdCQjlEQTA5MDM3RThCRDFDNTg4OUJBMzEzOTdBRDQyQ0FGMjNCNzRDQkM3MDc5OUI5Qzk2RTRCQ0Q4QkE5QTYyMzI0NEFCNUZCMjE2RDlGQTE0Mg==
```

Copy this - you'll need it in Step 3.

### Step 2: Open in Xcode (30 sec)

1. Open **BudgetInsight.xcodeproj** in Xcode
2. Select **iPhone 15 Pro** simulator (or any device)
3. Press **⌘R** or click the Play button ▶️

No configuration needed - SimpleFin uses simple token auth!

### Step 3: Connect Your Banks (1 min)

1. App launches and shows "Connect SimpleFin" screen
2. Tap **Connect SimpleFin**
3. Paste your setup token (from above)
4. Tap **Connect**
5. Wait 5-10 seconds for sync

The app will:
- Claim your token and get an access URL
- Fetch all accounts from SimpleFin
- Download recent transactions
- Categorize everything automatically
- Calculate your budgets

### Step 4: Explore Your Dashboard (30 sec)

You'll see:
- 💰 Monthly cash flow ($X saved this month)
- 📊 Budget categories with progress bars
- 💡 Smart insights and warnings
- 🎯 Remaining budget for each category

## 🎨 What You'll See

### Main Dashboard

```
┌────────────────────────────────┐
│  Monthly Overview              │
│  $1,500 net savings            │
│  Income: $5,000                │
│  Expenses: $3,500              │
│  Saving 30% of income          │
└────────────────────────────────┘

┌────────────────────────────────┐
│  💡 Insights                    │
│  • Great Saving! 30% rate      │
│  • Food is top expense         │
│  • Shopping at 85% of limit    │
└────────────────────────────────┘

┌────────────────────────────────┐
│  🍴 Food & Dining    75% 🟢     │
│  $450 / $600                   │
│  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░         │
│  $150 remaining                │
└────────────────────────────────┘
```

## 🔄 Daily Usage

### Every Morning
1. Open the app
2. Check **Monthly Overview** at the top
3. See your **net cash flow**
4. Review any **warnings** in insights

### Before Spending
1. Scroll to the category (e.g., Food & Dining)
2. Check **"$ remaining"**
3. Decide if you can afford it

### Weekly Review
1. Pull down to refresh transactions
2. Check **month-over-month** percentage
3. Review **top spending category** insight
4. Adjust spending if needed

## 📊 Understanding Your Budget

### Default Budget Categories

| Category | Monthly Limit | What It Includes |
|----------|--------------|------------------|
| 🍴 Food & Dining | $600 | Restaurants, groceries, coffee |
| 🛍️ Shopping | $400 | Amazon, Target, retail stores |
| 🚗 Transportation | $300 | Gas, Uber, parking, transit |
| 🎬 Entertainment | $200 | Netflix, movies, concerts |
| 🏠 Utilities | $250 | Electric, water, internet, phone |

### Color Coding

- 🟢 **Green (0-79%)**: Healthy - spend freely
- 🟠 **Orange (80-99%)**: Warning - slow down
- 🔴 **Red (100%+)**: Exceeded - stop spending

## 🔐 Security & Privacy

### What's Stored
- ✅ SimpleFin access URL (encrypted in Keychain)
- ✅ Budget limits (in UserDefaults)
- ✅ Transaction cache (in memory)

### What's NOT Stored
- ❌ Your bank username/password
- ❌ SimpleFin credentials
- ❌ Any data on external servers

### How SimpleFin Works
1. You connect banks through SimpleFin Bridge
2. SimpleFin aggregates your data
3. Your app fetches from SimpleFin (not banks directly)
4. All data stays on your device
5. SimpleFin NEVER sells your data

## 💰 Cost Breakdown

### SimpleFin Subscription
- **$1.50/month** (billed by SimpleFin)
- **$15/year** (save $3 annually)
- No per-transaction fees
- No usage limits (24 API calls/day)
- Cancel anytime

### This App
- **100% FREE**
- No in-app purchases
- No ads
- Open source

### vs Plaid
- Plaid: $50-500/month minimum
- SimpleFin: $1.50/month
- **You save $48.50+/month!**

## 🚀 Advanced Features

### Customizing Budgets

Edit `BudgetService.swift` line 87:

```swift
func createDefaultBudgets() {
    budgets = [
        Budget(category: .food, monthlyLimit: 800, yearlyLimit: 9600, ...),
        // Change amounts here
    ]
}
```

### Rate Limits

SimpleFin allows **24 requests per day**:
- Opening app: 1 request
- Manual refresh: 1 request
- Automatic background refresh: 0 requests (pull to refresh only)

**Tip**: You can open the app as many times as you want, but only refresh 24 times/day.

### Supported Banks

SimpleFin supports 11,000+ institutions including:
- ✅ Discover Bank
- ✅ DCU (Digital Federal Credit Union)
- ✅ Chase, Bank of America, Wells Fargo
- ✅ Most credit unions
- ✅ Investment accounts (some)

## 🐛 Troubleshooting

### "Invalid Setup Token"
- Token can only be claimed once
- Generate new token at beta-bridge.simplefin.org
- Make sure you copied the entire token

### Transactions not syncing
- Pull down to refresh
- Check internet connection
- Verify SimpleFin Bridge has transactions
- Ensure you haven't exceeded 24 requests/day

### Some banks missing
- Check SimpleFin Bridge dashboard
- Reconnect banks in SimpleFin if needed
- Some banks may need re-authentication

### App won't build
- Clean build: **⌘⇧K**
- Restart Xcode
- Ensure Xcode 15.0+ and iOS 16.0+

## 📚 How SimpleFin Works

### The Setup Token Flow

1. **Generate token** at SimpleFin Bridge
2. Token is **base64-encoded claim URL**
3. App decodes and **POSTs to claim URL**
4. SimpleFin returns **access URL** with credentials
5. App saves access URL in **Keychain**
6. Access URL used for all future requests

### The Access URL Format

```
https://username:password@beta-bridge.simplefin.org/simplefin/accounts
```

- Includes Basic Auth credentials
- Saved encrypted in Keychain
- Never expires (until you disconnect)

### Fetching Transactions

```
GET {access_url}/accounts
Authorization: Basic {credentials}
```

Returns:
- All connected accounts
- Recent transactions (past 90 days)
- Account balances
- Pending transactions

## 🎓 Next Steps

1. **Use it daily**:
   - Check budgets before spending
   - Review insights regularly
   - Pull to refresh for new transactions

2. **Customize it**:
   - Adjust budget limits
   - Add new categories
   - Modify insight rules

3. **Track progress**:
   - Watch savings rate improve
   - See month-over-month trends
   - Hit your financial goals

## ✅ You're All Set!

Your finance tracker is ready to use with SimpleFin:
- ✅ Cheaper than Plaid ($1.50 vs $50+/month)
- ✅ Privacy-focused (data never sold)
- ✅ Simple setup (just paste token)
- ✅ Works with Discover and DCU
- ✅ Automatic transaction syncing
- ✅ Smart budget tracking

Open the app daily and watch your finances improve! 🎉

## 🔗 Resources

- **SimpleFin Bridge**: https://beta-bridge.simplefin.org/
- **SimpleFin Protocol**: https://www.simplefin.org/protocol.html
- **Developer Docs**: https://beta-bridge.simplefin.org/info/developers
