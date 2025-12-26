import Foundation
import Combine

class SnapshotService: ObservableObject {
    static let shared = SnapshotService()

    @Published var monthlySnapshots: [PeriodSnapshot] = []
    @Published var yearlySnapshots: [PeriodSnapshot] = []

    private let userDefaults = UserDefaults.standard
    private let monthlyKey = "monthly_snapshots"
    private let yearlyKey = "yearly_snapshots"

    private init() {
        loadSnapshots()
    }

    // MARK: - Snapshot Creation

    func createMonthlySnapshot(
        year: Int,
        month: Int,
        monthlyTakeHome: Double,
        transactions: [Transaction]
    ) {
        let calendar = Calendar.current

        // Filter transactions for this specific month
        let monthTransactions = transactions.filter { transaction in
            let txMonth = calendar.component(.month, from: transaction.date)
            let txYear = calendar.component(.year, from: transaction.date)
            return txMonth == month && txYear == year && transaction.isExpense
        }

        let totalSpending = monthTransactions.reduce(0.0) { $0 + $1.amount }
        let savings = monthlyTakeHome - totalSpending

        let snapshot = PeriodSnapshot(
            year: year,
            month: month,
            monthlyTakeHome: monthlyTakeHome,
            totalSpending: totalSpending,
            savings: savings,
            createdAt: Date(),
            transactionCount: monthTransactions.count
        )

        // Check if snapshot for this month already exists
        if let existingIndex = monthlySnapshots.firstIndex(where: {
            $0.year == year && $0.month == month
        }) {
            // Update existing snapshot
            monthlySnapshots[existingIndex] = snapshot
        } else {
            // Add new snapshot
            monthlySnapshots.append(snapshot)
        }

        saveSnapshots()
    }

    func createYearlySnapshot(
        year: Int,
        monthlyTakeHome: Double,
        transactions: [Transaction]
    ) {
        let annualTakeHome = monthlyTakeHome * 12.0

        let calendar = Calendar.current

        // Filter transactions for this specific year
        let yearTransactions = transactions.filter { transaction in
            let txYear = calendar.component(.year, from: transaction.date)
            return txYear == year && transaction.isExpense
        }

        let totalSpending = yearTransactions.reduce(0.0) { $0 + $1.amount }
        let savings = annualTakeHome - totalSpending

        let snapshot = PeriodSnapshot(
            year: year,
            month: nil,
            monthlyTakeHome: annualTakeHome,
            totalSpending: totalSpending,
            savings: savings,
            createdAt: Date(),
            transactionCount: yearTransactions.count
        )

        // Check if snapshot for this year already exists
        if let existingIndex = yearlySnapshots.firstIndex(where: { $0.year == year }) {
            // Update existing snapshot
            yearlySnapshots[existingIndex] = snapshot
        } else {
            // Add new snapshot
            yearlySnapshots.append(snapshot)
        }

        saveSnapshots()
    }

    // MARK: - Automatic Snapshot Updates

    func updateSnapshotsIfNeeded(
        monthlyTakeHome: Double,
        transactions: [Transaction]
    ) {
        let calendar = Calendar.current
        let now = Date()
        let currentYear = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now)

        // Create/update snapshot for current month
        createMonthlySnapshot(
            year: currentYear,
            month: currentMonth,
            monthlyTakeHome: monthlyTakeHome,
            transactions: transactions
        )

        // Create/update snapshot for current year
        createYearlySnapshot(
            year: currentYear,
            monthlyTakeHome: monthlyTakeHome,
            transactions: transactions
        )
    }

    // MARK: - Retrieval

    func getMonthlySnapshots(sortedByDate: Bool = true) -> [PeriodSnapshot] {
        if sortedByDate {
            return monthlySnapshots.sorted {
                ($0.year, $0.month ?? 0) > ($1.year, $1.month ?? 0)
            }
        }
        return monthlySnapshots
    }

    func getYearlySnapshots(sortedByDate: Bool = true) -> [PeriodSnapshot] {
        if sortedByDate {
            return yearlySnapshots.sorted { $0.year > $1.year }
        }
        return yearlySnapshots
    }

    // MARK: - Persistence

    private func saveSnapshots() {
        if let monthlyData = try? JSONEncoder().encode(monthlySnapshots) {
            userDefaults.set(monthlyData, forKey: monthlyKey)
        }

        if let yearlyData = try? JSONEncoder().encode(yearlySnapshots) {
            userDefaults.set(yearlyData, forKey: yearlyKey)
        }
    }

    private func loadSnapshots() {
        if let data = userDefaults.data(forKey: monthlyKey),
           let decoded = try? JSONDecoder().decode([PeriodSnapshot].self, from: data) {
            monthlySnapshots = decoded
        }

        if let data = userDefaults.data(forKey: yearlyKey),
           let decoded = try? JSONDecoder().decode([PeriodSnapshot].self, from: data) {
            yearlySnapshots = decoded
        }
    }
}
