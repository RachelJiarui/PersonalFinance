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

    // Optional link to TransactionAlert
    var transactionAlertId: String?  // Links to TransactionAlert that this resolves

    enum CodingKeys: String, CodingKey {
        case id
        case amount
        case date
        case title
        case isExpense = "is_expense"
        case timestamp
        case transactionAlertId = "transaction_alert_id"
    }

    init(
        id: String = "", amount: Double, date: Date, title: String,
        isExpense: Bool, timestamp: Date = Date(), transactionAlertId: String? = nil
    ) {
        self.id = id
        self.amount = amount
        self.date = date
        self.title = title
        self.isExpense = isExpense
        self.timestamp = timestamp
        self.transactionAlertId = transactionAlertId
    }
}
