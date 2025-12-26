import Foundation

struct PeriodSnapshot: Identifiable, Codable, Equatable {
    let id: UUID
    let year: Int
    let month: Int?  // nil for yearly snapshot

    // Financial data
    let monthlyTakeHome: Double  // From UserIncome at the time
    let totalSpending: Double    // Sum of all transactions for this period
    let savings: Double          // takeHome - spending

    // Metadata
    let createdAt: Date
    let transactionCount: Int

    init(id: UUID = UUID(), year: Int, month: Int? = nil, monthlyTakeHome: Double, totalSpending: Double, savings: Double, createdAt: Date = Date(), transactionCount: Int) {
        self.id = id
        self.year = year
        self.month = month
        self.monthlyTakeHome = monthlyTakeHome
        self.totalSpending = totalSpending
        self.savings = savings
        self.createdAt = createdAt
        self.transactionCount = transactionCount
    }

    var periodType: PeriodType {
        month != nil ? .monthly : .yearly
    }

    var displayName: String {
        if let month = month {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            let components = DateComponents(year: year, month: month)
            if let date = Calendar.current.date(from: components) {
                return formatter.string(from: date)
            }
        }
        return "\(year)"
    }

    // Color status for calendar view
    func colorStatus(takeHome: Double) -> SnapshotColorStatus {
        let ratio = totalSpending / takeHome
        if ratio > 1.0 {
            return .red  // Overspent
        } else if ratio >= 0.9 {
            return .yellow  // Within 10% of budget (90-100%)
        } else {
            return .green  // Under budget (< 90%)
        }
    }
}

enum PeriodType {
    case monthly
    case yearly
}

enum SnapshotColorStatus {
    case green
    case yellow
    case red
}
