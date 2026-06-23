import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var showManualEntry = false
    @State private var showTransactionAlerts = false
    @State private var dashboardTask: Task<Void, Never>?
    @State private var bannerVisible = false

    var body: some View {
        VStack(spacing: 0) {
            if bannerVisible && viewModel.gmailAuthFailed {
                GmailDisconnectedBanner {
                    Task { await viewModel.connectGmail() }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            gmailContent
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.easeOut(duration: 0.4)) {
                    bannerVisible = true
                }
            }
        }
    }

    @ViewBuilder
    private var gmailContent: some View {
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

                    // Gmail Integration Section
                    Button(action: {
                        Task {
                            await viewModel.connectGmail()
                        }
                    }) {
                        Label("Connect Gmail", systemImage: "envelope.badge")
                    }

                    Button(action: {
                        showTransactionAlerts = true
                    }) {
                        Label("Transaction Alerts", systemImage: "bell.badge")
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
        .sheet(isPresented: $showTransactionAlerts) {
            TransactionAlertsView()
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

    // Sort categories: starred first, then by name
    var sortedCategories: [BudgetCategory] {
        categories.sorted { lhs, rhs in
            if lhs.isStarred != rhs.isStarred {
                return lhs.isStarred  // Starred categories come first
            }
            return lhs.name < rhs.name  // Then alphabetically
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            LazyVGrid(
                columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                ], spacing: 20
            ) {
                ForEach(sortedCategories) { category in
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

struct GmailDisconnectedBanner: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "envelope.badge.fill")
                    .foregroundColor(.white)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Gmail Disconnected")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    Text("Tap to reconnect")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.85))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.orange)
        }
        .buttonStyle(.plain)
    }
}
