# Budget Insight

A minimalistic iOS finance tracking app that automatically syncs with your bank accounts through SimpleFin to help you understand your spending habits and manage your budget.

## Features

- **Automatic Transaction Sync**: Connect once via SimpleFin and never manually enter expenses again
- **At-a-Glance Dashboard**: See your financial status instantly on the home screen
- **Smart Budget Tracking**: Monitor monthly and yearly budgets by category
- **Intelligent Insights**: Get personalized recommendations on spending patterns
- **Minimalistic Design**: Clean, Apple-inspired interface
- **Secure Storage**: Bank credentials safely stored using iOS Keychain
- **No Login Required**: Connect once and stay authenticated
- **Privacy First**: All data stays on your device

## What You Can See

### Dashboard Overview
- **Monthly Cash Flow**: Net income vs expenses
- **Savings Rate**: Percentage of income saved
- **Month-over-Month Comparison**: Track spending trends

### Budget Categories
- Food & Dining
- Shopping
- Transportation
- Entertainment
- Utilities
- Healthcare
- Travel
- Personal

Each category shows:
- Current spending vs budget limit
- Visual progress bar
- Monthly and yearly tracking
- Remaining budget

### Smart Insights
- Budget warnings when approaching limits
- Spending recommendations
- Achievement notifications
- Top spending category highlights

## Technical Stack

- **Language**: Swift 5.9
- **UI Framework**: SwiftUI
- **Minimum iOS**: 16.0
- **Architecture**: MVVM
- **Bank Integration**: SimpleFin Bridge API
- **Security**: iOS Keychain for token storage
- **Data Persistence**: UserDefaults & Codable

## Setup Instructions

### Prerequisites

1. **Xcode 15.0+** installed on your Mac
2. **iOS 16.0+** device or simulator
3. **SimpleFin Account** (for bank connections)

### SimpleFin Configuration

1. Sign up for SimpleFin at [beta-bridge.simplefin.org](https://beta-bridge.simplefin.org/)
2. Connect your bank accounts through SimpleFin Bridge
3. Generate a **Setup Token** from the SimpleFin dashboard
4. Copy the base64-encoded setup token

**Important**: SimpleFin is much cheaper than alternatives:
- **Cost**: $1.50/month (or $15/year)
- **No per-transaction fees**
- **No usage limits**
- **Privacy-focused**: No data selling

### Installation

1. Clone or download this repository
2. Open `BudgetInsight.xcodeproj` in Xcode
3. Select your target device/simulator
4. Build and run (⌘R)

### First Run

1. Launch the app
2. Tap "Connect SimpleFin"
3. Paste your setup token from SimpleFin
4. Tap "Connect"
5. Wait for initial sync to complete

### Your Setup Token

You provided this setup token (already saved for reference):
```
aHR0cHM6Ly9iZXRhLWJyaWRnZS5zaW1wbGVmaW4ub3JnL3NpbXBsZWZpbi9jbGFpbS8yQzUxMTcyQTA4MDczM0ExM0Q0RTBBRjRGQTkxNTFENjc2QkY3QUNGOTIzNzdCQjlEQTA5MDM3RThCRDFDNTg4OUJBMzEzOTdBRDQyQ0FGMjNCNzRDQkM3MDc5OUI5Qzk2RTRCQ0Q4QkE5QTYyMzI0NEFCNUZCMjE2RDlGQTE0Mg==
```

**Note**: This token can only be claimed once. After you use it in the app, it converts to an access URL that's saved securely in your Keychain.

## Project Structure

```
BudgetInsight/
├── BudgetInsight/
│   ├── Models/
│   │   ├── Transaction.swift          # Transaction data model
│   │   ├── Budget.swift                # Budget tracking model
│   │   └── SpendingInsights.swift     # Insights engine
│   ├── Views/
│   │   ├── ContentView.swift           # Main entry view
│   │   ├── DashboardView.swift         # Main dashboard
│   │   └── CategoryCard.swift          # Budget category card
│   ├── ViewModels/
│   │   └── DashboardViewModel.swift    # Dashboard logic
│   ├── Services/
│   │   ├── SimpleFinService.swift      # SimpleFin API integration
│   │   ├── KeychainService.swift       # Secure storage
│   │   └── BudgetService.swift         # Budget calculations
│   └── BudgetInsightApp.swift          # App entry point
└── Package.swift                        # Dependencies (none needed!)
```

## Security Features

### Keychain Integration
All sensitive data is stored securely:
- SimpleFin access URL encrypted in iOS Keychain
- URLs only accessible when device is unlocked
- Automatic cleanup on app deletion

### Data Privacy
- No user data stored on external servers
- All calculations performed on-device
- Bank credentials never stored in the app
- SimpleFin handles authentication securely
- Your data is NEVER sold or shared

## SimpleFin vs Plaid

Why SimpleFin is better for personal finance apps:

| Feature | SimpleFin | Plaid |
|---------|-----------|-------|
| **Cost** | $1.50/month | $5-50+/month |
| **Pricing Model** | Flat rate | Per-connection |
| **Privacy** | Privacy-focused | Data aggregation |
| **Setup** | Simple token | Complex OAuth |
| **Rate Limits** | 24/day | Varies |
| **Best For** | Personal use | Businesses |

## Customizing Budgets

Default budgets are created on first launch:
- Food & Dining: $600/month
- Shopping: $400/month
- Transportation: $300/month
- Entertainment: $200/month
- Utilities: $250/month

To customize budgets, modify the `createDefaultBudgets()` method in `BudgetService.swift`:

```swift
func createDefaultBudgets() {
    budgets = [
        Budget(id: UUID(), category: .food, monthlyLimit: 800, yearlyLimit: 9600, ...),
        // Customize amounts here
    ]
}
```

## API Usage

### SimpleFin Integration

The app uses SimpleFin Bridge API endpoints:

1. **POST /claim/{token}**
   - Converts setup token to access URL
   - Called once during initial connection

2. **GET /accounts**
   - Retrieves accounts and transactions
   - Called on app launch and manual refresh
   - Automatically categorizes transactions
   - Limited to 24 requests per day

### SimpleFin Response Format

SimpleFin returns account data with transactions:
```json
{
  "accounts": [
    {
      "id": "account_id",
      "name": "Checking Account",
      "balance": 125000,
      "transactions": [
        {
          "id": "txn_id",
          "posted": 1704067200,
          "amount": -4500,
          "description": "STARBUCKS",
          "pending": false
        }
      ]
    }
  ]
}
```

Note: Amounts are in 1/10,000ths of the currency unit (e.g., 4500 = $0.45).

## Known Limitations

- **Rate Limit**: 24 API requests per day (SimpleFin restriction)
- **Manual Refresh**: Pull to refresh for latest transactions
- **Single SimpleFin Account**: One setup token per app instance

## Troubleshooting

### App Won't Connect to SimpleFin
- Verify setup token is correct and hasn't been used
- Check internet connection
- Ensure SimpleFin account is active

### Transactions Not Syncing
- Pull down to refresh manually
- Check you haven't exceeded 24 requests/day
- Verify SimpleFin Bridge is working at beta-bridge.simplefin.org

### Budget Not Updating
- Ensure transactions are synced
- Check transaction categories match budget categories
- Verify date range includes current month

### "Invalid Setup Token" Error
- Setup tokens can only be claimed once
- Generate a new token from SimpleFin dashboard
- Ensure token is copied completely (base64 string)

### Build Errors
- Clean build folder (⌘⇧K)
- Ensure Xcode 15.0+ is installed
- Check iOS deployment target is 16.0+

## Future Enhancements

Potential features for future versions:
- Multiple SimpleFin account support
- Custom budget categories
- Spending goals and milestones
- Export data to CSV
- Recurring transaction detection
- Bill reminders
- Investment account tracking
- Receipt scanning
- Budget sharing (family accounts)

## SimpleFin Resources

- **Sign Up**: https://beta-bridge.simplefin.org/
- **Documentation**: https://www.simplefin.org/protocol.html
- **Developer Guide**: https://beta-bridge.simplefin.org/info/developers
- **Cost**: $1.50/month or $15/year

## Production Deployment

Before deploying to App Store:

1. **Complete Testing**:
   - Test with real bank accounts via SimpleFin
   - Verify all edge cases
   - Test on multiple iOS versions

2. **App Store Requirements**:
   - Add Privacy Policy URL
   - Complete App Store description
   - Include screenshots of dashboard
   - Mention SimpleFin integration in description

3. **Code Signing**:
   - Configure proper provisioning profiles
   - Enable necessary capabilities in Xcode

4. **Privacy**:
   - Update Info.plist with privacy descriptions
   - Explain data usage in App Store listing

## License

This project is provided as-is for personal use.

## Support

For SimpleFin-specific issues, refer to [SimpleFin Documentation](https://www.simplefin.org/protocol.html).

For app-related questions, check the code comments and inline documentation.

## Acknowledgments

- **SimpleFin** for providing affordable, privacy-focused banking infrastructure
- **Apple** for SwiftUI framework
- **Swift Community** for excellent tooling and resources

## Why SimpleFin?

SimpleFin is perfect for personal finance apps because:
- ✅ **Affordable**: $1.50/month vs $50+/month with Plaid
- ✅ **Privacy-focused**: Your data is never sold
- ✅ **Simple**: Just paste a token, no complex OAuth
- ✅ **Reliable**: Direct bank connections via their aggregation
- ✅ **No surprises**: Flat rate pricing, no per-use fees
