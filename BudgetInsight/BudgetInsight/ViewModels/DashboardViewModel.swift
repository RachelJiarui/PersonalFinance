import Combine
import Foundation

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var budgetCategories: [BudgetCategory] = []
    @Published var budgetPlan: BudgetPlan?
    @Published var userIncome: UserIncome?
    @Published var categorySpending: [String: Double] = [:]
    @Published var isLoading: Bool = false
    @Published var isEmailConnected: Bool = false
    @Published var transactions: [Transaction] = []
    @Published var transactionAlerts: [TransactionAlert] = []
    @Published var unlinkedAlertsCount: Int = 0
    @Published var errorMessage: String?

    private let emailService = EmailService.shared
    private let storageService = TransactionStorageService.shared
    private let budgetService = BudgetService.shared
    private let snapshotService = SnapshotService.shared
    private let backendService = BackendService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        setupSubscriptions()
        checkEmailConnection()
        loadLocalData()
    }

    private func setupSubscriptions() {
        // Email connection status
        emailService.$isAuthenticated
            .assign(to: &$isEmailConnected)

        // Storage service transactions
        storageService.$transactions
            .assign(to: &$transactions)

        // Storage service alerts
        storageService.$transactionAlerts
            .assign(to: &$transactionAlerts)

        // Budget service
        budgetService.$budgetCategories
            .assign(to: &$budgetCategories)

        budgetService.$budgetPlan
            .assign(to: &$budgetPlan)

        budgetService.$userIncome
            .assign(to: &$userIncome)

        budgetService.$categorySpending
            .assign(to: &$categorySpending)

        // Update unlinked alerts count whenever alerts change
        storageService.$transactionAlerts
            .map { alerts in
                alerts.filter { !$0.isResolved }.count
            }
            .assign(to: &$unlinkedAlertsCount)
    }

    func checkEmailConnection() {
        isEmailConnected = emailService.isAuthenticated
    }

    func loadLocalData() {
        // Data is automatically loaded via storageService subscriptions
        // Update category spending with loaded transactions
        budgetService.updateCategorySpending(with: storageService.transactions)
    }

    func refreshEmailAlerts() async {
        print("📧 [DashboardViewModel] Refreshing email alerts...")
        // No loading spinner - background refresh only

        do {
            // Check for cancellation before expensive operation
            try Task.checkCancellation()

            let newAlerts = try await emailService.pollForNewAlerts()

            // Check cancellation before updating state
            try Task.checkCancellation()

            // Save new alerts that don't already exist
            for alert in newAlerts {
                try Task.checkCancellation()  // Check in loop

                if !storageService.transactionAlerts.contains(where: { $0.emailId == alert.emailId }
                ) {
                    storageService.saveTransactionAlert(alert)
                }
            }

            print("✅ [DashboardViewModel] Found \(newAlerts.count) new alerts")
        } catch is CancellationError {
            print("⏹️ [DashboardViewModel] Email refresh cancelled")
        } catch {
            print("❌ [DashboardViewModel] Failed to refresh alerts: \(error)")
            errorMessage = "Failed to refresh email alerts: \(error.localizedDescription)"
        }
    }

    func refreshData() async {
        print("\n🔄 [DashboardViewModel] refreshData() called")

        do {
            try Task.checkCancellation()

            // Fetch data from backend if registered
            await fetchBackendData()

            try Task.checkCancellation()

            // Refresh email alerts
            await refreshEmailAlerts()

            try Task.checkCancellation()

            // Update category spending with current transactions
            budgetService.updateCategorySpending(with: storageService.transactions)

            // Update snapshots for historical tracking
            if let monthlyTakeHome = budgetService.userIncome?.monthlyTakeHome {
                snapshotService.updateSnapshotsIfNeeded(
                    monthlyTakeHome: monthlyTakeHome,
                    transactions: storageService.transactions
                )
            }

            print(
                "🔄 [DashboardViewModel] refreshData() complete - \(transactions.count) transactions, \(unlinkedAlertsCount) alerts need entry\n"
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

            // Merge with local transactions (avoid duplicates by ID)
            for transaction in backendTransactions {
                if !storageService.transactions.contains(where: { $0.id == transaction.id }) {
                    storageService.saveTransaction(transaction)
                }
            }
            print(
                "✅ [DashboardViewModel] Fetched \(backendTransactions.count) transactions from backend"
            )

            try Task.checkCancellation()

            // Fetch unresolved transaction alerts
            print("📥 [DashboardViewModel] Fetching unresolved alerts from backend...")
            let backendAlerts = try await backendService.fetchTransactionAlerts(resolved: false)

            // Merge with local alerts
            for alert in backendAlerts {
                if !storageService.transactionAlerts.contains(where: { $0.id == alert.id }) {
                    storageService.saveTransactionAlert(alert)
                }
            }
            print(
                "✅ [DashboardViewModel] Fetched \(backendAlerts.count) unresolved alerts from backend"
            )

            try Task.checkCancellation()

            // Fetch historical data (snapshots)
            print("📥 [DashboardViewModel] Fetching historical data from backend...")
            let monthlySnapshots = try await backendService.fetchSnapshots(periodType: "monthly")
            let yearlySnapshots = try await backendService.fetchSnapshots(periodType: "yearly")

            // Update snapshot service with backend data
            for snapshot in monthlySnapshots {
                snapshotService.addSnapshot(snapshot)
            }
            for snapshot in yearlySnapshots {
                snapshotService.addSnapshot(snapshot)
            }
            print(
                "✅ [DashboardViewModel] Fetched \(monthlySnapshots.count) monthly and \(yearlySnapshots.count) yearly snapshots from backend"
            )

            try Task.checkCancellation()

            // Fetch budget categories
            print("📥 [DashboardViewModel] Fetching budget categories from backend...")
            let backendCategories = try await backendService.fetchBudgetCategories()
            for category in backendCategories {
                if !budgetService.budgetCategories.contains(where: { $0.id == category.id }) {
                    budgetService.budgetCategories.append(category)
                }
            }
            print(
                "✅ [DashboardViewModel] Fetched \(backendCategories.count) budget categories from backend"
            )

            try Task.checkCancellation()

            // Fetch active budget plan
            print("📥 [DashboardViewModel] Fetching budget plan from backend...")
            if let plan = try await backendService.fetchActiveBudgetPlan() {
                budgetService.budgetPlan = plan

                // Fetch associated user income
                if let income = try await backendService.fetchUserIncome(
                    incomeId: plan.userIncomeId)
                {
                    budgetService.userIncome = income
                }

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

    func createManualEntry(transaction: Transaction, linkedAlertId: String?) {
        // Save transaction
        storageService.saveTransaction(transaction)

        // Link to alert if provided
        if let alertId = linkedAlertId {
            storageService.linkAlert(id: alertId, toTransactionId: transaction.id)
        }

        // Update category spending
        budgetService.updateCategorySpending(with: storageService.transactions)

        print("✅ [DashboardViewModel] Created manual entry: \(transaction.title)")
    }

    func disconnect() {
        emailService.disconnect()
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

        // Update snapshots for historical tracking
        if let monthlyTakeHome = budgetService.userIncome?.monthlyTakeHome {
            snapshotService.updateSnapshotsIfNeeded(
                monthlyTakeHome: monthlyTakeHome,
                transactions: storageService.transactions
            )
        }

        print("✅ [DashboardViewModel] Synchronous update complete")
    }

    // MARK: - Test Function: Fetch One Email Alert

    func fetchOneEmailAlert() async {
        print("📧 [DashboardViewModel] Fetching one email alert for testing...")

        do {
            try Task.checkCancellation()

            // Fetch alerts from Gmail
            let newAlerts = try await emailService.pollForNewAlerts()

            try Task.checkCancellation()

            // Save just the first one for testing
            if let firstAlert = newAlerts.first {
                // Check if it already exists
                if !storageService.transactionAlerts.contains(where: {
                    $0.emailId == firstAlert.emailId
                }) {
                    storageService.saveTransactionAlert(firstAlert)
                    print(
                        "✅ [DashboardViewModel] Saved test alert: \(firstAlert.merchant) - $\(firstAlert.amount)"
                    )
                } else {
                    print("ℹ️ [DashboardViewModel] Alert already exists")
                }
            } else {
                print("ℹ️ [DashboardViewModel] No new alerts found")
            }

        } catch is CancellationError {
            print("⏹️ [DashboardViewModel] Fetch cancelled")
        } catch {
            print("❌ [DashboardViewModel] Failed to fetch alert: \(error)")
            errorMessage = "Failed to fetch email alert: \(error.localizedDescription)"
        }
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
