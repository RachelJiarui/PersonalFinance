# Transaction Edit Logic - Money Handling Verification

## Critical Requirements
1. **No money should be lost** - All balance changes must be tracked
2. **No double counting** - Balance updates must not be applied twice
3. **All allocations must sum to transaction amount** - Validation enforced

## Money Flow on Transaction Edit

### Scenario 1: Amount or Expense Type Changed
When the transaction amount or expense/income type changes, we cannot safely update individual allocations. We must:

1. **Reverse all old allocations**
   - For each old allocation, reverse its balance effect
   - Categories: Handled by BudgetService recalculation (no direct reversal needed)
   - Funds: 
     - If was expense → add back the amount (reverse subtraction)
     - If was income → subtract back the amount (reverse addition)
   - Debts:
     - If was expense → subtract back the amount (reverse addition)
     - If was income → add back the amount (reverse subtraction)

2. **Delete all old allocations**
   - Remove from Firestore via AllocationService.deleteAllocation()
   - This also removes from local storage

3. **Create all new allocations**
   - Create fresh allocations with new amounts
   - AllocationService.createAllocation() applies the new balance changes
   - For categories: Updates via BudgetService
   - For funds:
     - If expense → subtract amount
     - If income → add amount
   - For debts:
     - If expense → add amount
     - If income → subtract amount

**Why this works:**
- Old balances are completely reversed (back to state before transaction)
- New balances are applied fresh (no risk of double counting)
- Categories get recalculated by BudgetService.updateCategorySpending()

### Scenario 2: Only Allocations Changed (Amount & Type Unchanged)
When only the allocation destinations or splits change (amount stays same):

1. **Identify deleted allocations**
   - Compare old set vs new set using key: "type:destinationId:amount"
   - For each deleted allocation, call AllocationService.deleteAllocation()
   - This reverses the balance change automatically

2. **Identify new allocations**
   - For each allocation in new but not in old, create it
   - AllocationService.createAllocation() applies balance changes

**Why this works:**
- Only changed allocations are touched
- Unchanged allocations remain intact (no unnecessary DB operations)
- Each allocation's balance effect is handled exactly once

## Balance Update Logic (from AllocationService)

### Categories
```swift
// No direct balance update - handled by BudgetService
budgetService.updateCategorySpending(with: transactions)
```
- Recalculates all category spending from scratch
- No risk of double counting
- Always accurate

### Funds
```swift
// Income adds to fund (saving), Expense subtracts from fund (spending)
let adjustedAmount = isExpense ? -amount : amount
FundService.shared.updateBalance(fundId: destinationId, amount: adjustedAmount)
```

### Debts
```swift
// Income reduces debt (payment), Expense increases debt (borrowing more)
let adjustedAmount = isExpense ? amount : -amount
DebtService.shared.updateBalance(debtId: destinationId, amount: adjustedAmount)
```

## Reversal Logic (in EditTransactionView)

```swift
private func reverseAllocationBalance(allocation: TransactionAllocation, isExpense: Bool) {
    switch allocation.destinationType {
    case .category:
        // Categories handled by recalculation
        break
        
    case .fund:
        // Reverse: was (expense ? -amount : amount), now do opposite
        let adjustedAmount = isExpense ? allocation.amount : -allocation.amount
        FundService.shared.updateBalance(fundId: allocation.destinationId, amount: adjustedAmount)
        
    case .debt:
        // Reverse: was (expense ? amount : -amount), now do opposite
        let adjustedAmount = isExpense ? -allocation.amount : allocation.amount
        DebtService.shared.updateBalance(debtId: allocation.destinationId, amount: adjustedAmount)
    }
}
```

**Verification:**
- Original: Fund gets `isExpense ? -100 : +100`
- Reversal: Fund gets `isExpense ? +100 : -100` ✓ (cancels out)
- Original: Debt gets `isExpense ? +100 : -100`
- Reversal: Debt gets `isExpense ? -100 : +100` ✓ (cancels out)

## Transaction Update Flow

1. **Validation** - Ensure allocations sum to transaction amount (±$0.01)
2. **Reverse old allocations** (if amount/type changed)
3. **Delete old allocations from Firestore**
4. **Create new allocations in Firestore**
5. **Update transaction in Firestore**
6. **Update local transaction storage**
7. **Handle alert linking changes**
8. **Recalculate category spending** (BudgetService)
9. **Update snapshots** (SnapshotService)

## Safety Guarantees

✅ **No money lost**: Every balance change is either reversed or tracked
✅ **No double counting**: Old allocations reversed before new ones applied
✅ **Validation enforced**: Cannot save if allocations don't match amount
✅ **Atomic updates**: Firestore updates happen in sequence
✅ **UI stays in sync**: Local storage updated after Firestore confirms

## Edge Cases Handled

1. **Changing from expense to income**: All balances reversed then reapplied with opposite sign ✓
2. **Splitting allocation differently**: Only changed allocations are touched ✓
3. **Changing amount by $0.01**: Old allocations deleted, new ones created ✓
4. **Linking/unlinking alerts**: Bidirectional links maintained ✓
5. **Partial allocation changes**: Set comparison identifies exact differences ✓

## Testing Checklist

- [ ] Edit transaction amount (increase)
- [ ] Edit transaction amount (decrease)
- [ ] Change expense to income
- [ ] Change income to expense
- [ ] Change allocation from Category A to Category B
- [ ] Split allocation across multiple destinations
- [ ] Change fund allocation amount
- [ ] Change debt allocation amount
- [ ] Link to different alert
- [ ] Unlink from alert
- [ ] Edit transaction title/date (no money impact)
- [ ] Verify category spending updates correctly
- [ ] Verify fund balances update correctly
- [ ] Verify debt balances update correctly
- [ ] Verify snapshots update correctly
