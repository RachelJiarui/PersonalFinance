import SwiftUI

struct ReviewDataView: View {
    let year: Int
    let month: Int
    @Environment(\.dismiss) var dismiss
    @StateObject private var transactionService = TransactionStorageService.shared
    @StateObject private var budgetService = BudgetService.shared
    @StateObject private var allocationService = AllocationService.shared
    @State private var showAddTransaction = false

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

                        Spacer()
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)

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
                    .id(transactionService.transactions.count)

                    // Transactions Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("All Transactions")
                                .font(.headline)

                            Spacer()

                            Button(action: {
                                showAddTransaction = true
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal)

                        if monthTransactions.isEmpty {
                            Text("No transactions for this month")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            let sortedTransactions = monthTransactions.sorted(by: {
                                $0.date > $1.date
                            })
                            ForEach(Array(sortedTransactions.enumerated()), id: \.element.id) {
                                index, transaction in
                                NavigationLink(
                                    destination: TransactionDetailView(
                                        transaction: transaction,
                                        budgetService: budgetService,
                                        allocationService: allocationService
                                    )
                                ) {
                                    TransactionRowView(
                                        transaction: transaction,
                                        budgetService: budgetService,
                                        allocationService: allocationService
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }
                .padding(.top)
            }
            .navigationTitle("\(monthName) \(String(year)) Transactions")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showAddTransaction) {
                ManualEntryView(restrictToYear: year, restrictToMonth: month)
            }
        }
    }
}
