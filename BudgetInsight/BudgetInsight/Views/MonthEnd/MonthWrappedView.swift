import SwiftUI

struct MonthWrappedView: View {
    let stats: MonthWrappedStats
    let onReviewData: () -> Void
    let onNext: () -> Void

    @StateObject private var alertService = TransactionAlertService.shared

    // Unresolved alerts from the month being reviewed
    private var unresolvedAlertsForMonth: [TransactionAlert] {
        let calendar = Calendar.current
        return alertService.unresolvedAlerts.filter { alert in
            let alertYear = calendar.component(.year, from: alert.transactionDate)
            let alertMonth = calendar.component(.month, from: alert.transactionDate)
            return alertYear == stats.year && alertMonth == stats.month
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Unlinked Transaction Alerts Warning
                if !unresolvedAlertsForMonth.isEmpty {
                    UnlinkedAlertsWarningView(
                        alertCount: unresolvedAlertsForMonth.count,
                        monthName: stats.monthName,
                        onReviewData: onReviewData
                    )
                    .padding(.horizontal)
                    .padding(.top)
                }

                // Header
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)

                    Text("\(stats.monthName) \(String(stats.year))")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Month Summary")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, unresolvedAlertsForMonth.isEmpty ? 0 : 0)

                // Diff Spending - MOST IMPORTANT
                VStack(spacing: 12) {
                    Text(stats.diffSpending >= 0 ? "Net Savings" : "Net Deficit")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(stats.diffSpending >= 0 ? "+" : "-")
                        Text("$\(String(format: "%.2f", abs(stats.diffSpending)))")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(stats.diffSpending >= 0 ? .green : .red)

                    if stats.diffSpending >= 0 {
                        Text("Great job! You saved money this month.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("You spent more than you earned this month.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)
                .padding(.horizontal)

                // Fund & Debt Allocations
                if !stats.fundDebtAllocations.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Fund & Debt Transactions")
                            .font(.headline)
                            .padding(.horizontal)

                        if !stats.fundAllocations.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Funds")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)

                                ForEach(stats.fundAllocations) { allocation in
                                    FundDebtAllocationRow(allocation: allocation)
                                }
                            }
                        }

                        if !stats.debtAllocations.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Debts")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                                    .padding(.top, stats.fundAllocations.isEmpty ? 0 : 8)

                                ForEach(stats.debtAllocations) { allocation in
                                    FundDebtAllocationRow(allocation: allocation)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)
                }

                // Monthly Statistics
                VStack(alignment: .leading, spacing: 16) {
                    Text("Monthly Statistics")
                        .font(.headline)
                        .padding(.horizontal)

                    StatRow(
                        icon: "arrow.down.circle.fill",
                        iconColor: .green,
                        label: "Total Income",
                        value: "$\(String(format: "%.2f", stats.totalIncome))"
                    )

                    StatRow(
                        icon: "arrow.up.circle.fill",
                        iconColor: .red,
                        label: "Total Spending",
                        value: "$\(String(format: "%.2f", stats.totalSpending))"
                    )

                    StatRow(
                        icon: "arrow.up.doc.fill",
                        iconColor: .red,
                        label: "Expense Transactions",
                        value: "\(stats.expenseTransactionCount)"
                    )

                    StatRow(
                        icon: "arrow.down.doc.fill",
                        iconColor: .green,
                        label: "Income Transactions",
                        value: "\(stats.incomeTransactionCount)"
                    )
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)
                .padding(.horizontal)

                // Category Breakdown
                VStack(alignment: .leading, spacing: 16) {
                    Text("Category Breakdown")
                        .font(.headline)
                        .padding(.horizontal)

                    if !stats.categoriesWithSavings.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Savings")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)

                            ForEach(stats.categoriesWithSavings, id: \.category.id) { balance in
                                CategoryBalanceRow(balance: balance, isSurplus: true)
                            }
                        }
                    }

                    if !stats.categoriesWithDeficits.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Overspending")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                                .padding(.top, 8)

                            ForEach(stats.categoriesWithDeficits, id: \.category.id) { balance in
                                CategoryBalanceRow(balance: balance, isSurplus: false)
                            }
                        }
                    }

                    if stats.categoriesWithSavings.isEmpty && stats.categoriesWithDeficits.isEmpty {
                        Text("All categories were perfectly balanced!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)
                .padding(.horizontal)

                Spacer()
            }
            .padding(.vertical)
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: onReviewData) {
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
        .onAppear {
            // Fetch transaction alerts to check for unlinked ones
            Task {
                await alertService.fetchAlerts()
            }
        }
    }
}

struct StatRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(iconColor)
                .frame(width: 40)

            Text(label)
                .font(.body)

            Spacer()

            Text(value)
                .font(.headline)
                .foregroundColor(.primary)
        }
        .padding(.horizontal)
    }
}

struct CategoryBalanceRow: View {
    let balance: CategoryBalance
    let isSurplus: Bool

    var body: some View {
        HStack {
            Image(systemName: balance.category.icon)
                .foregroundColor(isSurplus ? .green : .orange)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(balance.category.name)
                    .font(.body)

                Text(
                    "Budgeted: $\(String(format: "%.2f", balance.budgetAmount)) | Spent: $\(String(format: "%.2f", balance.actualSpending))"
                )
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text(
                    isSurplus
                        ? "+$\(String(format: "%.2f", balance.surplus))"
                        : "-$\(String(format: "%.2f", balance.deficit))"
                )
                .font(.headline)
                .foregroundColor(isSurplus ? .green : .orange)
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

// MARK: - Unlinked Alerts Warning View

struct UnlinkedAlertsWarningView: View {
    let alertCount: Int
    let monthName: String
    let onReviewData: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundColor(.orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Unlinked Transaction Alerts")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(
                        "You have \(alertCount) transaction \(alertCount == 1 ? "alert" : "alerts") from \(monthName) that \(alertCount == 1 ? "hasn't" : "haven't") been linked to a transaction yet."
                    )
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            Button(action: onReviewData) {
                HStack {
                    Image(systemName: "arrow.right.circle.fill")
                    Text("Review & Link Transactions")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

struct FundDebtAllocationRow: View {
    let allocation: FundDebtAllocation

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }

    var body: some View {
        HStack {
            Image(systemName: allocation.destinationIcon)
                .foregroundColor(allocation.destinationType == .fund ? .blue : .orange)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(allocation.destinationName)
                    .font(.body)

                Text(allocation.transactionTitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(
                    allocation.isExpense
                        ? "-$\(String(format: "%.2f", allocation.amount))"
                        : "+$\(String(format: "%.2f", allocation.amount))"
                )
                .font(.headline)
                .foregroundColor(allocation.isExpense ? .red : .green)

                Text(dateFormatter.string(from: allocation.transactionDate))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}
