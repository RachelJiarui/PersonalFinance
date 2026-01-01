import SwiftUI

struct CoverDeficitsView: View {
    let stats: MonthWrappedStats
    @Binding var categoryBalances: [CategoryBalance]
    @StateObject private var fundService = FundService.shared
    @StateObject private var debtService = DebtService.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Cover Deficits")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.horizontal)

                Text(
                    "You overspent in these categories. Cover the difference from Funds or create/add to Debt."
                )
                .font(.body)
                .foregroundColor(.secondary)
                .padding(.horizontal)

                let deficitCategories = stats.categoriesWithDeficits

                if deficitCategories.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.green)

                        Text("No overspending this month")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else {
                    ForEach(deficitCategories, id: \.category.id) { deficit in
                        if let index = categoryBalances.firstIndex(where: {
                            $0.category.id == deficit.category.id
                        }) {
                            DeficitAllocationCard(
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

struct DeficitAllocationCard: View {
    @Binding var balance: CategoryBalance
    let funds: [Fund]
    let debts: [Debt]

    @State private var selectedType: AllocationType = .fund
    @State private var selectedId: String = ""
    @State private var showInsufficientFundsAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: balance.category.icon)
                    .foregroundColor(.orange)
                Text(balance.category.name)
                    .font(.headline)
                Spacer()
                Text("$\(String(format: "%.2f", balance.deficit))")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
            }

            Picker("Cover from", selection: $selectedType) {
                Text("Fund").tag(AllocationType.fund)
                Text("Debt").tag(AllocationType.debt)
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: selectedType) { _ in
                selectedId = ""
                balance.allocatedTo = nil
            }

            if selectedType == .fund {
                Text("Withdraw from Fund:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                ForEach(funds) { fund in
                    Button(action: {
                        // Check if fund has sufficient balance
                        if fund.balance >= balance.deficit {
                            selectedId = fund.id
                            balance.allocatedTo = BalancingDestination(
                                type: .existingFund(fund.id),
                                amount: balance.deficit
                            )
                        } else {
                            showInsufficientFundsAlert = true
                        }
                    }) {
                        HStack {
                            Image(systemName: fund.icon)
                                .foregroundColor(.green)
                            VStack(alignment: .leading) {
                                Text(fund.name)
                                Text("Balance: $\(String(format: "%.2f", fund.balance))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
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
                Text("Add to Debt:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                ForEach(debts) { debt in
                    Button(action: {
                        selectedId = debt.id
                        balance.allocatedTo = BalancingDestination(
                            type: .existingDebt(debt.id),
                            amount: balance.deficit
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
                    Text("Fully Covered")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
        .alert("Insufficient Funds", isPresented: $showInsufficientFundsAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(
                "This fund doesn't have enough balance to cover the deficit. Please choose another fund or create a debt."
            )
        }
    }
}
