import Foundation

struct CategoryBalance {
    let category: BudgetCategory
    let budgetAmount: Double
    let actualSpending: Double
    var allocatedTo: BalancingDestination?

    // Computed properties
    var surplus: Double {
        max(0, budgetAmount - actualSpending)
    }

    var deficit: Double {
        max(0, actualSpending - budgetAmount)
    }

    var hasBalance: Bool {
        surplus > 0 || deficit > 0
    }

    var isFullyAllocated: Bool {
        allocatedTo != nil
    }
}
