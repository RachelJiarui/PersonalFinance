import SwiftUI

struct AllocateSavingsView: View {
    let stats: MonthWrappedStats
    @Binding var categoryBalances: [CategoryBalance]
    @StateObject private var fundService = FundService.shared
    @StateObject private var debtService = DebtService.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Allocate Savings")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.horizontal)

                Text(
                    "You saved money in these categories. Choose to add them to Funds or pay off Debts."
                )
                .font(.body)
                .foregroundColor(.secondary)
                .padding(.horizontal)

                let surplusCategories = stats.categoriesWithSavings

                if surplusCategories.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.green)

                        Text("No savings this month")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else {
                    ForEach(categoryBalances.indices, id: \.self) { index in
                        if categoryBalances[index].surplus > 0 {
                            SavingsAllocationCard(
                                balance: $categoryBalances[index],
                                funds: fundService.getActiveFunds(),
                                debts: debtService.getActiveDebts()
                            )
                        }
                    }
                }
            }
            .padding(.vertical)
        }
    }
}

struct SavingsAllocationCard: View {
    @Binding var balance: CategoryBalance
    let funds: [Fund]
    let debts: [Debt]

    @State private var selectedType: AllocationType = .fund
    @State private var selectedId: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: balance.category.icon)
                    .foregroundColor(.green)
                Text(balance.category.name)
                    .font(.headline)
                Spacer()
                Text("$\(String(format: "%.2f", balance.surplus))")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }

            Picker("Allocate to", selection: $selectedType) {
                Text("Fund").tag(AllocationType.fund)
                Text("Debt").tag(AllocationType.debt)
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: selectedType) { _ in
                selectedId = ""
                balance.allocatedTo = nil
            }

            if selectedType == .fund {
                ForEach(funds) { fund in
                    Button(action: {
                        selectedId = fund.id
                        balance.allocatedTo = BalancingDestination(
                            type: .existingFund(fund.id),
                            amount: balance.surplus
                        )
                    }) {
                        HStack {
                            Image(systemName: fund.icon)
                                .foregroundColor(.green)
                            Text(fund.name)
                            Spacer()
                            if selectedId == fund.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .foregroundColor(.primary)
                }
            } else {
                ForEach(debts) { debt in
                    Button(action: {
                        selectedId = debt.id
                        balance.allocatedTo = BalancingDestination(
                            type: .existingDebt(debt.id),
                            amount: balance.surplus
                        )
                    }) {
                        HStack {
                            Image(systemName: debt.icon)
                                .foregroundColor(.orange)
                            Text(debt.name)
                            Spacer()
                            if selectedId == debt.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .foregroundColor(.primary)
                }
            }

            if balance.isFullyAllocated {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Fully Allocated")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}
