import Foundation

struct FundDebtAllocation: Identifiable {
    var id: String { "\(transactionId)-\(destinationId)" }
    let transactionId: String
    let transactionTitle: String
    let transactionDate: Date
    let destinationType: AllocationType  // .fund or .debt
    let destinationId: String
    let destinationName: String
    let destinationIcon: String
    let amount: Double
    let isExpense: Bool
}

struct MonthWrappedStats {
    let year: Int
    let month: Int
    let monthlyTakeHome: Double

    // Category-level breakdown
    let categoryBalances: [CategoryBalance]

    // Fund/Debt allocations for this month
    let fundDebtAllocations: [FundDebtAllocation]

    // Top-level aggregates
    let totalIncome: Double
    let totalSpending: Double
    let diffSpending: Double  // monthlyTakeHome (budget) - spending (can be negative)
    let expenseTransactionCount: Int
    let incomeTransactionCount: Int

    var transactionCount: Int {
        expenseTransactionCount + incomeTransactionCount
    }

    // Computed helpers
    var hasSurplus: Bool { diffSpending > 0 }
    var hasDeficit: Bool { diffSpending < 0 }
    var categoriesWithSavings: [CategoryBalance] { categoryBalances.filter { $0.surplus > 0 } }
    var categoriesWithDeficits: [CategoryBalance] { categoryBalances.filter { $0.deficit > 0 } }
    var fundAllocations: [FundDebtAllocation] {
        fundDebtAllocations.filter { $0.destinationType == .fund }
    }
    var debtAllocations: [FundDebtAllocation] {
        fundDebtAllocations.filter { $0.destinationType == .debt }
    }

    var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        let calendar = Calendar.current
        let components = DateComponents(year: year, month: month)
        if let date = calendar.date(from: components) {
            return formatter.string(from: date)
        }
        return "Month \(month)"
    }
}
