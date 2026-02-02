import SwiftUI

struct BalancingSummaryView: View {
    let stats: MonthWrappedStats
    let onComplete: () -> Void
    @StateObject private var fundService = FundService.shared
    @StateObject private var debtService = DebtService.shared

    private var destinationInfo: (name: String, amount: Double, isDebt: Bool)? {
        if stats.diffSpending > 0 {
            // Positive savings - goes to default fund
            return ("General Savings", stats.diffSpending, false)
        } else if stats.diffSpending < 0 {
            // Deficit - goes to default debt
            return ("General Debt", abs(stats.diffSpending), true)
        }
        return nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Summary")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.horizontal)

                Text("Review the month-end allocation before completing.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                // Auto-Allocation Info
                if let destination = destinationInfo {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Auto-Allocation")
                            .font(.headline)
                            .padding(.horizontal)

                        HStack {
                            Image(
                                systemName: destination.isDebt ? "creditcard" : "dollarsign.circle"
                            )
                            .font(.system(size: 50))
                            .foregroundColor(destination.isDebt ? .orange : .green)

                            VStack(alignment: .leading, spacing: 8) {
                                Text(destination.isDebt ? "Net Deficit" : "Net Savings")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Text("$\(String(format: "%.2f", destination.amount))")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(destination.isDebt ? .orange : .green)

                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.right")
                                        .font(.caption)
                                    Text(destination.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.secondary)
                            }

                            Spacer()
                        }
                        .padding()
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)
                } else {
                    // Perfectly balanced
                    VStack(spacing: 16) {
                        Image(systemName: "equal.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)

                        Text("Perfectly Balanced")
                            .font(.headline)

                        Text("Your income matched your spending exactly this month.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)
                }

                // Info
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Automatic Allocation")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        if let destination = destinationInfo {
                            if destination.isDebt {
                                Text(
                                    "This month's deficit will be automatically added to your \(destination.name) bucket. You can transfer funds later to pay it off."
                                )
                                .font(.caption)
                                .foregroundColor(.secondary)
                            } else {
                                Text(
                                    "This month's savings will be automatically added to your \(destination.name) bucket. You can transfer it to other funds or debts later."
                                )
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                        } else {
                            Text(
                                "No allocation needed this month since income matched spending."
                            )
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)

                Spacer()
            }
            .padding(.vertical)
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: onComplete) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Complete Monthly Review & Rollover")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding()
            .background(Color(.systemBackground))
        }
    }
}
