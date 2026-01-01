import SwiftUI

struct BalancingSummaryView: View {
    let stats: MonthWrappedStats
    let categoryBalances: [CategoryBalance]
    let onComplete: () -> Void
    @StateObject private var fundService = FundService.shared
    @StateObject private var debtService = DebtService.shared

    private var transactionsToCreate:
        [(category: String, destination: String, amount: Double, isSurplus: Bool)]
    {
        var transactions: [(String, String, Double, Bool)] = []

        for balance in categoryBalances {
            guard let destination = balance.allocatedTo else { continue }

            let isSurplus = balance.surplus > 0
            let amount = isSurplus ? balance.surplus : balance.deficit

            let destName: String
            switch destination.type {
            case .existingFund(let id):
                destName = fundService.getFundById(id)?.name ?? "Fund"
            case .newFund(let name, _, _):
                destName = name
            case .existingDebt(let id):
                destName = debtService.getDebtById(id)?.name ?? "Debt"
            case .newDebt(let name, _, _, _):
                destName = name
            }

            transactions.append((balance.category.name, destName, amount, isSurplus))
        }

        return transactions
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Summary")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.horizontal)

                Text("Review your allocations before completing the balancing process.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                // Transactions to Create
                VStack(alignment: .leading, spacing: 12) {
                    Text("Transactions to Create (\(transactionsToCreate.count))")
                        .font(.headline)
                        .padding(.horizontal)

                    ForEach(transactionsToCreate.indices, id: \.self) { index in
                        let tx = transactionsToCreate[index]
                        TransactionPreviewRow(
                            number: index + 1,
                            category: tx.category,
                            destination: tx.destination,
                            amount: tx.amount,
                            isSurplus: tx.isSurplus
                        )
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)
                .padding(.horizontal)

                // Warning
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("This cannot be undone")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text(
                            "Once you complete balancing, these transactions will be created and Fund/Debt balances will be updated."
                        )
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)

                // Completion Info
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("All balances accounted for")
                            .font(.headline)
                            .foregroundColor(.green)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()

                Spacer()
            }
            .padding(.vertical)
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: onComplete) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Complete Balancing")
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

struct TransactionPreviewRow: View {
    let number: Int
    let category: String
    let destination: String
    let amount: Double
    let isSurplus: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number).")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 20, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                if isSurplus {
                    Text("\(category) → \(destination)")
                        .font(.body)
                } else {
                    Text("\(destination) → \(category)")
                        .font(.body)
                }

                Text(isSurplus ? "Savings allocation" : "Deficit coverage")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("$\(String(format: "%.2f", amount))")
                .font(.headline)
                .foregroundColor(isSurplus ? .green : .orange)
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}
