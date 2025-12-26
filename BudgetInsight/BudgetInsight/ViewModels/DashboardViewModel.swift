import Foundation
import Combine

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var budgets: [Budget] = []
    @Published var insights: [SpendingInsight] = []
    @Published var spendingSummary: SpendingSummary?
    @Published var isLoading: Bool = false
    @Published var isConnected: Bool = false
    @Published var setupToken: String = ""
    @Published var showingSetupAlert: Bool = false
    @Published var errorMessage: String?

    private let simpleFinService = SimpleFinService.shared
    private let budgetService = BudgetService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        setupSubscriptions()
        checkConnectionStatus()
    }

    private func setupSubscriptions() {
        simpleFinService.$isConnected
            .assign(to: &$isConnected)

        simpleFinService.$isLoading
            .assign(to: &$isLoading)

        budgetService.$budgets
            .assign(to: &$budgets)

        budgetService.$spendingSummary
            .assign(to: &$spendingSummary)

        Publishers.CombineLatest3(
            budgetService.$budgets,
            simpleFinService.$transactions,
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

    func checkConnectionStatus() {
        isConnected = simpleFinService.isConnected
    }

    func connectToSimpleFin() {
        showingSetupAlert = true
    }

    func claimSetupToken() {
        guard !setupToken.isEmpty else {
            errorMessage = "Please enter a setup token"
            return
        }

        Task {
            do {
                try await simpleFinService.claimSetupToken(setupToken)
                showingSetupAlert = false
                setupToken = ""
                await refreshData()
            } catch {
                errorMessage = "Failed to claim token: \(error.localizedDescription)"
                print("Failed to claim token: \(error)")
            }
        }
    }

    func refreshData() async {
        print("\n🔄 [DashboardViewModel] refreshData() called")
        await simpleFinService.syncTransactions()
        print("🔄 [DashboardViewModel] Synced \(simpleFinService.transactions.count) transactions from SimpleFin")
        budgetService.updateBudgets(with: simpleFinService.transactions)
        print("🔄 [DashboardViewModel] refreshData() complete\n")
    }

    func disconnect() {
        simpleFinService.disconnect()
        budgetService.createDefaultBudgets()
    }
}
