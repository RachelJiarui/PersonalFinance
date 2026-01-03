# Widget Files Checklist

Use this checklist when setting up the widget extension in Xcode.

## Files to Add to Widget Target ONLY

Located in `BudgetInsightWidget/`:

- [ ] `BudgetInsightWidgetBundle.swift`
- [ ] `BudgetInsightWidget.swift`  
- [ ] `BudgetWidgetEntry.swift`
- [ ] `WidgetDataProvider.swift`
- [ ] `SmallBudgetWidget.swift`
- [ ] `MediumBudgetWidget.swift`
- [ ] `Info.plist`

## Files to Add to BOTH Targets

These must be in both the main app AND widget targets:

### Models (Required)
- [ ] `BudgetInsight/Models/BudgetCategory.swift`
- [ ] `BudgetInsight/Models/BudgetPlan.swift`
- [ ] `BudgetInsight/Models/Transaction.swift`
- [ ] `BudgetInsight/Models/TransactionAllocation.swift`

### Utilities (Required)
- [ ] `BudgetInsight/Utilities/SharedUserDefaults.swift`

## Files Already Modified (No Action Needed)

These were automatically updated to use shared storage:

- ✅ `BudgetInsight/BudgetInsightApp.swift`
- ✅ `BudgetInsight/Services/BudgetService.swift`
- ✅ `BudgetInsight/Services/TransactionStorageService.swift`
- ✅ `BudgetInsight/Services/AllocationService.swift`

## Capabilities to Add in Xcode

### For Main App Target (BudgetInsight)
- [ ] App Groups capability
- [ ] App Group ID: `group.com.budgetinsight.shared`

### For Widget Target (BudgetInsightWidget)  
- [ ] App Groups capability
- [ ] App Group ID: `group.com.budgetinsight.shared`

⚠️ **Important**: The App Group ID must match exactly in both targets!

## Quick Setup Steps

1. **Create Widget Extension**
   - File → New → Target → Widget Extension
   - Name: `BudgetInsightWidget`
   - Uncheck "Include Configuration Intent"

2. **Add Files to Widget Target**
   - Select each file in `BudgetInsightWidget/`
   - Check "BudgetInsightWidget" in File Inspector

3. **Add Models to Both Targets**
   - Select each model file
   - Check BOTH "BudgetInsight" AND "BudgetInsightWidget"

4. **Configure App Groups**
   - Select project → BudgetInsight target → Capabilities
   - Add "App Groups" → `group.com.budgetinsight.shared`
   - Select project → BudgetInsightWidget target → Capabilities  
   - Add "App Groups" → `group.com.budgetinsight.shared`

5. **Build and Run**
   - Select BudgetInsight scheme
   - Build and run (⌘R)
   - Add widgets to home screen

## Verification

After setup, verify:

- [ ] Widget extension builds without errors
- [ ] Main app builds without errors
- [ ] App runs and data migrates to shared container
- [ ] Widgets appear in widget gallery
- [ ] Small widget displays spending data
- [ ] Medium widget displays starred categories
- [ ] Widgets update when you add transactions

If anything doesn't work, see `WIDGET_SETUP_GUIDE.md` for troubleshooting.
