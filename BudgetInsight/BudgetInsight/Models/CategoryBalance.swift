import Foundation

struct CategoryBalance {
    let category: BudgetCategory
    let budgetAmount: Double
    let actualSpending: Double
    var allocatedTo: BalancingDestination?

    // Computed properties (rounded to 2 decimal places)
    var surplus: Double {
        let value = max(0, budgetAmount - actualSpending)
        return (value * 100).rounded() / 100
    }

    var deficit: Double {
        let value = max(0, actualSpending - budgetAmount)
        return (value * 100).rounded() / 100
    }

    var hasBalance: Bool {
        surplus > 0 || deficit > 0
    }

    var isFullyAllocated: Bool {
        allocatedTo != nil
    }
}
