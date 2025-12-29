import Foundation

/// Represents how a transaction's amount is allocated across destinations
/// Enables split allocations across categories, funds, and debts
struct TransactionAllocation: Identifiable, Codable, Equatable {
    // ID - Firestore auto-generates, empty until saved to backend
    var id: String

    // Required fields
    let transactionId: String  // Links to Transaction
    let destinationType: AllocationType
    let destinationId: String  // ID of Category/Fund/Debt
    let amount: Double  // Dollar amount of this allocation

    // Automatic
    let allocatedAt: Date  // When allocation was made

    init(
        id: String = "",
        transactionId: String,
        destinationType: AllocationType,
        destinationId: String,
        amount: Double,
        allocatedAt: Date = Date()
    ) {
        self.id = id
        self.transactionId = transactionId
        self.destinationType = destinationType
        self.destinationId = destinationId
        self.amount = amount
        self.allocatedAt = allocatedAt
    }
}

/// Type of destination for a transaction allocation
enum AllocationType: String, Codable {
    case category
    case fund
    case debt
}
