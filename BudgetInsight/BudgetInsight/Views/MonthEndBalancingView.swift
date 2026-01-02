import SwiftUI

struct MonthEndBalancingView: View {
    @EnvironmentObject var balancingService: MonthEndBalancingService
    @StateObject private var viewModel = MonthEndBalancingViewModel()
    @State private var currentMonthIndex = 0

    private var unbalancedMonths: [(year: Int, month: Int)] {
        balancingService.unbalancedMonths
    }

    private var currentMonth: (year: Int, month: Int)? {
        guard currentMonthIndex < unbalancedMonths.count else { return nil }
        return unbalancedMonths[currentMonthIndex]
    }

    private var monthProgress: String {
        guard !unbalancedMonths.isEmpty else { return "" }
        return "Month \(currentMonthIndex + 1) of \(unbalancedMonths.count)"
    }

    var body: some View {
        NavigationView {
            ZStack {
                if currentMonth != nil, let stats = viewModel.currentMonthStats {
                    VStack(spacing: 0) {
                        // Step Indicator
                        HStack {
                            Text("Step \(viewModel.currentStep + 1) of 3")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)

                        // Step Content
                        TabView(selection: $viewModel.currentStep) {
                            // Step 1: Month Wrapped
                            MonthWrappedView(
                                stats: stats,
                                onReviewData: { viewModel.nextStep() },
                                onNext: { viewModel.currentStep = 2 }
                            )
                            .tag(0)
                            .id(
                                "\(stats.year)-\(stats.month)-\(stats.totalIncome)-\(stats.totalSpending)"
                            )

                            // Step 2: Review Data
                            ReviewDataStepView(
                                year: stats.year,
                                month: stats.month,
                                onNext: {
                                    viewModel.refreshCurrentMonthStats()
                                    viewModel.nextStep()
                                }
                            )
                            .tag(1)

                            // Step 3: Summary
                            BalancingSummaryView(
                                stats: stats,
                                onComplete: completeCurrentMonth
                            )
                            .tag(2)
                            .id(
                                "\(stats.year)-\(stats.month)-\(stats.totalIncome)-\(stats.totalSpending)-summary"
                            )
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    }
                } else {
                    // Loading state
                    VStack(spacing: 20) {
                        ProgressView()
                        Text("Loading month data...")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Balance the Books")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if viewModel.currentStep > 0 {
                        Button(action: { viewModel.previousStep() }) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                        }
                    }
                }
            }
            .alert(
                "Error",
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { if !$0 { viewModel.errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
            .onAppear {
                loadCurrentMonth()
            }
            .onChange(of: currentMonthIndex) { _ in
                loadCurrentMonth()
            }
            .onChange(of: viewModel.currentStep) { newStep in
                // Refresh stats when navigating back to Month Wrapped from Review Data
                if newStep == 0 {
                    viewModel.refreshCurrentMonthStats()
                }
            }
        }
    }

    private func loadCurrentMonth() {
        guard let month = currentMonth else { return }
        viewModel.loadStatsForMonth(year: month.year, month: month.month)
    }

    private func completeCurrentMonth() {
        Task {
            await viewModel.completeBalancing()

            // Check if there was an error
            if viewModel.errorMessage == nil {
                // Success! Move to next month or exit
                await MainActor.run {
                    if currentMonthIndex < unbalancedMonths.count - 1 {
                        // More months to balance
                        currentMonthIndex += 1
                    } else {
                        // All months balanced - the service will update needsBalancing
                        // which will automatically dismiss this view
                    }
                }
            }
        }
    }
}

// MARK: - Review Data Step View

struct ReviewDataStepView: View {
    let year: Int
    let month: Int
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ReviewDataView(year: year, month: month)

            // Navigation Button
            VStack(spacing: 0) {
                Divider()

                Button(action: onNext) {
                    HStack {
                        Text("Next")
                        Image(systemName: "chevron.right")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding()
                .background(Color(.systemBackground))
            }
        }
    }
}
