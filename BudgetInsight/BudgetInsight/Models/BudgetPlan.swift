import Foundation

/// Represents the budget plan for a specific year
/// Supports versioning - multiple budget plans can exist for the same year with different effective dates
struct BudgetPlan: Identifiable, Codable, Equatable {
    // ID - Firestore auto-generates, empty until saved to backend
    var id: String

    let year: Int
    let annualSalaryGross: Double
    let userIncomeId: String  // Links to UserIncome for tax calculations (Firestore ID)
    var categoryIds: [String]  // List of BudgetCategory IDs (only active categories, Firestore IDs)

    // Versioning fields - support mid-year budget changes without affecting historical data
    var isActive: Bool  // Only one active plan per year at any time
    var effectiveDate: Date  // When this version became active
    var endDate: Date?  // When superseded by new version (nil if still active)
    var versionNumber: Int  // Human-readable version (v1, v2, v3... per year)
    var changeReason: String?  // Optional description of why version was created
    var supersededByPlanId: String?  // ID of the plan that replaced this one

    init(
        id: String = "",
        year: Int,
        annualSalaryGross: Double,
        userIncomeId: String,
        categoryIds: [String] = [],
        isActive: Bool = true,
        effectiveDate: Date = Date(),
        endDate: Date? = nil,
        versionNumber: Int = 1,
        changeReason: String? = nil,
        supersededByPlanId: String? = nil
    ) {
        self.id = id
        self.year = year
        self.annualSalaryGross = annualSalaryGross
        self.userIncomeId = userIncomeId
        self.categoryIds = categoryIds
        self.isActive = isActive
        self.effectiveDate = effectiveDate
        self.endDate = endDate
        self.versionNumber = versionNumber
        self.changeReason = changeReason
        self.supersededByPlanId = supersededByPlanId
    }

    // MARK: - Helper Methods

    /// Check if this plan is currently active (not superseded and effectiveDate has passed)
    var isCurrentlyActive: Bool {
        guard isActive else { return false }
        let now = Date()
        return effectiveDate <= now && (endDate == nil || now < endDate!)
    }

    /// Check if this plan was active on a specific date
    /// - Parameter date: The date to check
    /// - Returns: True if the plan was active on that date
    func wasActive(on date: Date) -> Bool {
        let afterStart = date >= effectiveDate
        let beforeEnd = endDate == nil || date < endDate!
        return afterStart && beforeEnd
    }
}
