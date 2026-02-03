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

        // Filter transactions for this specific month (all transactions, not just expenses)
        let monthTransactions = transactions.filter { transaction in
            let txMonth = calendar.component(.month, from: transaction.date)
            let txYear = calendar.component(.year, from: transaction.date)
            return txMonth == month && txYear == year
        }

        // Calculate spending using allocation-based method (same as MonthEndBalancingService)
        // This ensures the snapshot savings matches what was shown during month-end balancing
        let (totalCategorySpending, savings) = await calculateAllocationBasedSpending(
            year: year,
            month: month,
            monthlyTakeHome: monthlyTakeHome,
            transactions: monthTransactions,
            budgetPlanId: budgetPlanId
        )

        // Round all monetary values to 2 decimal places for consistency
        let roundedTakeHome = (monthlyTakeHome * 100).rounded() / 100
        let roundedSpending = (totalCategorySpending * 100).rounded() / 100

        let snapshot = PeriodSnapshot(
            year: year,
            month: month,
            monthlyTakeHome: roundedTakeHome,
            totalSpending: roundedSpending,
            savings: savings,
            budgetPlanId: budgetPlanId,
            createdAt: Date(),
            expenseTransactionCount: monthTransactions.filter { $0.isExpense }.count,
            incomeTransactionCount: monthTransactions.filter { !$0.isExpense }.count
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
            _ = try await BackendService.shared.createSnapshot(snapshot)
        } catch {
            print("❌ [SnapshotService] Failed to save monthly snapshot: \(error)")
            // Continue anyway - local storage succeeded
        }
    }

    /// Calculate spending based on allocations to budget categories (not raw transaction amounts)
    /// This matches the calculation used in MonthEndBalancingService.calculateMonthStats()
    private func calculateAllocationBasedSpending(
        year: Int,
        month: Int,
        monthlyTakeHome: Double,
        transactions: [Transaction],
        budgetPlanId: String
    ) async -> (totalSpending: Double, savings: Double) {
        let calendar = Calendar.current
        let budgetService = BudgetService.shared
        let allocationService = AllocationService.shared

        // Get the target date (last day of month) for fetching historical categories
        var components = DateComponents()
        components.year = year
        components.month = month + 1
        components.day = 0
        let targetDate = calendar.date(from: components) ?? Date()

        // Get categories that were active during this historical month
        let categories = await budgetService.getActiveCategoriesForDate(targetDate)

        var totalBudget = 0.0
        var totalActualSpending = 0.0

        for category in categories {
            // Calculate budget amount for this category
            let budgetAmount = category.dollarAmount(monthlyTakeHome: monthlyTakeHome)
            totalBudget += budgetAmount

            // Calculate actual spending for this category in this month
            let categoryAllocations = allocationService.allocations.filter { allocation in
                guard allocation.destinationType == .category else { return false }
                guard allocation.destinationId == category.id else { return false }

                // Find the transaction for this allocation
                guard
                    let transaction = transactions.first(where: {
                        $0.id == allocation.transactionId
                    })
                else {
                    return false
                }

                let txYear = calendar.component(.year, from: transaction.date)
                let txMonth = calendar.component(.month, from: transaction.date)

                return txYear == year && txMonth == month
            }

            // Sum up spending (expense allocations add, income allocations subtract as reimbursements)
            for allocation in categoryAllocations {
                if let transaction = transactions.first(where: { $0.id == allocation.transactionId }
                ) {
                    if transaction.isExpense {
                        totalActualSpending += allocation.amount
                    } else {
                        totalActualSpending -= allocation.amount  // Reimbursement reduces spending
                    }
                }
            }
        }

        // Round all values to 2 decimal places for consistency
        let roundedSpending = (totalActualSpending * 100).rounded() / 100
        let roundedBudget = (totalBudget * 100).rounded() / 100

        // Savings = total budget - actual spending against categories
        // Positive = under budget (saved money), Negative = over budget
        let savings = ((roundedBudget - roundedSpending) * 100).rounded() / 100

        print("📊 [SnapshotService] Allocation-based calculation for \(month)/\(year):")
        print("   Total budget: $\(String(format: "%.2f", roundedBudget))")
        print("   Category spending: $\(String(format: "%.2f", roundedSpending))")
        print("   Savings (budget - spending): $\(String(format: "%.2f", savings))")

        return (roundedSpending, savings)
    }

    func createYearlySnapshot(
        year: Int,
        monthlyTakeHome: Double,
        transactions: [Transaction],
        budgetPlanId: String
    ) async {
        let calendar = Calendar.current

        // Filter transactions for this specific year (all transactions, not just expenses)
        let yearTransactions = transactions.filter { transaction in
            let txYear = calendar.component(.year, from: transaction.date)
            return txYear == year
        }

        // Calculate spending using allocation-based method for each month, then sum
        var totalYearSpending = 0.0
        var totalYearSavings = 0.0

        for month in 1...12 {
            let monthTransactions = yearTransactions.filter { transaction in
                let txMonth = calendar.component(.month, from: transaction.date)
                return txMonth == month
            }

            if !monthTransactions.isEmpty {
                let (spending, savings) = await calculateAllocationBasedSpending(
                    year: year,
                    month: month,
                    monthlyTakeHome: monthlyTakeHome,
                    transactions: monthTransactions,
                    budgetPlanId: budgetPlanId
                )
                totalYearSpending += spending
                totalYearSavings += savings
            }
        }

        // Round all monetary values to 2 decimal places for consistency
        let roundedAnnualTakeHome = ((monthlyTakeHome * 12.0) * 100).rounded() / 100
        let roundedYearSpending = (totalYearSpending * 100).rounded() / 100
        let roundedYearSavings = (totalYearSavings * 100).rounded() / 100

        let snapshot = PeriodSnapshot(
            year: year,
            month: nil,
            monthlyTakeHome: roundedAnnualTakeHome,
            totalSpending: roundedYearSpending,
            savings: roundedYearSavings,
            budgetPlanId: budgetPlanId,
            createdAt: Date(),
            expenseTransactionCount: yearTransactions.filter { $0.isExpense }.count,
            incomeTransactionCount: yearTransactions.filter { !$0.isExpense }.count
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
            _ = try await BackendService.shared.createSnapshot(snapshot)
        } catch {
            print("❌ [SnapshotService] Failed to save yearly snapshot: \(error)")
            // Continue anyway - local storage succeeded
        }
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
