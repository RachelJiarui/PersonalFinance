import SwiftUI

struct TransactionRowView: View {
    let transaction: Transaction
    let budgetService: BudgetService
    let allocationService: AllocationService

    @StateObject private var fundService = FundService.shared
    @StateObject private var debtService = DebtService.shared

    var body: some View {
        HStack(spacing: 12) {
            // Income/Expense Icon
            ZStack {
                Circle()
                    .fill(transaction.isExpense ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
                    .frame(width: 40, height: 40)

                Image(
                    systemName: transaction.isExpense
                        ? "arrow.down.circle.fill" : "arrow.up.circle.fill"
                )
                .foregroundColor(transaction.isExpense ? .red : .green)
                .font(.system(size: 20))
            }

            VStack(alignment: .leading, spacing: 4) {
                // Title
                Text(transaction.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)

                // Date
                Text(transaction.date, style: .date)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                // Allocations summary
                HStack(spacing: 4) {
                    ForEach(Array(allocationParts.enumerated()), id: \.offset) { index, part in
                        HStack(spacing: 4) {
                            Image(systemName: part.icon)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Text(part.name)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)

                            if index < allocationParts.count - 1 {
                                Text("•")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .lineLimit(1)
            }

            Spacer()

            // Amount
            Text(
                transaction.isExpense
                    ? "-$\(transaction.amount, specifier: "%.2f")"
                    : "+$\(transaction.amount, specifier: "%.2f")"
            )
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(transaction.isExpense ? .red : .green)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }

    private var allocationParts: [(icon: String, name: String)] {
        let allocations = allocationService.allocations.filter {
            $0.transactionId == transaction.id
        }

        if allocations.isEmpty {
            return [(icon: "questionmark.circle", name: "No allocation")]
        }

        return allocations.compactMap { allocation -> (icon: String, name: String)? in
            let icon: String
            let name: String

            switch allocation.destinationType {
            case .category:
                guard let category = budgetService.getCategoryById(allocation.destinationId) else {
                    return (icon: "questionmark.circle", name: "Unknown Category")
                }
                icon = category.icon
                name = category.name
            case .fund:
                // Access all funds directly (includes inactive)
                guard
                    let fund = fundService.funds.first(where: { $0.id == allocation.destinationId })
                else {
                    return (icon: "dollarsign.circle", name: "Unknown Fund")
                }
                icon = fund.icon
                name = fund.name
            case .debt:
                // Access all debts directly (includes inactive)
                guard
                    let debt = debtService.debts.first(where: { $0.id == allocation.destinationId })
                else {
                    return (icon: "creditcard", name: "Unknown Debt")
                }
                icon = debt.icon
                name = debt.name
            }

            return (icon: icon, name: name)
        }
    }
}
