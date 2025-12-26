import Foundation
import Combine

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var budgets: [Budget] = []
    @Published var insights: [SpendingInsight] = []
    @Published var spendingSummary: SpendingSummary?
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
        budgetService.$budgets
            .assign(to: &$budgets)

        budgetService.$spendingSummary
            .assign(to: &$spendingSummary)

        // Update unlinked alerts count whenever alerts change
        storageService.$transactionAlerts
            .map { alerts in
                alerts.filter { !$0.isLinked }.count
            }
            .assign(to: &$unlinkedAlertsCount)

        // Generate insights when budgets, transactions, or summary change
        Publishers.CombineLatest3(
            budgetService.$budgets,
            storageService.$transactions,
            budgetService.$spendingSummary
        )
        .sink { [weak self] budgets, transactions, summary in
            guard let self = self, let summary = summary else { return }
            self.insights = InsightEngine.generateInsights(
                budgets: budgets,
                transactions: transactions,
                summary: summary
            )
        }
        .store(in: &cancellables)
    }

    func checkEmailConnection() {
        isEmailConnected = emailService.isAuthenticated
    }

    func loadLocalData() {
        // Data is automatically loaded via storageService subscriptions
        // Update budgets with loaded transactions
        budgetService.updateBudgets(with: storageService.transactions)
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
                try Task.checkCancellation() // Check in loop

                if !storageService.transactionAlerts.contains(where: { $0.emailId == alert.emailId }) {
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

            // Refresh email alerts
            await refreshEmailAlerts()

            try Task.checkCancellation()

            // Update budgets with current transactions
            budgetService.updateBudgets(with: storageService.transactions)

            // Update category spending for new budget system
            budgetService.updateCategorySpending(with: storageService.transactions)

            // Update snapshots for historical tracking
            if let monthlyTakeHome = budgetService.userIncome?.monthlyTakeHome {
                snapshotService.updateSnapshotsIfNeeded(
                    monthlyTakeHome: monthlyTakeHome,
                    transactions: storageService.transactions
                )
            }

            print("🔄 [DashboardViewModel] refreshData() complete - \(transactions.count) transactions, \(unlinkedAlertsCount) alerts need entry\n")
        } catch is CancellationError {
            print("⏹️ [DashboardViewModel] Refresh cancelled")
        } catch {
            print("❌ [DashboardViewModel] Refresh error: \(error)")
        }
    }

    func createManualEntry(transaction: Transaction, linkedAlertId: String?) {
        // Save transaction
        storageService.saveTransaction(transaction)

        // Link to alert if provided
        if let alertId = linkedAlertId {
            storageService.linkAlert(id: alertId, toTransactionId: transaction.id)
        }

        // Update budgets
        budgetService.updateBudgets(with: storageService.transactions)

        print("✅ [DashboardViewModel] Created manual entry: \(transaction.merchantName ?? "Unknown")")
    }

    func disconnect() {
        emailService.disconnect()
        budgetService.createDefaultBudgets()
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

        // Update budgets with current transactions (synchronous, instant)
        budgetService.updateBudgets(with: storageService.transactions)

        // Update category spending for new budget system
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
                if !storageService.transactionAlerts.contains(where: { $0.emailId == firstAlert.emailId }) {
                    storageService.saveTransactionAlert(firstAlert)
                    print("✅ [DashboardViewModel] Saved test alert: \(firstAlert.merchant) - $\(firstAlert.amount)")
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
}
