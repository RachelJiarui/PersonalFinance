import Foundation

/// Represents a financial transaction (always manually entered)
struct Transaction: Identifiable, Codable {
    // ID - Firestore auto-generates, empty until saved to backend
    var id: String

    // Required fields
    let amount: Double
    let date: Date
    let title: String
    let categoryId: String  // BudgetCategory ID (Firestore auto-generated)
    let isExpense: Bool  // True if expense, False if income

    // Automatic
    let timestamp: Date  // Auto-set to now() when creating transaction

    // Optional
    let linkedEmailAlertId: String?  // Links to TransactionAlert when matched

    init(
        id: String = "", amount: Double, date: Date, title: String,
        categoryId: String, isExpense: Bool, timestamp: Date = Date(),
        linkedEmailAlertId: String? = nil
    ) {
        self.id = id
        self.amount = amount
        self.date = date
        self.title = title
        self.categoryId = categoryId
        self.isExpense = isExpense
        self.timestamp = timestamp
        self.linkedEmailAlertId = linkedEmailAlertId
    }
}
