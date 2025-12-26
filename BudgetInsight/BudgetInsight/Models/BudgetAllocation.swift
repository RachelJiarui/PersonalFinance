import Foundation

struct BudgetAllocation: Codable, Equatable {
    var categories: [BudgetCategory]
    var emergencyBufferId: UUID  // Special category for remaining percentage

    init(categories: [BudgetCategory] = [], emergencyBufferId: UUID = UUID()) {
        self.categories = categories
        self.emergencyBufferId = emergencyBufferId
    }

    // Total percentage allocated across all categories
    var totalPercentage: Double {
        categories.reduce(0) { $0 + $1.percentage }
    }

    // Check if allocation is valid (must equal 100% ± 0.01 for floating point)
    var isValid: Bool {
        abs(totalPercentage - 100.0) < 0.01
    }

    // Emergency buffer percentage (fills remaining to reach 100%)
    func emergencyBufferPercentage() -> Double {
        max(0, 100.0 - totalPercentage)
    }

    // Emergency buffer in dollars
    func emergencyBufferAmount(monthlyTakeHome: Double) -> Double {
        monthlyTakeHome * (emergencyBufferPercentage() / 100.0)
    }

    // Check if total exceeds 100%
    var isOverAllocated: Bool {
        totalPercentage > 100.01
    }
}
