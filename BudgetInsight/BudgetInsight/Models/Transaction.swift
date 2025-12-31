import Foundation

/// Represents a financial transaction (always manually entered)
/// Note: Allocations to categories/funds/debts are stored separately in TransactionAllocation
struct Transaction: Identifiable, Codable {
    // ID - Firestore auto-generates, empty until saved to backend
    var id: String

    // Required fields
    let amount: Double
    let date: Date
    let title: String
    let isExpense: Bool  // True if expense, False if income

    // Automatic
    let timestamp: Date  // Auto-set to now() when creating transaction

    init(
        id: String = "", amount: Double, date: Date, title: String,
        isExpense: Bool, timestamp: Date = Date()
    ) {
        self.id = id
        self.amount = amount
        self.date = date
        self.title = title
        self.isExpense = isExpense
        self.timestamp = timestamp
    }
}
