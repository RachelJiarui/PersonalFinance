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
                // Check for unbalanced months on app launch
                await balancingService.checkForUnbalancedMonths()
                showBalancing = balancingService.needsBalancing

                refreshTask = Task {
                    await dashboardViewModel.refreshData()
                }
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
            // Re-check balancing on app return
            Task {
                await balancingService.checkForUnbalancedMonths()
            }
            Task {
                await dashboardViewModel.refreshData()
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
