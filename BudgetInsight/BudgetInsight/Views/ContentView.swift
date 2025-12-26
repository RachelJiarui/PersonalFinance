import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = DashboardViewModel()

    var body: some View {
        NavigationView {
            if viewModel.isConnected {
                DashboardView()
                    .environmentObject(viewModel)
            } else {
                OnboardingView()
                    .environmentObject(viewModel)
            }
        }
        .task {
            if viewModel.isConnected {
                await viewModel.refreshData()
            }
        }
    }
}

struct OnboardingView: View {
    @EnvironmentObject var viewModel: DashboardViewModel

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 72))
                    .foregroundColor(.blue)

                Text("Budget Insight")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Track your spending, manage your budget, and achieve your financial goals")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            VStack(spacing: 16) {
                Button(action: {
                    viewModel.connectToSimpleFin()
                }) {
                    HStack {
                        Image(systemName: "link")
                        Text("Connect SimpleFin")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 32)

                Text("Secure connection via SimpleFin Bridge")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 48)
        }
        .alert("Connect SimpleFin", isPresented: $viewModel.showingSetupAlert) {
            TextField("Paste Setup Token", text: $viewModel.setupToken)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Button("Cancel", role: .cancel) {
                viewModel.setupToken = ""
            }

            Button("Connect") {
                viewModel.claimSetupToken()
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            } else {
                Text("Paste your SimpleFin setup token from beta-bridge.simplefin.org")
            }
        }
    }
}
