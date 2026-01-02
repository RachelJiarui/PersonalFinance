import Combine
import Foundation

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var budgetCategories: [BudgetCategory] = []
    @Published var budgetPlan: BudgetPlan?
    @Published var categorySpending: [String: Double] = [:]
    @Published var isLoading: Bool = false
    @Published var transactions: [Transaction] = []
    @Published var errorMessage: String?

    private let storageService = TransactionStorageService.shared
    private let budgetService = BudgetService.shared
    private let snapshotService = SnapshotService.shared
    private let backendService = BackendService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        setupSubscriptions()
        loadLocalData()
    }

    private func setupSubscriptions() {
        // Storage service transactions
        storageService.$transactions
            .assign(to: &$transactions)

        // Budget service
        budgetService.$budgetCategories
            .assign(to: &$budgetCategories)

        budgetService.$budgetPlan
            .assign(to: &$budgetPlan)

        budgetService.$categorySpending
            .assign(to: &$categorySpending)
    }

    func loadLocalData() {
        // Data is automatically loaded via storageService subscriptions
        // Update category spending with loaded transactions
        budgetService.updateCategorySpending(with: storageService.transactions)
    }

    func refreshData() async {
        print("\n🔄 [DashboardViewModel] refreshData() called")

        do {
            try Task.checkCancellation()

            // Fetch data from backend if registered
            await fetchBackendData()

            try Task.checkCancellation()

            // Update category spending with current transactions
            budgetService.updateCategorySpending(with: storageService.transactions)

            // Update snapshots for historical tracking
            if let monthlyTakeHome = budgetService.budgetPlan?.monthlyTakeHome {
                await snapshotService.updateSnapshotsIfNeeded(
                    monthlyTakeHome: monthlyTakeHome,
                    transactions: storageService.transactions
                )
            }

            print(
                "🔄 [DashboardViewModel] refreshData() complete - \(transactions.count) transactions\n"
            )
        } catch is CancellationError {
            print("⏹️ [DashboardViewModel] Refresh cancelled")
        } catch {
            print("❌ [DashboardViewModel] Refresh error: \(error)")
        }
    }

    func fetchBackendData() async {
        print("☁️ [DashboardViewModel] Fetching data from backend...")

        do {
            try Task.checkCancellation()

            // Fetch transaction data
            print("📥 [DashboardViewModel] Fetching transactions from backend...")
            let backendTransactions = try await backendService.fetchTransactions()

            // Use Firestore as source of truth - replace local data entirely
            await MainActor.run {
                storageService.transactions = backendTransactions
                storageService.persistTransactions()
            }
            print(
                "✅ [DashboardViewModel] Synced \(backendTransactions.count) transactions from backend (source of truth)"
            )

            try Task.checkCancellation()

            // Fetch historical data (snapshots)
            print("📥 [DashboardViewModel] Fetching historical data from backend...")
            let monthlySnapshots = try await backendService.fetchSnapshots(periodType: "monthly")
            let yearlySnapshots = try await backendService.fetchSnapshots(periodType: "yearly")

            // Use Firestore as source of truth - replace local data entirely
            await MainActor.run {
                snapshotService.monthlySnapshots = monthlySnapshots
                snapshotService.yearlySnapshots = yearlySnapshots
                snapshotService.saveSnapshots()
            }
            print(
                "✅ [DashboardViewModel] Synced \(monthlySnapshots.count) monthly and \(yearlySnapshots.count) yearly snapshots from backend (source of truth)"
            )

            try Task.checkCancellation()

            // Fetch budget categories
            print("📥 [DashboardViewModel] Fetching budget categories from backend...")
            let backendCategories = try await backendService.fetchBudgetCategories()

            // Use Firestore as source of truth - replace local data entirely
            await MainActor.run {
                budgetService.budgetCategories = backendCategories
                budgetService.saveBudgetCategories()
            }
            print(
                "✅ [DashboardViewModel] Synced \(backendCategories.count) budget categories from backend (source of truth)"
            )

            try Task.checkCancellation()

            // Fetch active budget plan
            print("📥 [DashboardViewModel] Fetching budget plan from backend...")
            if let plan = try await backendService.fetchActiveBudgetPlan() {
                budgetService.budgetPlan = plan
                budgetService.updateCategorySpending(with: storageService.transactions)
                print("✅ [DashboardViewModel] Fetched budget plan from backend")
            } else {
                print("ℹ️ [DashboardViewModel] No budget plan found on backend")
            }

            print("☁️ [DashboardViewModel] Backend data fetch complete")

        } catch is CancellationError {
            print("⏹️ [DashboardViewModel] Backend fetch cancelled")
        } catch {
            print(
                "⚠️ [DashboardViewModel] Failed to fetch from backend: \(error.localizedDescription)"
            )
            // Don't set error message - this is a background operation
        }
    }

    func createManualEntry(transaction: Transaction) {
        // Save transaction
        storageService.saveTransaction(transaction)

        // Update category spending
        budgetService.updateCategorySpending(with: storageService.transactions)

        print("✅ [DashboardViewModel] Created manual entry: \(transaction.title)")
    }

    func disconnect() {
        // Disconnect method kept for compatibility
    }

    func cancelAllTasks() {
        print("🛑 [DashboardViewModel] Cancelling all active tasks")
        // Tasks are managed by the views that call the async methods
        // This method is here for completeness but actual cancellation
        // happens when the Task objects in the views are cancelled
    }

    // MARK: - Synchronous Updates (for instant UI refresh)

    func updateBudgetsSync() {
        print("⚡ [DashboardViewModel] Synchronous budget update with local data")

        // Update category spending with current transactions (synchronous, instant)
        budgetService.updateCategorySpending(with: storageService.transactions)

        // Update snapshots for historical tracking (async in background)
        if let monthlyTakeHome = budgetService.budgetPlan?.monthlyTakeHome {
            Task {
                await snapshotService.updateSnapshotsIfNeeded(
                    monthlyTakeHome: monthlyTakeHome,
                    transactions: storageService.transactions
                )
            }
        }

        print("✅ [DashboardViewModel] Synchronous update complete")
    }

    // MARK: - Helper Methods

    func getCategoryName(for categoryId: String) -> String {
        return budgetService.getCategoryById(categoryId)?.name ?? "Unknown"
    }

    func getCategoryIcon(for categoryId: String) -> String {
        return budgetService.getCategoryById(categoryId)?.icon ?? "questionmark.circle"
    }

    func getCategoryBudget(for categoryId: String) -> Double {
        return budgetService.getCategoryBudgetAmount(categoryId: categoryId) ?? 0.0
    }

    func getCategorySpending(for categoryId: String) -> Double {
        return budgetService.getSpending(forCategoryId: categoryId)
    }

    func getCategorySpendingRatio(for categoryId: String) -> Double {
        return budgetService.getCategorySpendingRatio(categoryId: categoryId) ?? 0.0
    }
}
