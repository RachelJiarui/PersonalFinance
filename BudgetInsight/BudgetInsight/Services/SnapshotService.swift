import Combine
import Foundation

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
        transactions: [Transaction],
        budgetPlanId: String
    ) async {
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
            budgetPlanId: budgetPlanId,
            createdAt: Date(),
            transactionCount: monthTransactions.count
        )

        // Save to local storage first
        await MainActor.run {
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

        // Save to Firebase
        do {
            let firebaseId = try await BackendService.shared.createSnapshot(snapshot)
        } catch {
            print("❌ [SnapshotService] Failed to save monthly snapshot: \(error)")
            // Continue anyway - local storage succeeded
        }
    }

    func createYearlySnapshot(
        year: Int,
        monthlyTakeHome: Double,
        transactions: [Transaction],
        budgetPlanId: String
    ) async {
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
            budgetPlanId: budgetPlanId,
            createdAt: Date(),
            transactionCount: yearTransactions.count
        )

        // Save to local storage first
        await MainActor.run {
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

        // Save to Firebase
        do {
            let firebaseId = try await BackendService.shared.createSnapshot(snapshot)
        } catch {
            print("❌ [SnapshotService] Failed to save yearly snapshot: \(error)")
            // Continue anyway - local storage succeeded
        }
    }

    // MARK: - Automatic Snapshot Updates

    func updateSnapshotsIfNeeded(
        monthlyTakeHome: Double,
        transactions: [Transaction]
    ) async {
        let calendar = Calendar.current
        let now = Date()
        let currentYear = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now)

        // Get the current active budget plan ID
        guard let currentPlan = BudgetService.shared.budgetPlan else {
            return
        }

        // Create/update snapshot for current month
        await createMonthlySnapshot(
            year: currentYear,
            month: currentMonth,
            monthlyTakeHome: monthlyTakeHome,
            transactions: transactions,
            budgetPlanId: currentPlan.id
        )

        // Create/update snapshot for current year
        await createYearlySnapshot(
            year: currentYear,
            monthlyTakeHome: monthlyTakeHome,
            transactions: transactions,
            budgetPlanId: currentPlan.id
        )
    }

    // MARK: - Manual Snapshot Management

    func addSnapshot(_ snapshot: PeriodSnapshot) {
        if let month = snapshot.month {
            // Monthly snapshot
            if let existingIndex = monthlySnapshots.firstIndex(where: {
                $0.year == snapshot.year && $0.month == month
            }) {
                // Update existing snapshot only if the new one is more recent
                if snapshot.createdAt > monthlySnapshots[existingIndex].createdAt {
                    monthlySnapshots[existingIndex] = snapshot
                }
            } else {
                // Add new snapshot
                monthlySnapshots.append(snapshot)
            }
        } else {
            // Yearly snapshot
            if let existingIndex = yearlySnapshots.firstIndex(where: { $0.year == snapshot.year }) {
                // Update existing snapshot only if the new one is more recent
                if snapshot.createdAt > yearlySnapshots[existingIndex].createdAt {
                    yearlySnapshots[existingIndex] = snapshot
                }
            } else {
                // Add new snapshot
                yearlySnapshots.append(snapshot)
            }
        }

        saveSnapshots()
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

    /// Fetch a snapshot with its associated budget plan for historical viewing
    func getSnapshotWithBudgetPlan(year: Int, month: Int) async -> (PeriodSnapshot, BudgetPlan)? {
        guard let snapshot = monthlySnapshots.first(where: { $0.year == year && $0.month == month })
        else {
            return nil
        }

        // Fetch the budget plan that was active for this snapshot
        do {
            if let budgetPlan = try await BackendService.shared.fetchBudgetPlan(
                planId: snapshot.budgetPlanId)
            {
                return (snapshot, budgetPlan)
            }
        } catch {
            print("❌ [SnapshotService] Error fetching budget plan for snapshot: \(error)")
        }

        return nil
    }

    // MARK: - Persistence

    func saveSnapshots() {
        if let monthlyData = try? JSONEncoder().encode(monthlySnapshots) {
            userDefaults.set(monthlyData, forKey: monthlyKey)
        }

        if let yearlyData = try? JSONEncoder().encode(yearlySnapshots) {
            userDefaults.set(yearlyData, forKey: yearlyKey)
        }
    }

    private func loadSnapshots() {
        if let data = userDefaults.data(forKey: monthlyKey),
            let decoded = try? JSONDecoder().decode([PeriodSnapshot].self, from: data)
        {
            monthlySnapshots = decoded
        }

        if let data = userDefaults.data(forKey: yearlyKey),
            let decoded = try? JSONDecoder().decode([PeriodSnapshot].self, from: data)
        {
            yearlySnapshots = decoded
        }
    }
}
