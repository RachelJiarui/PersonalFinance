import Foundation

struct MonthWrappedStats {
    let year: Int
    let month: Int
    let monthlyTakeHome: Double

    // Category-level breakdown
    let categoryBalances: [CategoryBalance]

    // Top-level aggregates
    let totalIncome: Double
    let totalSpending: Double
    let netSavings: Double  // monthlyTakeHome (budget) - spending (can be negative)
    let transactionCount: Int

    // Computed helpers
    var hasSurplus: Bool { netSavings > 0 }
    var hasDeficit: Bool { netSavings < 0 }
    var categoriesWithSavings: [CategoryBalance] { categoryBalances.filter { $0.surplus > 0 } }
    var categoriesWithDeficits: [CategoryBalance] { categoryBalances.filter { $0.deficit > 0 } }

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
