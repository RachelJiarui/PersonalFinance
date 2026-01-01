import SwiftUI

struct ReviewDataView: View {
    let year: Int
    let month: Int
    @Environment(\.dismiss) var dismiss
    @StateObject private var transactionService = TransactionStorageService.shared
    @StateObject private var budgetService = BudgetService.shared
    @StateObject private var allocationService = AllocationService.shared
    @State private var selectedTransaction: Transaction?
    @State private var showEditSheet = false

    private var monthTransactions: [Transaction] {
        transactionService.getTransactionsForMonth(year: year, month: month)
    }

    private var totalIncome: Double {
        monthTransactions.filter { !$0.isExpense }.reduce(0.0) { $0 + $1.amount }
    }

    private var totalExpenses: Double {
        monthTransactions.filter { $0.isExpense }.reduce(0.0) { $0 + $1.amount }
    }

    private var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        let calendar = Calendar.current
        let components = DateComponents(year: year, month: month)
        if let date = calendar.date(from: components) {
            return formatter.string(from: date)
        }
        return "Month \(month)"
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Summary Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Summary")
                            .font(.headline)

                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Total Income")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text("$\(String(format: "%.2f", totalIncome))")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.green)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Total Expenses")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text("$\(String(format: "%.2f", totalExpenses))")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.red)
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)

                    // Transactions Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("All Transactions (\(monthTransactions.count))")
                            .font(.headline)
                            .padding(.horizontal)

                        if monthTransactions.isEmpty {
                            Text("No transactions for this month")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            ForEach(monthTransactions.sorted(by: { $0.date > $1.date })) {
                                transaction in
                                Button(action: {
                                    selectedTransaction = transaction
                                    showEditSheet = true
                                }) {
                                    SimpleTransactionRow(transaction: transaction)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }

                    // Info Message
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Review & Edit")
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            Text(
                                "Tap any transaction to edit it. Changes will be reflected in your month summary."
                            )
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.bottom)
                }
                .padding(.top)
            }
            .navigationTitle("\(monthName) \(year) Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showEditSheet) {
                if let transaction = selectedTransaction {
                    EditTransactionView(
                        originalTransaction: transaction,
                        originalAllocations: allocationService.allocations.filter {
                            $0.transactionId == transaction.id
                        }
                    )
                }
            }
        }
    }
}

struct SimpleTransactionRow: View {
    let transaction: Transaction

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: transaction.date)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            Image(
                systemName: transaction.isExpense
                    ? "arrow.up.circle.fill" : "arrow.down.circle.fill"
            )
            .font(.title2)
            .foregroundColor(transaction.isExpense ? .red : .green)

            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.title)
                    .font(.body)
                    .lineLimit(2)

                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Amount
            Text(
                transaction.isExpense
                    ? "-$\(String(format: "%.2f", transaction.amount))"
                    : "+$\(String(format: "%.2f", transaction.amount))"
            )
            .font(.headline)
            .foregroundColor(transaction.isExpense ? .red : .green)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}
