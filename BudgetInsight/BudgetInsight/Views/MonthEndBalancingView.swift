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
                        // Progress Indicator
                        ProgressView(
                            value: Double(viewModel.currentStep),
                            total: Double(viewModel.totalSteps - 1)
                        )
                        .padding()

                        // Step Content
                        TabView(selection: $viewModel.currentStep) {
                            // Step 1: Month Wrapped
                            MonthWrappedView(
                                stats: stats,
                                onReviewData: { viewModel.nextStep() },
                                onNext: { viewModel.currentStep = 2 }
                            )
                            .tag(0)

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

                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        if !unbalancedMonths.isEmpty {
                            Text(monthProgress)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Text(viewModel.progressText())
                            .font(.caption2)
                            .foregroundColor(.secondary)
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
                        Text("Continue to Summary")
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
