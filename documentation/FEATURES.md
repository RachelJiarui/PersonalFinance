# Budget Insight - Feature Overview

## What You'll See on Your Dashboard

### 1. Monthly Overview Card
**At the top of your dashboard**, you'll see a large card showing:
- **Net Cash Flow**: Your income minus expenses for the current month in large numbers
  - Green if positive (you're saving money)
  - Red if negative (spending more than earning)
- **Income**: Total money coming in (with green arrow)
- **Expenses**: Total money going out (with red arrow)
- **Savings Rate**: What percentage of your income you're keeping
- **Month-over-Month**: How your spending compares to last month

**Example**: If you earned $5,000 and spent $3,500, you'd see:
- Net: $1,500 (in green)
- Savings Rate: 30%
- vs Last Month: +5% (if you spent more than last month)

### 2. Smart Insights Section
**Below the overview**, you'll get 3 personalized insights such as:

- **⚠️ Budget Exceeded** (Red warning)
  - "You've exceeded your Food & Dining budget by $150"
  
- **💡 Approaching Limit** (Blue recommendation)
  - "You've used 85% of your Shopping budget"
  
- **✅ Great Saving!** (Green achievement)
  - "You're saving 25% of your income this month"
  
- **💡 Top Spending Category** (Blue info)
  - "Food & Dining is your highest expense at $650"

### 3. Budget Categories
**The main section** shows each spending category with:

#### For Each Category (e.g., Food & Dining):
- **Icon and Name**: Visual identifier
- **Current Spending**: "$450 of $600"
- **Percentage**: "75%" with color coding:
  - Green: Under 80% (healthy)
  - Orange: 80-99% (warning)
  - Red: 100%+ (exceeded)
- **Progress Bar**: Visual representation
- **Monthly Status**: Current month spending
- **Yearly Status**: Year-to-date spending
- **Remaining Budget**: "$150 left" or "$50 over"

### 4. Interactive Features

#### Pull to Refresh
- Swipe down anywhere on the dashboard
- Syncs latest transactions from your bank
- Updates all budgets and insights

#### Menu Options (⋯ button)
- **Refresh**: Manually sync transactions
- **Disconnect**: Remove bank connection and reset app

## What the App Tells You

### Things You Can Spend Money On
The app shows you **remaining budgets** for each category:
- ✅ "Transportation: $200 left" → You can spend $200 on gas/uber
- ✅ "Entertainment: $75 left" → You can spend $75 on movies/games
- ⚠️ "Food & Dining: $50 left" → Only $50 left for restaurants
- ❌ "Shopping: $100 over" → You should avoid shopping this month

### Where You Are in Your Budget

#### Monthly View (Current Month)
- Progress bar shows how much of the month's budget you've used
- Color-coded status (green/orange/red)
- Days remaining in month (implicitly shown via percentage)

#### Yearly View (Year-to-Date)
- Shows spending across the entire year
- Helps you plan for annual expenses
- Tracks long-term spending patterns

### What You Need to Cut Back On
The insights section tells you:
1. **Exceeded budgets** → Cut back immediately
2. **Categories approaching limits** → Slow down spending
3. **Top spending categories** → Areas to focus on reducing
4. **Month-over-month increases** → Growing expenses to watch

## Example Dashboard Scenario

### You open the app and see:

```
┌─────────────────────────────────┐
│   Monthly Overview              │
│   $1,200  (in green)            │
│   ↓ $4,500    ↑ $3,300          │
│   Savings Rate: 27%             │
│   vs Last Month: +8%            │
└─────────────────────────────────┘

┌─────────────────────────────────┐
│ ⚠️  Budget Exceeded              │
│ You've exceeded your Food &     │
│ Dining budget by $120           │
└─────────────────────────────────┘

┌─────────────────────────────────┐
│ 💡 Approaching Limit             │
│ You've used 88% of your         │
│ Shopping budget                 │
└─────────────────────────────────┘

┌─────────────────────────────────┐
│ 🍴 Food & Dining      106% 🔴    │
│ $720 of $600                    │
│ ████████████████████░           │
│ Monthly: $720 / $600            │
│ Yearly: $4,320 / $7,200         │
│ $120 over                       │
└─────────────────────────────────┘

┌─────────────────────────────────┐
│ 🛍️  Shopping          88% 🟠     │
│ $352 of $400                    │
│ ████████████████░░░░            │
│ Monthly: $352 / $400            │
│ Yearly: $2,816 / $4,800         │
│ $48 left                        │
└─────────────────────────────────┘

┌─────────────────────────────────┐
│ 🚗 Transportation     45% 🟢     │
│ $135 of $300                    │
│ ████████░░░░░░░░░░░░            │
│ Monthly: $135 / $300            │
│ Yearly: $810 / $3,600           │
│ $165 left                       │
└─────────────────────────────────┘
```

### What This Tells You:
- ✅ You saved $1,200 this month
- ❌ Stop eating out - you're $120 over budget
- ⚠️ Be careful with shopping - only $48 left
- ✅ Transportation is fine - plenty of room

## Automatic Transaction Categorization

The app automatically sorts your transactions:
- **Starbucks, McDonald's, Restaurant** → Food & Dining
- **Amazon, Target, Mall** → Shopping
- **Uber, Gas Station, Transit** → Transportation
- **Netflix, Movies, Concerts** → Entertainment
- **Electric, Water, Internet** → Utilities
- **Doctor, Pharmacy** → Healthcare
- **Hotels, Airbnb, Flights** → Travel

## Privacy & Security

- ✅ Bank credentials **never stored** in the app
- ✅ Plaid handles all bank authentication
- ✅ Access tokens encrypted in iOS Keychain
- ✅ All data stays on your device
- ✅ No cloud storage or third-party access
- ✅ Automatic security on device unlock

## One-Time Setup

1. Download and open app
2. Tap "Connect Your Bank"
3. Enter bank credentials (one time only)
4. Grant permission
5. **Never log in again** - stay connected forever

The app automatically syncs in the background!
