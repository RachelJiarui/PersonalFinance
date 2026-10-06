import SwiftUI

struct ContentView: View {
    @StateObject private var dashboardViewModel = DashboardViewModel()
    @StateObject private var budgetViewModel = BudgetViewModel()
    @StateObject private var historyViewModel = HistoryViewModel()
    @StateObject private var balancingService = MonthEndBalancingService.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var refreshTask: Task<Void, Never>?
    @State private var showBalancing = false

    var body: some View {
        MainTabView()
            .environmentObject(dashboardViewModel)
            .environmentObject(budgetViewModel)
            .environmentObject(historyViewModel)
            .fullScreenCover(isPresented: $showBalancing) {
                MonthEndBalancingView()
                    .environmentObject(balancingService)
                    .interactiveDismissDisabled(true)  // CANNOT swipe to dismiss
            }
            .onChange(of: scenePhase) { newPhase in
                handleScenePhaseChange(newPhase)
            }
            .task {
                // Sync the authoritative transaction list from the backend first —
                // checking for unbalanced months against the stale local cache can
                // miss recent transactions and leave the balancing flow stuck.
                let task = Task {
                    await dashboardViewModel.refreshData()
                }
                refreshTask = task
                await task.value

                await balancingService.checkForUnbalancedMonths()
                showBalancing = balancingService.needsBalancing
            }
            .onChange(of: balancingService.needsBalancing) { needsBalancing in
                showBalancing = needsBalancing
            }
            .onDisappear {
                refreshTask?.cancel()
                refreshTask = nil
            }
    }

    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            print("🔄 [ContentView] App became active")
            // Re-check balancing on app return, after syncing transactions first
            // so the check doesn't run against a stale local cache.
            Task {
                await dashboardViewModel.refreshData()
                await balancingService.checkForUnbalancedMonths()
            }

        case .inactive:
            print("⏸️ [ContentView] App became inactive")
            refreshTask?.cancel()

        case .background:
            print("📴 [ContentView] App went to background")
            refreshTask?.cancel()
            dashboardViewModel.cancelAllTasks()

        @unknown default:
            break
        }
    }
}
