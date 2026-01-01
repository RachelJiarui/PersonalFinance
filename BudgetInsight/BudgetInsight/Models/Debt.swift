import Foundation

/// Represents a debt that needs to be paid off
/// Created when spending exceeds budget and needs to be covered in future months
struct Debt: Identifiable, Codable, Equatable {
    // ID - Firestore auto-generates, empty until saved to backend
    var id: String

    // Required fields
    var name: String
    var icon: String  // SF Symbol name
    var description: String
    var balance: Double  // Current amount owed
    var goal: Double  // REQUIRED - target amount to pay off

    // Optional - for UI
    var deadline: Date?  // Payment deadline

    // Automatic
    var createdAt: Date  // When debt was created
    var isActive: Bool  // Soft delete flag
    var isDefault: Bool  // True for default debts (cannot be deleted)

    init(
        id: String = "",
        name: String,
        icon: String,
        description: String,
        balance: Double,
        goal: Double,
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
    func progressRatio() -> Double {
        guard goal > 0 else { return 0 }
        // For debt, progress is how much has been paid off
        let paidOff = max(0, goal - balance)
        return min(paidOff / goal, 1.0)
    }

    func isPaidOff() -> Bool {
        return balance <= 0
    }

    func remainingToPay() -> Double {
        return max(0, balance)
    }
}
