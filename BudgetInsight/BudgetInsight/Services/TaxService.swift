import Foundation

class TaxService {
    static let shared = TaxService()

    private init() {}

    // MARK: - 2025 Tax Brackets

    // 2025 Federal Tax Brackets (Single Filer)
    private let federalBrackets2025: [(threshold: Double, rate: Double)] = [
        (0, 0.10),
        (11_925, 0.12),
        (48_475, 0.22),
        (103_350, 0.24),
        (197_300, 0.32),
        (250_525, 0.35),
        (626_350, 0.37)
    ]

    private let standardDeduction2025: Double = 15_000

    // NY State Tax Brackets 2025 (Single Filer)
    private let nyStateBrackets2025: [(threshold: Double, rate: Double)] = [
        (0, 0.04),
        (8_500, 0.045),
        (11_700, 0.0525),
        (13_900, 0.0585),
        (80_650, 0.0625),
        (215_400, 0.0685),
        (1_077_550, 0.0965),
        (5_000_000, 0.103),
        (25_000_000, 0.109)
    ]

    // NYC Tax Brackets 2025 (Single Filer)
    private let nycBrackets2025: [(threshold: Double, rate: Double)] = [
        (0, 0.03078),
        (12_000, 0.03762),
        (25_000, 0.03819),
        (50_000, 0.03876)
    ]

    // Flat rates
    private let socialSecurityRate: Double = 0.062
    private let socialSecurityWageBase2025: Double = 176_100
    private let medicareRate: Double = 0.0145

    // MARK: - Tax Calculation Methods

    func calculateFederalTax(taxableIncome: Double) -> Double {
        let deductedIncome = max(0, taxableIncome - standardDeduction2025)
        return calculateProgressiveTax(income: deductedIncome, brackets: federalBrackets2025)
    }

    func calculateSocialSecurityTax(grossIncome: Double) -> Double {
        let cappedIncome = min(grossIncome, socialSecurityWageBase2025)
        return cappedIncome * socialSecurityRate
    }

    func calculateMedicareTax(grossIncome: Double) -> Double {
        return grossIncome * medicareRate
    }

    func calculateNYStateTax(taxableIncome: Double) -> Double {
        return calculateProgressiveTax(income: taxableIncome, brackets: nyStateBrackets2025)
    }

    func calculateNYCTax(taxableIncome: Double) -> Double {
        return calculateProgressiveTax(income: taxableIncome, brackets: nycBrackets2025)
    }

    // MARK: - Progressive Tax Algorithm

    private func calculateProgressiveTax(income: Double, brackets: [(threshold: Double, rate: Double)]) -> Double {
        var tax: Double = 0
        var previousThreshold: Double = 0

        for (index, bracket) in brackets.enumerated() {
            // Determine the upper bound for this bracket
            let nextThreshold = index < brackets.count - 1 ? brackets[index + 1].threshold : Double.infinity

            if income <= bracket.threshold {
                // Income doesn't reach this bracket
                break
            }

            // Calculate taxable amount in this bracket
            let upperBound = min(income, nextThreshold)
            let taxableInBracket = upperBound - bracket.threshold

            if taxableInBracket > 0 {
                tax += taxableInBracket * bracket.rate
            }
        }

        return tax
    }

    // MARK: - Main Tax Calculation

    func calculateAllTaxes(annualSalary: Double, contribution401k: Double) -> UserIncome {
        let taxableIncome = annualSalary - contribution401k

        let federal = calculateFederalTax(taxableIncome: taxableIncome)
        let socialSecurity = calculateSocialSecurityTax(grossIncome: annualSalary)
        let medicare = calculateMedicareTax(grossIncome: annualSalary)
        let nyState = calculateNYStateTax(taxableIncome: taxableIncome)
        let nyc = calculateNYCTax(taxableIncome: taxableIncome)

        return UserIncome(
            annualSalary: annualSalary,
            contribution401k: contribution401k,
            federalTax: federal,
            socialSecurityTax: socialSecurity,
            medicareTax: medicare,
            nyStateTax: nyState,
            nycTax: nyc
        )
    }
}
