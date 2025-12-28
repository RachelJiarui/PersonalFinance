import Foundation

/// Represents an email alert from Gmail API (transaction notifications from credit cards)
struct TransactionAlert: Identifiable, Codable {
    // ID - Firestore auto-generates, empty until saved to backend
    var id: String

    // Required fields (all parsed from Gmail API email)
    let emailId: String  // Gmail message ID
    let merchant: String
    let date: Date
    let amount: Double
    let rawEmailBody: String  // Store for debugging/re-parsing if needed
    let receivedAt: Date  // When the email was received

    // Optional - bidirectional link to Transaction
    let linkedTransactionId: String?  // Links to Transaction when resolved

    // Computed property
    var isResolved: Bool {
        linkedTransactionId != nil
    }

    init(
        id: String = "", emailId: String, merchant: String, date: Date, amount: Double,
        rawEmailBody: String, receivedAt: Date = Date(), linkedTransactionId: String? = nil
    ) {
        self.id = id
        self.emailId = emailId
        self.merchant = merchant
        self.date = date
        self.amount = amount
        self.rawEmailBody = rawEmailBody
        self.receivedAt = receivedAt
        self.linkedTransactionId = linkedTransactionId
    }
}
