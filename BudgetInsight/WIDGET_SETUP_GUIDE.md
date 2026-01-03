# BudgetInsight Widget Setup Guide

This guide will walk you through setting up Apple Widgets for your BudgetInsight app.

## Overview

You now have two types of widgets:
1. **Small Widget**: Shows total monthly spending with percentage and color status
2. **Medium Widget**: Shows up to 4 starred budget categories with circular progress rings (mimics Apple Battery widget)

## Setup Steps

### Step 1: Create Widget Extension Target in Xcode

1. Open `BudgetInsight.xcodeproj` in Xcode
2. Click **File → New → Target**
3. Select **Widget Extension**
4. Configure the widget:
   - Product Name: `BudgetInsightWidget`
   - Include Configuration Intent: **Uncheck this** (we're using static widgets)
   - Click **Finish**
5. When prompted "Activate 'BudgetInsightWidget' scheme?", click **Activate**

### Step 2: Add Widget Files to the Widget Extension Target

You need to add all the widget files to the new target:

1. In Xcode's Project Navigator, locate these files in `BudgetInsightWidget/`:
   - `BudgetInsightWidgetBundle.swift`
   - `BudgetInsightWidget.swift`
   - `BudgetWidgetEntry.swift`
   - `WidgetDataProvider.swift`
   - `SmallBudgetWidget.swift`
   - `MediumBudgetWidget.swift`

2. **Important**: Delete any auto-generated files like `BudgetInsightWidget.swift` or `BudgetInsightWidgetBundle.swift` that Xcode created, and use the versions in the `BudgetInsightWidget/` folder instead.

3. For each file above, select it and in the **File Inspector** (right panel), check the box next to **BudgetInsightWidget** under "Target Membership"

### Step 3: Add Shared Model Files to Both Targets

The widget needs access to your data models. Add these files to BOTH the main app AND widget targets:

1. In Xcode, select each of these model files:
   - `BudgetInsight/Models/BudgetCategory.swift`
   - `BudgetInsight/Models/BudgetPlan.swift`
   - `BudgetInsight/Models/Transaction.swift`
   - `BudgetInsight/Models/TransactionAllocation.swift`
   - `BudgetInsight/Utilities/SharedUserDefaults.swift`

2. In the **File Inspector** (right panel), ensure BOTH targets are checked:
   - ✅ BudgetInsight
   - ✅ BudgetInsightWidget

### Step 4: Set Up App Groups (Critical for Data Sharing)

Both the main app and widget need to share data through an App Group.

#### For the Main App Target:

1. Select the **BudgetInsight** project in the navigator
2. Select the **BudgetInsight** target (not the widget)
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability**
5. Add **App Groups**
6. Click the **+** button under App Groups
7. Enter: `group.com.budgetinsight.shared`
8. Click **OK**

#### For the Widget Extension Target:

1. Select the **BudgetInsightWidget** target
2. Go to **Signing & Capabilities** tab
3. Click **+ Capability**
4. Add **App Groups**
5. Click the **+** button under App Groups
6. Enter: `group.com.budgetinsight.shared` (same as main app)
7. Click **OK**

⚠️ **Important**: The App Group identifier must match exactly in both targets!

### Step 5: Configure Widget Scheme (Optional but Recommended)

1. Click on the scheme dropdown (next to the Run button)
2. Select **Edit Scheme**
3. Make sure **BudgetInsightWidget** is selected
4. This allows you to run and debug the widget directly

### Step 6: Build and Run

1. Select the **BudgetInsight** scheme
2. Build and run the main app (Cmd+R)
3. The app will migrate your data to the shared container automatically
4. Add some transactions and star some budget categories

### Step 7: Add Widgets to Home Screen

1. Long-press on your home screen
2. Tap the **+** button in the top-left corner
3. Search for "BudgetInsight" or "Budget Tracker"
4. Choose widget size:
   - **Small**: Shows total spending
   - **Medium**: Shows 4 starred categories
5. Tap **Add Widget**

## How the Widgets Work

### Small Widget
- Displays total money spent across all categories this month
- Shows percentage of total budget used in top-right corner
- Color indicates spending status:
  - **Green**: On track (spending ≤ time through month)
  - **Yellow**: Slightly ahead (1-1.5× time ratio)
  - **Red**: Over budget or way ahead

### Medium Widget
- Shows up to 4 starred and active budget categories
- Each category displays as a circular progress ring with icon
- Bottom shows percentage of first category
- Categories must be BOTH starred and active to appear
- If you have fewer than 4 starred categories, empty circles appear

### Data Refresh
- Widgets automatically refresh every 15 minutes
- Widgets also refresh whenever you:
  - Add or modify transactions
  - Update budget categories
  - Change budget plan
  - Star/unstar categories

## Troubleshooting

### Widget Shows "No Data"
- Make sure you've set up your budget plan in the app
- Star some budget categories (tap the pin icon)
- Add some transactions for the current month
- Check that App Groups are configured correctly

### Widget Not Updating
- Force refresh by removing and re-adding the widget
- Make sure both targets have the same App Group ID
- Check that all model files are included in the widget target

### Build Errors
- Ensure all widget files have **BudgetInsightWidget** target membership
- Ensure model files have BOTH targets checked
- Clean build folder (Product → Clean Build Folder)
- Restart Xcode if needed

### Widget Shows Old Data
- The migration only runs once on first launch
- If data seems stale, try:
  1. Delete the app completely
  2. Reinstall and run again
  3. This will re-trigger the migration

## File Structure

```
BudgetInsight/
├── BudgetInsight/                          # Main App Target
│   ├── BudgetInsightApp.swift             # ✅ Updated with migration call
│   ├── Models/                             # ✅ Models shared with widget
│   │   ├── BudgetCategory.swift           # ✅ Add to both targets
│   │   ├── BudgetPlan.swift               # ✅ Add to both targets
│   │   ├── Transaction.swift              # ✅ Add to both targets
│   │   └── TransactionAllocation.swift    # ✅ Add to both targets
│   ├── Services/                           # ✅ Updated to use shared container
│   │   ├── BudgetService.swift            # ✅ Uses SharedUserDefaults
│   │   ├── TransactionStorageService.swift # ✅ Uses SharedUserDefaults
│   │   └── AllocationService.swift        # ✅ Uses SharedUserDefaults
│   └── Utilities/
│       └── SharedUserDefaults.swift       # ✅ Add to both targets
│
└── BudgetInsightWidget/                    # Widget Extension Target
    ├── BudgetInsightWidgetBundle.swift    # ✅ Widget entry point
    ├── BudgetInsightWidget.swift          # ✅ Main widget configuration
    ├── BudgetWidgetEntry.swift            # ✅ Timeline provider
    ├── WidgetDataProvider.swift           # ✅ Data loading logic
    ├── SmallBudgetWidget.swift            # ✅ Small widget view
    └── MediumBudgetWidget.swift           # ✅ Medium widget view
```

## Testing the Widgets

1. **Run the main app** and verify:
   - Budget plan is set up
   - At least 2-4 categories are created and starred
   - Transactions exist for current month

2. **Add the small widget**:
   - Should show total spending amount
   - Should show percentage in top-right
   - Color should reflect your spending status

3. **Add the medium widget**:
   - Should show circular progress rings for starred categories
   - Should show category icons inside circles
   - Should show percentage at bottom

4. **Test updates**:
   - Add a new transaction in the app
   - Wait ~15 seconds
   - Widget should update automatically

## Next Steps

Once everything is working:
- Star your most important budget categories to see them in widgets
- Place widgets on your home screen for quick budget tracking
- Customize which categories appear by starring/unstarring them

Enjoy your new budget tracking widgets! 🎉
