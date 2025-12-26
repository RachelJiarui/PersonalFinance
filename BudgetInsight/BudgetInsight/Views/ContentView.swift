import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @State private var refreshTask: Task<Void, Never>?

    var body: some View {
        NavigationView {
            if viewModel.isEmailConnected {
                DashboardView()
                    .environmentObject(viewModel)
            } else {
                EmailSetupView()
            }
        }
        .onChange(of: scenePhase) { newPhase in
            handleScenePhaseChange(newPhase)
        }
        .task {
            if viewModel.isEmailConnected {
                // Store task reference for cancellation
                refreshTask = Task {
                    await viewModel.refreshData()
                }
            }
        }
        .onDisappear {
            // Cancel refresh task when view disappears
            refreshTask?.cancel()
            refreshTask = nil
        }
    }

    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            print("🔄 [ContentView] App became active")
            // Optionally refresh data when app comes to foreground
            if viewModel.isEmailConnected {
                Task {
                    await viewModel.refreshData()
                }
            }

        case .inactive:
            print("⏸️ [ContentView] App became inactive")
            // Cancel ongoing tasks
            refreshTask?.cancel()

        case .background:
            print("📴 [ContentView] App went to background")
            // Cancel all tasks immediately to prevent SIGTERM
            refreshTask?.cancel()
            viewModel.cancelAllTasks()

        @unknown default:
            break
        }
    }
}
