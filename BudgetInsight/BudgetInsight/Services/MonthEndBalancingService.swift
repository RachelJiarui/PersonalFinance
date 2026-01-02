import Foundation
import SwiftUI

enum BalancingError: LocalizedError {
    case defaultFundNotFound
    case defaultDebtNotFound

    var errorDescription: String? {
        switch self {
        case .defaultFundNotFound:
            return "Default fund 'General Savings' not found. Please restart the app."
        case .defaultDebtNotFound:
            return "Default debt 'General Debt' not found. Please restart the app."
        }
    }
}

class MonthEndBalancingService: ObservableObject {
    static let shared = MonthEndBalancingService()

    @Published var needsBalancing: Bool = false
    @Published var unbalancedMonths: [(year: Int, month: Int)] = []

    private let userDefaults = UserDefaults.standard
    private let calendar = Calendar.current

    private init() {}

    // MARK: - Detection

    func checkForUnbalancedMonths() async {
        let now = Date()
        let currentYear = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now)

        // Get all transactions
        let transactions = TransactionStorageService.shared.transactions
        guard !transactions.isEmpty else {
            await MainActor.run {
                self.needsBalancing = false
                self.unbalancedMonths = []
            }
            return
        }

        // Find earliest transaction date
        let earliestDate = transactions.map { $0.date }.min() ?? now
        let firstYear = calendar.component(.year, from: earliestDate)
        let firstMonth = calendar.component(.month, from: earliestDate)

        // Iterate through all months from first to previous month (not current)
        var checkDate = calendar.date(from: DateComponents(year: firstYear, month: firstMonth))!
        let previousMonthDate = calendar.date(byAdding: .month, value: -1, to: now)!

        var unbalancedList: [(Int, Int)] = []

        while checkDate <= previousMonthDate {
            let year = calendar.component(.year, from: checkDate)
            let month = calendar.component(.month, from: checkDate)

            // Skip if this is the current month
            if year == currentYear && month == currentMonth {
                checkDate = calendar.date(byAdding: .month, value: 1, to: checkDate)!
                continue
            }

            if !isMonthBalanced(year: year, month: month) {
                unbalancedList.append((year, month))
            }

            // Move to next month
            checkDate = calendar.date(byAdding: .month, value: 1, to: checkDate)!
        }

        let sortedUnbalanced = unbalancedList.sorted {
            ($0.0, $0.1) < ($1.0, $1.1)
        }

        await MainActor.run {
            self.unbalancedMonths = sortedUnbalanced
            self.needsBalancing = !sortedUnbalanced.isEmpty
        }

        print("📊 [BalancingService] Found \(unbalancedList.count) unbalanced months")
    }

    func isMonthBalanced(year: Int, month: Int) -> Bool {
        let key = "balanced_\(year)_\(month)"
        return userDefaults.bool(forKey: key)
    }

    // MARK: - Testing/Debug Methods

    /// Reset balancing status for a specific month (for testing)
    func resetMonthBalancing(year: Int, month: Int) {
        let key = "balanced_\(year)_\(month)"
        userDefaults.removeObject(forKey: key)
        print("🔄 [BalancingService] Reset balancing for \(monthName(month)) \(year)")

        // Re-check for unbalanced months
        Task {
            await checkForUnbalancedMonths()
        }
    }

    /// Reset ALL balancing history (for testing)
    func resetAllBalancing() {
        let calendar = Calendar.current
        let now = Date()
        let currentYear = calendar.component(.year, from: now)

        // Clear all balanced flags for the past few years
        for year in (currentYear - 3)...currentYear {
            for month in 1...12 {
                let key = "balanced_\(year)_\(month)"
                userDefaults.removeObject(forKey: key)
            }
        }

        print("🔄 [BalancingService] Reset ALL balancing history")

        // Re-check for unbalanced months
        Task {
            await checkForUnbalancedMonths()
        }
    }

    func markMonthBalanced(year: Int, month: Int, transactionIds: [String]) {
        let key = "balanced_\(year)_\(month)"
        userDefaults.set(true, forKey: key)

        print("✅ [BalancingService] Marked \(monthName(month)) \(year) as balanced")

        // Create snapshot for this month
        let lastDayOfMonth = getLastDayOfMonth(year: year, month: month)
        if let monthlyTakeHome = BudgetService.shared.getMonthlyTakeHomeForDate(lastDayOfMonth),
            let budgetPlan = BudgetService.shared.budgetPlan
        {
            let allTransactions = TransactionStorageService.shared.transactions
            SnapshotService.shared.createMonthlySnapshot(
                year: year,
                month: month,
                monthlyTakeHome: monthlyTakeHome,
                transactions: allTransactions,
                budgetPlanId: budgetPlan.id
            )
            print("📊 [BalancingService] Created snapshot for \(monthName(month)) \(year)")
        }

        // Also save to Firestore
        Task {
            let balance = MonthEndBalance(
                year: year,
                month: month,
                isBalanced: true,
                balancedAt: Date(),
                balancingTransactionIds: transactionIds,
                netSavings: nil,
                categoriesProcessed: nil
            )

            do {
                _ = try await BackendService.shared.createMonthEndBalance(balance)
                print("✅ [BalancingService] Saved balance record to Firestore")
            } catch {
                print("❌ [BalancingService] Failed to save to Firestore: \(error)")
            }
        }

        // Re-check for more unbalanced months
        Task {
            await checkForUnbalancedMonths()
        }
    }

    // MARK: - Statistics Calculation

    func calculateMonthStats(year: Int, month: Int) -> MonthWrappedStats? {
        // Get transactions for this month
        let monthTransactions = getTransactionsForMonth(year: year, month: month)

        guard !monthTransactions.isEmpty else {
            print("⚠️ [BalancingService] No transactions for \(monthName(month)) \(year)")
            return nil
        }

        // Get monthly take-home (use budget plan active at end of month)
        let lastDayOfMonth = getLastDayOfMonth(year: year, month: month)
        guard let monthlyTakeHome = BudgetService.shared.getMonthlyTakeHomeForDate(lastDayOfMonth)
        else {
            print("❌ [BalancingService] No monthly take-home found for \(monthName(month)) \(year)")
            return nil
        }

        // Calculate totals
        let totalIncome =
            monthTransactions
            .filter { !$0.isExpense }
            .reduce(0.0) { $0 + $1.amount }

        let totalSpending =
            monthTransactions
            .filter { $0.isExpense }
            .reduce(0.0) { $0 + $1.amount }

        let netSavings = monthlyTakeHome + (totalIncome - totalSpending)

        // Calculate category balances
        let categoryBalances = calculateCategoryBalances(
            year: year,
            month: month,
            transactions: monthTransactions,
            monthlyTakeHome: monthlyTakeHome
        )

        return MonthWrappedStats(
            year: year,
            month: month,
            monthlyTakeHome: monthlyTakeHome,
            categoryBalances: categoryBalances,
            totalIncome: totalIncome,
            totalSpending: totalSpending,
            netSavings: netSavings,
            transactionCount: monthTransactions.count
        )
    }

    private func calculateCategoryBalances(
        year: Int,
        month: Int,
        transactions: [Transaction],
        monthlyTakeHome: Double
    ) -> [CategoryBalance] {
        let budgetService = BudgetService.shared
        let allocationService = AllocationService.shared

        // Get active categories (from the budget plan active at month-end)
        let categories = budgetService.getActiveCategories()

        return categories.compactMap { category in
            // Calculate budget amount
            let budgetAmount = category.dollarAmount(monthlyTakeHome: monthlyTakeHome)

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

            // Sum up spending (expense allocations add, income allocations subtract)
            var actualSpending = 0.0
            for allocation in categoryAllocations {
                if let transaction = transactions.first(where: { $0.id == allocation.transactionId }
                ) {
                    if transaction.isExpense {
                        actualSpending += allocation.amount
                    } else {
                        actualSpending -= allocation.amount  // Reimbursement
                    }
                }
            }

            return CategoryBalance(
                category: category,
                budgetAmount: budgetAmount,
                actualSpending: actualSpending,
                allocatedTo: nil
            )
        }.filter { $0.hasBalance }  // Only include categories with savings or deficits
    }

    // MARK: - Auto-Allocation to Default Buckets

    func autoAllocateToDefaultBuckets(for stats: MonthWrappedStats) async throws -> [String] {
        let lastDayOfMonth = getLastDayOfMonth(year: stats.year, month: stats.month)
        var transactionIds: [String] = []

        print(
            "💰 [BalancingService] Auto-allocating for \(monthName(stats.month)) \(stats.year)"
        )

        // Check if there are net savings or deficit
        if abs(stats.netSavings) < 0.01 {
            // Perfectly balanced - no transaction needed
            print("✅ [BalancingService] Month is perfectly balanced, no allocation needed")
            return []
        }

        if stats.netSavings > 0 {
            // Net savings - allocate to default fund
            guard let defaultFund = FundService.shared.getDefaultFund() else {
                throw BalancingError.defaultFundNotFound
            }

            let transaction = Transaction(
                id: "",
                amount: stats.netSavings,
                date: lastDayOfMonth,
                title: "Month-End: Net Savings → \(defaultFund.name)",
                isExpense: false,  // Income to the fund
                timestamp: Date()
            )

            // Save transaction
            await MainActor.run {
                TransactionStorageService.shared.saveTransaction(transaction)
            }
            try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds
            let tempId = transaction.id.isEmpty ? UUID().uuidString : transaction.id

            // Create allocation to default fund
            await MainActor.run {
                _ = AllocationService.shared.createAllocation(
                    transactionId: tempId,
                    destinationType: .fund,
                    destinationId: defaultFund.id,
                    amount: stats.netSavings,
                    isExpense: false
                )
            }

            transactionIds.append(tempId)
            print(
                "✅ [BalancingService] Allocated $\(String(format: "%.2f", stats.netSavings)) to \(defaultFund.name)"
            )

        } else {
            // Net deficit - allocate to default debt
            guard let defaultDebt = DebtService.shared.getDefaultDebt() else {
                throw BalancingError.defaultDebtNotFound
            }

            let deficitAmount = abs(stats.netSavings)

            let transaction = Transaction(
                id: "",
                amount: deficitAmount,
                date: lastDayOfMonth,
                title: "Month-End: Net Deficit → \(defaultDebt.name)",
                isExpense: true,  // Expense - adding to debt
                timestamp: Date()
            )

            // Save transaction
            await MainActor.run {
                TransactionStorageService.shared.saveTransaction(transaction)
            }
            try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds
            let tempId = transaction.id.isEmpty ? UUID().uuidString : transaction.id

            // Create allocation to default debt
            await MainActor.run {
                _ = AllocationService.shared.createAllocation(
                    transactionId: tempId,
                    destinationType: .debt,
                    destinationId: defaultDebt.id,
                    amount: deficitAmount,
                    isExpense: true
                )
            }

            transactionIds.append(tempId)
            print(
                "✅ [BalancingService] Allocated $\(String(format: "%.2f", deficitAmount)) to \(defaultDebt.name)"
            )
        }

        return transactionIds
    }

    // MARK: - Transaction Creation (Legacy - kept for reference)

    func createBalancingTransactions(
        for stats: MonthWrappedStats,
        with allocations: [CategoryBalance]
    ) async throws -> [String] {
        let lastDayOfMonth = getLastDayOfMonth(year: stats.year, month: stats.month)
        var transactionIds: [String] = []

        print(
            "💰 [BalancingService] Creating balancing transactions for \(monthName(stats.month)) \(stats.year)"
        )

        // Process all allocations
        for categoryBalance in allocations {
            guard let destination = categoryBalance.allocatedTo else { continue }

            let isSurplus = categoryBalance.surplus > 0
            let amount = isSurplus ? categoryBalance.surplus : categoryBalance.deficit

            // Create transaction
            let title = generateTransactionTitle(
                categoryName: categoryBalance.category.name,
                destination: destination,
                isSurplus: isSurplus
            )

            let transaction = Transaction(
                id: "",
                amount: amount,
                date: lastDayOfMonth,
                title: title,
                isExpense: !isSurplus,  // Surplus = income to destination, Deficit = expense from source
                timestamp: Date()
            )

            // Save transaction
            TransactionStorageService.shared.saveTransaction(transaction)

            // Wait a moment for transaction ID to be set (optimistic update)
            try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds

            let tempId = transaction.id.isEmpty ? UUID().uuidString : transaction.id

            // Create allocation based on destination type
            switch destination.type {
            case .existingFund(let fundId):
                AllocationService.shared.createAllocation(
                    transactionId: tempId,
                    destinationType: .fund,
                    destinationId: fundId,
                    amount: amount,
                    isExpense: !isSurplus
                )
                print("✅ Created allocation: \(title)")

            case .newFund(let name, let icon, let description):
                let fund = FundService.shared.createFund(
                    name: name,
                    icon: icon,
                    description: description,
                    balance: 0.0
                )
                AllocationService.shared.createAllocation(
                    transactionId: tempId,
                    destinationType: .fund,
                    destinationId: fund.id,
                    amount: amount,
                    isExpense: !isSurplus
                )
                print("✅ Created new fund '\(name)' and allocation: \(title)")

            case .existingDebt(let debtId):
                AllocationService.shared.createAllocation(
                    transactionId: tempId,
                    destinationType: .debt,
                    destinationId: debtId,
                    amount: amount,
                    isExpense: !isSurplus
                )
                print("✅ Created allocation: \(title)")

            case .newDebt(let name, let icon, let description, let goal):
                let debt = DebtService.shared.createDebt(
                    name: name,
                    icon: icon,
                    description: description,
                    balance: amount,
                    goal: goal
                )
                AllocationService.shared.createAllocation(
                    transactionId: tempId,
                    destinationType: .debt,
                    destinationId: debt.id,
                    amount: amount,
                    isExpense: !isSurplus
                )
                print("✅ Created new debt '\(name)' and allocation: \(title)")
            }

            transactionIds.append(tempId)
        }

        print("✅ [BalancingService] Created \(transactionIds.count) balancing transactions")

        return transactionIds
    }

    private func generateTransactionTitle(
        categoryName: String,
        destination: BalancingDestination,
        isSurplus: Bool
    ) -> String {
        let destinationName: String

        switch destination.type {
        case .existingFund(let fundId):
            destinationName = FundService.shared.getFundById(fundId)?.name ?? "Fund"
        case .newFund(let name, _, _):
            destinationName = name
        case .existingDebt(let debtId):
            destinationName = DebtService.shared.getDebtById(debtId)?.name ?? "Debt"
        case .newDebt(let name, _, _, _):
            destinationName = name
        }

        if isSurplus {
            if case .existingDebt(_) = destination.type, isSurplus {
                return "Month-End: \(categoryName) Savings → Pay \(destinationName)"
            } else {
                return "Month-End: \(categoryName) Savings → \(destinationName)"
            }
        } else {
            if case .existingFund(_) = destination.type {
                return "Month-End: \(destinationName) → Cover \(categoryName) Deficit"
            } else {
                return "Month-End: \(categoryName) Deficit → \(destinationName)"
            }
        }
    }

    // MARK: - Validation

    func validateAllocations(_ stats: MonthWrappedStats, allocations: [CategoryBalance]) -> (
        isValid: Bool, errors: [String]
    ) {
        var errors: [String] = []

        // Check 1: All surplus categories fully allocated
        for category in stats.categoriesWithSavings {
            if let matchingCategory = allocations.first(where: {
                $0.category.id == category.category.id
            }) {
                guard matchingCategory.allocatedTo != nil else {
                    errors.append(
                        "\(category.category.name) has $\(String(format: "%.2f", category.surplus)) unallocated savings"
                    )
                    continue
                }

                if let destination = matchingCategory.allocatedTo {
                    if abs(destination.amount - category.surplus) > 0.01 {
                        errors.append("\(category.category.name) allocation mismatch")
                    }
                }
            } else {
                errors.append("\(category.category.name) has unallocated savings")
            }
        }

        // Check 2: All deficit categories fully covered
        for category in stats.categoriesWithDeficits {
            if let matchingCategory = allocations.first(where: {
                $0.category.id == category.category.id
            }) {
                guard matchingCategory.allocatedTo != nil else {
                    errors.append(
                        "\(category.category.name) has $\(String(format: "%.2f", category.deficit)) uncovered deficit"
                    )
                    continue
                }

                if let destination = matchingCategory.allocatedTo {
                    if abs(destination.amount - category.deficit) > 0.01 {
                        errors.append("\(category.category.name) coverage mismatch")
                    }
                }
            } else {
                errors.append("\(category.category.name) deficit not covered")
            }
        }

        // Check 3: Validate fund balances won't go negative
        for category in stats.categoriesWithDeficits {
            if let matchingCategory = allocations.first(where: {
                $0.category.id == category.category.id
            }),
                let destination = matchingCategory.allocatedTo,
                case .existingFund(let fundId) = destination.type
            {
                if let fund = FundService.shared.getFundById(fundId) {
                    if fund.balance < category.deficit {
                        errors.append(
                            "Insufficient funds in \(fund.name) (needs $\(String(format: "%.2f", category.deficit)), has $\(String(format: "%.2f", fund.balance)))"
                        )
                    }
                }
            }
        }

        return (errors.isEmpty, errors)
    }

    // MARK: - Helper Methods

    private func getTransactionsForMonth(year: Int, month: Int) -> [Transaction] {
        return TransactionStorageService.shared.transactions.filter { transaction in
            let txYear = calendar.component(.year, from: transaction.date)
            let txMonth = calendar.component(.month, from: transaction.date)
            return txYear == year && txMonth == month
        }
    }

    private func getLastDayOfMonth(year: Int, month: Int) -> Date {
        // Create first day of next month, then subtract 1 second
        var components = DateComponents()
        components.year = year
        components.month = month + 1
        components.day = 0  // Last day of previous month
        components.hour = 23
        components.minute = 59
        components.second = 59

        return calendar.date(from: components) ?? Date()
    }

    private func monthName(_ month: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        let components = DateComponents(year: 2024, month: month)
        if let date = calendar.date(from: components) {
            return formatter.string(from: date)
        }
        return "Month \(month)"
    }
}
