import SwiftUI

struct FundDetailView: View {
    let fund: Fund

    @StateObject private var fundService = FundService.shared
    @StateObject private var allocationService = AllocationService.shared
    @StateObject private var storageService = TransactionStorageService.shared

    @State private var showEditFund = false
    @State private var showDeleteConfirmation = false

    @Environment(\.dismiss) var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // MARK: - Header
                VStack(spacing: 12) {
                    Image(systemName: fund.icon)
                        .font(.system(size: 60))
                        .foregroundColor(.green)

                    Text(fund.name)
                        .font(.title)
                        .fontWeight(.bold)

                    if !fund.description.isEmpty {
                        Text(fund.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    // Balance
                    VStack(spacing: 4) {
                        Text("Current Balance")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("$\(String(format: "%.2f", fund.balance))")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.green)
                    }
                    .padding(.vertical, 8)

                    // Goal Progress
                    if let goal = fund.goal {
                        VStack(spacing: 8) {
                            HStack {
                                Text("Goal: $\(String(format: "%.0f", goal))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                Spacer()

                                if fund.isGoalMet() {
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                        Text("Goal Met!")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.green)
                                    }
                                } else if let remaining = fund.remainingToGoal() {
                                    Text("$\(String(format: "%.2f", remaining)) to go")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }

                            if let progressRatio = fund.progressRatio() {
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(height: 12)
                                            .cornerRadius(6)

                                        Rectangle()
                                            .fill(fund.isGoalMet() ? Color.green : Color.blue)
                                            .frame(
                                                width: geometry.size.width * CGFloat(progressRatio),
                                                height: 12
                                            )
                                            .cornerRadius(6)
                                    }
                                }
                                .frame(height: 12)
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Deadline
                    if let deadline = fund.deadline {
                        HStack {
                            Image(systemName: "calendar")
                            Text("Deadline: \(formattedDate(deadline))")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)

                // MARK: - Transaction History
                VStack(alignment: .leading, spacing: 12) {
                    Text("Transaction History")
                        .font(.headline)
                        .padding(.horizontal)

                    let allocations = getFundAllocations()

                    if allocations.isEmpty {
                        Text("No transactions yet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    } else {
                        ForEach(allocations) { allocation in
                            if let transaction = getTransaction(for: allocation) {
                                AllocationTransactionRow(
                                    transaction: transaction, allocation: allocation)
                            }
                        }
                    }
                }
                .padding(.vertical)

                // MARK: - Actions
                VStack(spacing: 12) {
                    Button(action: {
                        showEditFund = true
                    }) {
                        HStack {
                            Image(systemName: "pencil")
                            Text("Edit Fund")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }

                    Button(action: {
                        showDeleteConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Fund")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Fund Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEditFund) {
            EditFundView(fund: fund)
        }
        .alert("Delete Fund?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteFund()
            }
        } message: {
            if fund.balance > 0 {
                Text(
                    "This fund has a balance of $\(String(format: "%.2f", fund.balance)). Deleting it will remove the fund but keep transaction history."
                )
            } else {
                Text("Are you sure you want to delete this fund?")
            }
        }
    }

    private func getFundAllocations() -> [TransactionAllocation] {
        return allocationService.getAllocationsForDestination(
            destinationType: .fund, destinationId: fund.id
        ).sorted { $0.allocatedAt > $1.allocatedAt }
    }

    private func getTransaction(for allocation: TransactionAllocation) -> Transaction? {
        return storageService.transactions.first { $0.id == allocation.transactionId }
    }

    private func deleteFund() {
        fundService.deleteFund(fundId: fund.id)
        dismiss()
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Edit Fund View

struct EditFundView: View {
    let fund: Fund

    @Environment(\.dismiss) var dismiss
    @StateObject private var fundService = FundService.shared

    @State private var name: String
    @State private var description: String
    @State private var icon: String
    @State private var hasGoal: Bool
    @State private var goal: String
    @State private var hasDeadline: Bool
    @State private var deadline: Date

    init(fund: Fund) {
        self.fund = fund
        _name = State(initialValue: fund.name)
        _description = State(initialValue: fund.description)
        _icon = State(initialValue: fund.icon)
        _hasGoal = State(initialValue: fund.goal != nil)
        _goal = State(initialValue: fund.goal != nil ? String(format: "%.0f", fund.goal!) : "")
        _hasDeadline = State(initialValue: fund.deadline != nil)
        _deadline = State(initialValue: fund.deadline ?? Date())
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Fund Details")) {
                    TextField("Name", text: $name)
                    TextField("Description (optional)", text: $description)

                    NavigationLink(destination: IconPickerView(selectedIcon: $icon)) {
                        HStack {
                            Text("Icon")
                            Spacer()
                            Image(systemName: icon)
                                .foregroundColor(.green)
                        }
                    }
                }

                Section(header: Text("Goal (Optional)")) {
                    Toggle("Set Goal", isOn: $hasGoal)

                    if hasGoal {
                        HStack {
                            Text("$")
                                .foregroundColor(.secondary)
                            TextField("0.00", text: $goal)
                                .keyboardType(.decimalPad)
                        }
                    }
                }

                Section(header: Text("Deadline (Optional)")) {
                    Toggle("Set Deadline", isOn: $hasDeadline)

                    if hasDeadline {
                        DatePicker(
                            "Deadline",
                            selection: $deadline,
                            displayedComponents: [.date]
                        )
                    }
                }
            }
            .navigationTitle("Edit Fund")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveFund()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }

    private func saveFund() {
        let goalValue = hasGoal ? Double(goal) : nil
        let deadlineValue = hasDeadline ? deadline : nil

        fundService.updateFund(
            fundId: fund.id,
            name: name,
            icon: icon,
            description: description,
            goal: goalValue,
            deadline: deadlineValue
        )

        dismiss()
    }
}

// MARK: - Allocation Transaction Row

struct AllocationTransactionRow: View {
    let transaction: Transaction
    let allocation: TransactionAllocation

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.title)
                    .font(.body)

                Text(formattedDate(transaction.date))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(
                "\(transaction.isExpense ? "-" : "+")$\(String(format: "%.2f", allocation.amount))"
            )
            .font(.body)
            .fontWeight(.medium)
            .foregroundColor(transaction.isExpense ? .red : .green)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .padding(.horizontal)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Preview

struct FundDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            FundDetailView(
                fund: Fund(
                    id: "test",
                    name: "Emergency Fund",
                    icon: "dollarsign.circle",
                    description: "For unexpected expenses",
                    balance: 1500.0,
                    goal: 3000.0,
                    deadline: Date(),
                    createdAt: Date(),
                    isActive: true
                ))
        }
    }
}
