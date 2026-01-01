import SwiftUI

struct MonthWrappedView: View {
    let stats: MonthWrappedStats
    let onReviewData: () -> Void
    let onNext: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
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
                .padding(.top)

                // Net Savings - MOST IMPORTANT
                VStack(spacing: 12) {
                    Text("Net Savings")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(stats.netSavings >= 0 ? "+" : "")
                        Text("$\(String(format: "%.2f", abs(stats.netSavings)))")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(stats.netSavings >= 0 ? .green : .red)

                    if stats.netSavings >= 0 {
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
                        icon: "doc.text.fill",
                        iconColor: .blue,
                        label: "Transactions",
                        value: "\(stats.transactionCount)"
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
            VStack(spacing: 12) {
                Button(action: onReviewData) {
                    HStack {
                        Image(systemName: "doc.text.magnifyingglass")
                        Text("Review Data")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .foregroundColor(.primary)
                    .cornerRadius(10)
                }

                Button(action: onNext) {
                    HStack {
                        Text("Next")
                        Image(systemName: "arrow.right")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
            .padding()
            .background(Color(.systemBackground))
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
