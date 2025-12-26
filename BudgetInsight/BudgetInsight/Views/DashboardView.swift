import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var showManualEntry = false
    @State private var dashboardTask: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(spacing: 24) {
                    HeaderView()

                    if viewModel.isLoading {
                        ProgressView()
                            .padding()
                    } else {
                        // New percentage-based budget section
                        if let allocation = BudgetService.shared.budgetAllocation,
                           let income = BudgetService.shared.userIncome {
                            BudgetRingsSection(allocation: allocation, income: income)
                        } else {
                            // Prompt to set up budget
                            EmptyBudgetView()
                        }
                    }
                }
                .padding()
                .padding(.bottom, 80) // Space for FAB
            }

            // MARK: - Floating Action Button
            Button(action: {
                showManualEntry = true
            }) {
                HStack {
                    Image(systemName: "plus")
                    Text("Add Transaction")
                }
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.blue)
                .cornerRadius(25)
                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        dashboardTask?.cancel()
                        dashboardTask = Task {
                            await viewModel.refreshData()
                        }
                    }) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }

                    Button(role: .destructive, action: {
                        dashboardTask?.cancel()
                        viewModel.disconnect()
                    }) {
                        Label("Disconnect", systemImage: "xmark.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .refreshable {
            dashboardTask?.cancel()
            await viewModel.refreshData()
        }
        .task {
            dashboardTask = Task {
                await viewModel.refreshData()
            }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .background {
                dashboardTask?.cancel()
            }
        }
        .onDisappear {
            dashboardTask?.cancel()
            dashboardTask = nil
        }
        .sheet(isPresented: $showManualEntry) {
            ManualEntryView()
        }
    }
}

struct HeaderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dashboard")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text(Date().formatted(date: .abbreviated, time: .omitted))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct BudgetRingsSection: View {
    let allocation: BudgetAllocation
    let income: UserIncome

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Budget Categories")
                .font(.title2)
                .fontWeight(.bold)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 20) {
                ForEach(allocation.categories) { category in
                    DashboardCategoryCard(
                        category: category,
                        monthlyTakeHome: income.monthlyTakeHome
                    )
                }
            }
        }
    }
}

struct EmptyBudgetView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.pie.fill")
                .font(.system(size: 64))
                .foregroundColor(.gray)

            Text("Set Up Your Budget")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Go to 'My Budget' tab to configure your income and budget categories")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.vertical, 40)
    }
}
