import Foundation

struct Budget: Identifiable, Codable {
    let id: UUID
    let category: TransactionCategory
    var monthlyLimit: Double
    var yearlyLimit: Double
    var currentMonthSpent: Double
    var currentYearSpent: Double

    var monthlyPercentage: Double {
        guard monthlyLimit > 0 else { return 0 }
        return (currentMonthSpent / monthlyLimit) * 100
    }

    var yearlyPercentage: Double {
        guard yearlyLimit > 0 else { return 0 }
        return (currentYearSpent / yearlyLimit) * 100
    }

    var monthlyRemaining: Double {
        monthlyLimit - currentMonthSpent
    }

    var yearlyRemaining: Double {
        yearlyLimit - currentYearSpent
    }

    var isOverMonthlyBudget: Bool {
        currentMonthSpent > monthlyLimit
    }

    var isOverYearlyBudget: Bool {
        currentYearSpent > yearlyLimit
    }

    var status: BudgetStatus {
        if monthlyPercentage >= 100 {
            return .exceeded
        } else if monthlyPercentage >= 80 {
            return .warning
        } else {
            return .healthy
        }
    }
}

enum BudgetStatus {
    case healthy
    case warning
    case exceeded

    var color: String {
        switch self {
        case .healthy: return "green"
        case .warning: return "orange"
        case .exceeded: return "red"
        }
    }
}

struct SpendingSummary {
    let totalIncome: Double
    let totalExpenses: Double
    let categoryBreakdown: [TransactionCategory: Double]
    let monthOverMonth: Double
    let topSpendingCategory: TransactionCategory?

    var netCashFlow: Double {
        totalIncome - totalExpenses
    }

    var savingsRate: Double {
        guard totalIncome > 0 else { return 0 }
        return (netCashFlow / totalIncome) * 100
    }
}
