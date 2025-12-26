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
        isLoading = true

        do {
            let newAlerts = try await emailService.pollForNewAlerts()

            // Save new alerts that don't already exist
            for alert in newAlerts {
                if !storageService.transactionAlerts.contains(where: { $0.emailId == alert.emailId }) {
                    storageService.saveTransactionAlert(alert)
                }
            }

            print("✅ [DashboardViewModel] Found \(newAlerts.count) new alerts")
        } catch {
            print("❌ [DashboardViewModel] Failed to refresh alerts: \(error)")
            errorMessage = "Failed to refresh email alerts: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func refreshData() async {
        print("\n�� [DashboardViewModel] refreshData() called")

        // Refresh email alerts
        await refreshEmailAlerts()

        // Update budgets with current transactions
        budgetService.updateBudgets(with: storageService.transactions)

        print("🔄 [DashboardViewModel] refreshData() complete - \(transactions.count) transactions, \(unlinkedAlertsCount) alerts need entry\n")
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
}
