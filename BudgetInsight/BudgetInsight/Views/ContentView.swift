import SwiftUI

struct ContentView: View {
    @StateObject private var dashboardViewModel = DashboardViewModel()
    @StateObject private var budgetViewModel = BudgetViewModel()
    @StateObject private var historyViewModel = HistoryViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @State private var refreshTask: Task<Void, Never>?

    var body: some View {
        Group {
            if dashboardViewModel.isEmailConnected {
                MainTabView()
                    .environmentObject(dashboardViewModel)
                    .environmentObject(budgetViewModel)
                    .environmentObject(historyViewModel)
            } else {
                NavigationView {
                    EmailSetupView()
                }
            }
        }
        .onChange(of: scenePhase) { newPhase in
            handleScenePhaseChange(newPhase)
        }
        .task {
            if dashboardViewModel.isEmailConnected {
                refreshTask = Task {
                    await dashboardViewModel.refreshData()
                }
            }
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
            if dashboardViewModel.isEmailConnected {
                Task {
                    await dashboardViewModel.refreshData()
                }
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
