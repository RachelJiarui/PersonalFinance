import Foundation

/// Represents the budget plan for a specific year
/// The active budget plan is the one matching the current year
struct BudgetPlan: Identifiable, Codable, Equatable {
    // ID - Firestore auto-generates, empty until saved to backend
    var id: String

    let year: Int
    let annualSalaryGross: Double
    let userIncomeId: String  // Links to UserIncome for tax calculations (Firestore ID)
    var categoryIds: [String]  // List of BudgetCategory IDs (only active categories, Firestore IDs)

    init(
        id: String = "", year: Int, annualSalaryGross: Double, userIncomeId: String,
        categoryIds: [String] = []
    ) {
        self.id = id
        self.year = year
        self.annualSalaryGross = annualSalaryGross
        self.userIncomeId = userIncomeId
        self.categoryIds = categoryIds
    }

    // Check if this is the active budget plan
    var isActive: Bool {
        let currentYear = Calendar.current.component(.year, from: Date())
        return year == currentYear
    }
}
