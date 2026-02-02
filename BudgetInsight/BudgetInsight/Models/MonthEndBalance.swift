import Foundation

struct MonthEndBalance: Identifiable, Codable {
    var id: String = ""  // Firestore-generated ID
    let year: Int
    let month: Int
    let isBalanced: Bool
    let balancedAt: Date?
    let balancingTransactionIds: [String]  // IDs of transactions created during balancing

    // Optional metadata for audit trail
    let diffSpending: Double?  // Total savings/deficit for the month
    let categoriesProcessed: Int?

    init(
        year: Int,
        month: Int,
        isBalanced: Bool = false,
        balancedAt: Date? = nil,
        balancingTransactionIds: [String] = [],
        diffSpending: Double? = nil,
        categoriesProcessed: Int? = nil
    ) {
        self.year = year
        self.month = month
        self.isBalanced = isBalanced
        self.balancedAt = balancedAt
        self.balancingTransactionIds = balancingTransactionIds
        self.diffSpending = diffSpending
        self.categoriesProcessed = categoriesProcessed
    }
}
