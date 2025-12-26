import Foundation

/// Represents an email alert from Discover card that needs to be matched with a manual transaction entry
struct TransactionAlert: Identifiable, Codable {
    let id: String
    let emailId: String  // Gmail message ID
    let merchant: String
    let date: Date
    let amount: Double
    let rawEmailBody: String  // Store for debugging/re-parsing if needed
    let receivedAt: Date  // When the email was received

    /// Whether this alert has been linked to a manual transaction entry
    var isLinked: Bool = false

    init(id: String = UUID().uuidString, emailId: String, merchant: String, date: Date, amount: Double, rawEmailBody: String, receivedAt: Date = Date()) {
        self.id = id
        self.emailId = emailId
        self.merchant = merchant
        self.date = date
        self.amount = amount
        self.rawEmailBody = rawEmailBody
        self.receivedAt = receivedAt
    }
}
