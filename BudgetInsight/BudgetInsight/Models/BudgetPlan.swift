import Foundation

/// Represents a budget plan with monthly time-range model
/// Budget plans span months and can cross calendar years (e.g., Nov 2025 - Feb 2026)
/// Income and tax data is included directly in the BudgetPlan
struct BudgetPlan: Identifiable, Codable, Equatable {
    // ID - Firestore auto-generates, empty until saved to backend
    var id: String

    // Time range (month/year precision)
    let createdAt: Date  // First month active (stored as first day of month)
    let endDate: Date?  // Exclusive - first month NOT covered (nil = active)

    // Income & Taxes
    let annualSalary: Double
    let contribution401k: Double
    let federalTax: Double
    let socialSecurityTax: Double
    let medicareTax: Double
    let nyStateTax: Double
    let nycTax: Double

    // Categories
    var categoryIds: [String]  // Active budget category UUIDs

    // MARK: - Coding Keys

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case endDate = "end_date"
        case annualSalary = "annual_salary"
        case contribution401k = "contribution_401k"
        case federalTax = "federal_tax"
        case socialSecurityTax = "social_security_tax"
        case medicareTax = "medicare_tax"
        case nyStateTax = "ny_state_tax"
        case nycTax = "nyc_tax"
        case categoryIds = "category_ids"
    }

    init(
        id: String = "",
        createdAt: Date,
        endDate: Date? = nil,
        annualSalary: Double,
        contribution401k: Double,
        federalTax: Double,
        socialSecurityTax: Double,
        medicareTax: Double,
        nyStateTax: Double,
        nycTax: Double,
        categoryIds: [String] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.endDate = endDate
        self.annualSalary = annualSalary
        self.contribution401k = contribution401k
        self.federalTax = federalTax
        self.socialSecurityTax = socialSecurityTax
        self.medicareTax = medicareTax
        self.nyStateTax = nyStateTax
        self.nycTax = nycTax
        self.categoryIds = categoryIds
    }

    // MARK: - Computed Properties

    var taxableIncome: Double {
        annualSalary - contribution401k
    }

    var totalTaxes: Double {
        federalTax + socialSecurityTax + medicareTax + nyStateTax + nycTax
    }

    var annualTakeHome: Double {
        annualSalary - contribution401k - totalTaxes
    }

    var monthlyTakeHome: Double {
        annualTakeHome / 12.0
    }

    var isActive: Bool {
        endDate == nil
    }

    // MARK: - Helper Methods

    /// Check if this plan covers a specific date
    /// - Parameter date: The date to check
    /// - Returns: True if the plan covers that date
    func covers(date: Date) -> Bool {
        let calendar = Calendar.current
        let targetMonth = calendar.startOfMonth(for: date)
        let planStartMonth = calendar.startOfMonth(for: createdAt)

        if let endDate = endDate {
            let planEndMonth = calendar.startOfMonth(for: endDate)
            // Range is [createdAt, endDate) - exclusive end
            return targetMonth >= planStartMonth && targetMonth < planEndMonth
        } else {
            // Active plan (no end date)
            return targetMonth >= planStartMonth
        }
    }

    /// Get month/year string for created_at
    /// - Returns: Formatted string like "March 2025"
    func createdAtMonthYear() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: createdAt)
    }

    /// Get date range string for display
    /// - Returns: Formatted string like "March 2025 - June 2025" or "March 2025 - Present"
    func dateRangeString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"

        let start = formatter.string(from: createdAt)

        if let endDate = endDate {
            let end = formatter.string(from: endDate)
            return "\(start) - \(end)"
        } else {
            return "\(start) - Present"
        }
    }
}

// MARK: - Calendar Extension

extension Calendar {
    /// Get the first day of the month for a given date
    /// - Parameter date: The date
    /// - Returns: Date representing first day of that month
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components)!
    }
}
