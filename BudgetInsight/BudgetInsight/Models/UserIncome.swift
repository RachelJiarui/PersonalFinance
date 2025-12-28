import Foundation

/// Represents user income and tax calculations for a specific year
/// Used by BudgetPlan to calculate monthly take-home for budget allocation
struct UserIncome: Identifiable, Codable, Equatable {
    // ID - Firestore auto-generates, empty until saved to backend
    var id: String

    let year: Int  // Year this income applies to
    var annualSalary: Double  // Gross annual salary
    var contribution401k: Double  // Pre-tax 401k contribution

    // Tax amounts (calculated by TaxService)
    var federalTax: Double
    var socialSecurityTax: Double
    var medicareTax: Double
    var nyStateTax: Double
    var nycTax: Double

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

    init(
        id: String = "", year: Int, annualSalary: Double, contribution401k: Double,
        federalTax: Double = 0, socialSecurityTax: Double = 0, medicareTax: Double = 0,
        nyStateTax: Double = 0, nycTax: Double = 0
    ) {
        self.id = id
        self.year = year
        self.annualSalary = annualSalary
        self.contribution401k = contribution401k
        self.federalTax = federalTax
        self.socialSecurityTax = socialSecurityTax
        self.medicareTax = medicareTax
        self.nyStateTax = nyStateTax
        self.nycTax = nycTax
    }
}
