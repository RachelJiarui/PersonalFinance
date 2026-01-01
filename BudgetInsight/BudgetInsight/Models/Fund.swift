import Foundation

/// Represents a savings fund for larger purchases or goals
/// Funds persist across years and can have optional goals
struct Fund: Identifiable, Codable, Equatable {
    // ID - Firestore auto-generates, empty until saved to backend
    var id: String

    // Required fields
    var name: String
    var icon: String  // SF Symbol name
    var description: String
    var balance: Double  // Current balance

    // Optional - for UI/goal tracking
    var goal: Double?  // Can exceed this goal
    var deadline: Date?  // Urgency tracking

    // Automatic
    var createdAt: Date  // When fund was created
    var isActive: Bool  // Soft delete flag
    var isDefault: Bool  // True for default funds (cannot be deleted)

    init(
        id: String = "",
        name: String,
        icon: String,
        description: String,
        balance: Double = 0.0,
        goal: Double? = nil,
        deadline: Date? = nil,
        createdAt: Date = Date(),
        isActive: Bool = true,
        isDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.description = description
        self.balance = balance
        self.goal = goal
        self.deadline = deadline
        self.createdAt = createdAt
        self.isActive = isActive
        self.isDefault = isDefault
    }

    // Helper methods for UI
    func progressRatio() -> Double? {
        guard let goal = goal, goal > 0 else { return nil }
        return min(balance / goal, 1.0)
    }

    func isGoalMet() -> Bool {
        guard let goal = goal else { return false }
        return balance >= goal
    }

    func remainingToGoal() -> Double? {
        guard let goal = goal else { return nil }
        return max(0, goal - balance)
    }
}
