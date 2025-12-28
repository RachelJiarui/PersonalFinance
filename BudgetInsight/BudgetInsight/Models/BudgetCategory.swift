import Foundation

/// Represents a budget category for tracking spending
/// Note: Categories are immutable once isActive = false (for historical data integrity)
struct BudgetCategory: Identifiable, Codable, Equatable {
    // ID - Firestore auto-generates, empty until saved to backend
    var id: String

    // Required fields
    var name: String  // Can edit if isActive = true
    var percentage: Double  // 0-100, can edit if isActive = true
    var icon: String  // SF Symbol name, can edit if isActive = true
    var isActive: Bool  // Once false, category becomes immutable

    init(id: String = "", name: String, percentage: Double, icon: String, isActive: Bool = true) {
        self.id = id
        self.name = name
        self.percentage = percentage
        self.icon = icon
        self.isActive = isActive
    }

    // Helper methods for budget calculations
    func dollarAmount(monthlyTakeHome: Double) -> Double {
        monthlyTakeHome * (percentage / 100.0)
    }

    // Calculate spending ratio for progress ring (0.0 to 1.0+)
    func spendingRatio(currentSpent: Double, monthlyTakeHome: Double) -> Double {
        let budget = dollarAmount(monthlyTakeHome: monthlyTakeHome)
        guard budget > 0 else { return 0 }
        return currentSpent / budget
    }

    // Remaining budget for the month
    func monthlyRemaining(currentSpent: Double, monthlyTakeHome: Double) -> Double {
        let budget = dollarAmount(monthlyTakeHome: monthlyTakeHome)
        return max(0, budget - currentSpent)
    }
}
