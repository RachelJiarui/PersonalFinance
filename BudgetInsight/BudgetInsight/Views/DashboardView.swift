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
                    // Always show content, never show loading spinner
                    if let budgetPlan = BudgetService.shared.budgetPlan,
                        !BudgetService.shared.getActiveCategories().isEmpty
                    {
                        BudgetRingsSection(
                            categories: BudgetService.shared.getActiveCategories(),
                            categorySpending: viewModel.categorySpending,
                            budgetPlan: budgetPlan
                        )
                    } else {
                        // Prompt to set up budget
                        EmptyBudgetView()
                    }
                }
                .padding()
                .padding(.bottom, 80)  // Space for FAB
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
        .navigationTitle("Dashboard")
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

                    Divider()

                    // Debug Section
                    Menu {
                        Button(action: {
                            let calendar = Calendar.current
                            let now = Date()
                            let lastMonth = calendar.date(byAdding: .month, value: -1, to: now)!
                            let year = calendar.component(.year, from: lastMonth)
                            let month = calendar.component(.month, from: lastMonth)
                            MonthEndBalancingService.shared.resetMonthBalancing(
                                year: year, month: month)
                        }) {
                            Label(
                                "Reset Last Month Balancing", systemImage: "arrow.counterclockwise")
                        }

                        Button(
                            role: .destructive,
                            action: {
                                MonthEndBalancingService.shared.resetAllBalancing()
                            }
                        ) {
                            Label(
                                "Reset All Balancing History",
                                systemImage: "exclamationmark.triangle")
                        }
                    } label: {
                        Label("Debug Tools", systemImage: "hammer")
                    }

                    Divider()

                    Button(
                        role: .destructive,
                        action: {
                            dashboardTask?.cancel()
                            viewModel.disconnect()
                        }
                    ) {
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
            // Load initial data in background without blocking UI
            dashboardTask = Task {
                await viewModel.refreshData()
            }

            // Update budget immediately with existing local data
            viewModel.updateBudgetsSync()
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
            Text(Date().formatted(date: .abbreviated, time: .omitted))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct BudgetRingsSection: View {
    let categories: [BudgetCategory]
    let categorySpending: [String: Double]
    let budgetPlan: BudgetPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            LazyVGrid(
                columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                ], spacing: 20
            ) {
                ForEach(categories) { category in
                    DashboardCategoryCard(
                        category: category,
                        currentSpent: categorySpending[category.id] ?? 0.0,
                        monthlyTakeHome: budgetPlan.monthlyTakeHome
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
