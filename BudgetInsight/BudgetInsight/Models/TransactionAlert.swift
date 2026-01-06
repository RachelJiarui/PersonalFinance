import Foundation

/// Represents a transaction alert parsed from email (Discover card)
/// Users can review and resolve these by creating actual Transaction entries
struct TransactionAlert: Identifiable, Codable {
    // ID - Firestore auto-generates
    var id: String

    // Required fields from email
    let emailId: String  // Gmail message ID (unique)
    let merchant: String  // Parsed merchant name
    let transactionDate: Date  // Parsed transaction date
    let amount: Double  // Parsed amount
    let rawEmailBody: String  // Full email body for debugging

    // Optional fields
    let cardLast4: String?  // Last 4 digits of card

    // Metadata
    let receivedAt: Date  // When alert was received

    // Resolution
    var isResolved: Bool  // Whether user has resolved this alert
    var resolvedTransactionId: String?  // Link to created Transaction (if resolved)

    enum CodingKeys: String, CodingKey {
        case id
        case emailId = "email_id"
        case merchant
        case transactionDate = "transaction_date"
        case amount
        case rawEmailBody = "raw_email_body"
        case cardLast4 = "card_last4"
        case receivedAt = "received_at"
        case isResolved = "is_resolved"
        case resolvedTransactionId = "resolved_transaction_id"
    }

    init(
        id: String = "",
        emailId: String,
        merchant: String,
        transactionDate: Date,
        amount: Double,
        rawEmailBody: String,
        cardLast4: String? = nil,
        receivedAt: Date = Date(),
        isResolved: Bool = false,
        resolvedTransactionId: String? = nil
    ) {
        self.id = id
        self.emailId = emailId
        self.merchant = merchant
        self.transactionDate = transactionDate
        self.amount = amount
        self.rawEmailBody = rawEmailBody
        self.cardLast4 = cardLast4
        self.receivedAt = receivedAt
        self.isResolved = isResolved
        self.resolvedTransactionId = resolvedTransactionId
    }
}
