import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    @State private var showManualEntry = false
    @State private var showNeedsEntry = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(spacing: 24) {
                    HeaderView()

                    // MARK: - Needs Entry Section
                    if viewModel.unlinkedAlertsCount > 0 {
                        NeedsEntryBanner(count: viewModel.unlinkedAlertsCount) {
                            showNeedsEntry = true
                        }
                    }

                    if viewModel.isLoading {
                        ProgressView()
                            .padding()
                    } else {
                        if let summary = viewModel.spendingSummary {
                            SummaryCard(summary: summary)
                        }

                        InsightsSection(insights: viewModel.insights)

                        BudgetSection(budgets: viewModel.budgets)
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
                        Task {
                            await viewModel.refreshData()
                        }
                    }) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }

                    Button(role: .destructive, action: {
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
            await viewModel.refreshData()
        }
        .task {
            await viewModel.refreshData()
        }
        .sheet(isPresented: $showManualEntry) {
            ManualEntryView()
        }
        .sheet(isPresented: $showNeedsEntry) {
            NeedsEntryView()
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

struct SummaryCard: View {
    let summary: SpendingSummary

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Monthly Overview")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text("$\(Int(summary.netCashFlow))")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(summary.netCashFlow >= 0 ? .green : .red)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.green)
                        Text("$\(Int(summary.totalIncome))")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(.red)
                        Text("$\(Int(summary.totalExpenses))")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
            }

            Divider()

            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(.blue)
                    VStack(alignment: .leading) {
                        Text("Savings Rate")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(Int(summary.savingsRate))%")
                            .font(.headline)
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .foregroundColor(.orange)
                    VStack(alignment: .leading) {
                        Text("vs Last Month")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(summary.monthOverMonth >= 0 ? "+" : "")\(String(format: "%.1f", summary.monthOverMonth))%")
                            .font(.headline)
                            .foregroundColor(summary.monthOverMonth >= 0 ? .red : .green)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct InsightsSection: View {
    let insights: [SpendingInsight]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Insights")
                .font(.title2)
                .fontWeight(.bold)

            if insights.isEmpty {
                Text("No insights available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(insights.prefix(3)) { insight in
                    InsightCard(insight: insight)
                }
            }
        }
    }
}

struct InsightCard: View {
    let insight: SpendingInsight

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundColor(iconColor)
                .frame(width: 40, height: 40)
                .background(iconColor.opacity(0.1))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.headline)

                Text(insight.message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private var iconName: String {
        switch insight.type {
        case .warning: return "exclamationmark.triangle.fill"
        case .recommendation: return "lightbulb.fill"
        case .achievement: return "checkmark.seal.fill"
        }
    }

    private var iconColor: Color {
        switch insight.type {
        case .warning: return .red
        case .recommendation: return .blue
        case .achievement: return .green
        }
    }
}

struct BudgetSection: View {
    let budgets: [Budget]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Budget Categories")
                .font(.title2)
                .fontWeight(.bold)

            ForEach(budgets) { budget in
                CategoryCard(budget: budget)
            }
        }
    }
}

struct NeedsEntryBanner: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "envelope.badge.fill")
                    .font(.title2)
                    .foregroundColor(.orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Needs Entry")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("\(count) transaction alert\(count == 1 ? "" : "s") waiting")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
