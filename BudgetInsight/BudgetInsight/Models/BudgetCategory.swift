import Foundation

struct BudgetCategory: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var percentage: Double  // 0-100
    var icon: String        // SF Symbol name
    var color: String       // Hex color or system color name
    var currentMonthSpent: Double

    init(id: UUID = UUID(), name: String, percentage: Double, icon: String, color: String, currentMonthSpent: Double = 0) {
        self.id = id
        self.name = name
        self.percentage = percentage
        self.icon = icon
        self.color = color
        self.currentMonthSpent = currentMonthSpent
    }

    // Calculate dollar amount from percentage and monthly take-home
    func dollarAmount(monthlyTakeHome: Double) -> Double {
        monthlyTakeHome * (percentage / 100.0)
    }

    // Calculate spending ratio for progress ring (0.0 to 1.0+)
    func spendingRatio(monthlyTakeHome: Double) -> Double {
        let budget = dollarAmount(monthlyTakeHome: monthlyTakeHome)
        guard budget > 0 else { return 0 }
        return currentMonthSpent / budget
    }

    // Remaining budget for the month
    func monthlyRemaining(monthlyTakeHome: Double) -> Double {
        let budget = dollarAmount(monthlyTakeHome: monthlyTakeHome)
        return max(0, budget - currentMonthSpent)
    }
}
