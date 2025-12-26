import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = DashboardViewModel()

    var body: some View {
        NavigationView {
            if viewModel.isEmailConnected {
                DashboardView()
                    .environmentObject(viewModel)
            } else {
                EmailSetupView()
            }
        }
        .task {
            if viewModel.isEmailConnected {
                await viewModel.refreshData()
            }
        }
    }
}
