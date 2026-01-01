import SwiftUI

struct DebtDetailView: View {
    let debt: Debt

    @StateObject private var debtService = DebtService.shared
    @StateObject private var allocationService = AllocationService.shared
    @StateObject private var storageService = TransactionStorageService.shared
    @StateObject private var backendService = BackendService.shared

    @State private var showEditDebt = false
    @State private var showDeleteConfirmation = false
    @State private var showAllocateBalance = false

    @Environment(\.dismiss) var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // MARK: - Header
                VStack(spacing: 12) {
                    Image(systemName: debt.icon)
                        .font(.system(size: 60))
                        .foregroundColor(.orange)

                    Text(debt.name)
                        .font(.title)
                        .fontWeight(.bold)

                    if !debt.description.isEmpty {
                        Text(debt.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    // Balance
                    VStack(spacing: 4) {
                        Text("Amount Owed")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("$\(String(format: "%.2f", debt.balance))")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(debt.isPaidOff() ? .green : .orange)
                    }
                    .padding(.vertical, 8)

                    // Payoff Progress
                    VStack(spacing: 8) {
                        HStack {
                            Text("Total to Pay: $\(String(format: "%.0f", debt.goal))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Spacer()

                            if debt.isPaidOff() {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Paid Off!")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.green)
                                }
                            } else {
                                Text("$\(String(format: "%.2f", debt.remainingToPay())) left")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }

                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 12)
                                    .cornerRadius(6)

                                Rectangle()
                                    .fill(debt.isPaidOff() ? Color.green : Color.orange)
                                    .frame(
                                        width: geometry.size.width * CGFloat(debt.progressRatio()),
                                        height: 12
                                    )
                                    .cornerRadius(6)
                            }
                        }
                        .frame(height: 12)

                        Text(
                            "\(Int(debt.progressRatio() * 100))% paid off"
                        )
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)

                    // Deadline
                    if let deadline = debt.deadline {
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
                    Text("Payment History")
                        .font(.headline)
                        .padding(.horizontal)

                    let allocations = getDebtAllocations()

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
                if !debt.isDefault {
                    VStack(spacing: 12) {
                        Button(action: {
                            showEditDebt = true
                        }) {
                            HStack {
                                Image(systemName: "pencil")
                                Text("Edit Debt")
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
                                Text("Delete Debt")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .foregroundColor(.red)
                            .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)
                } else {
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.blue)
                            Text("This is a default debt")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        Text("Default debts cannot be edited or deleted")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Debt Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEditDebt) {
            EditDebtView(debt: debt)
        }
        .sheet(isPresented: $showAllocateBalance) {
            AllocateBalanceView(
                balanceAmount: debt.balance,
                balanceType: "Debt",
                sourceName: debt.name,
                sourceId: debt.id,
                onComplete: { allocations in
                    handleBalanceAllocation(allocations)
                }
            )
        }
        .alert("Delete Debt?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            if debt.balance > 0 {
                Button("Continue", role: .none) {
                    showAllocateBalance = true
                }
            } else {
                Button("Delete", role: .destructive) {
                    deleteDebt()
                }
            }
        } message: {
            if debt.balance > 0 {
                Text(
                    "This debt has a balance of $\(String(format: "%.2f", debt.balance)). You must allocate this debt before deleting."
                )
            } else {
                Text("Are you sure you want to delete this debt?")
            }
        }
    }

    private func getDebtAllocations() -> [TransactionAllocation] {
        return allocationService.getAllocationsForDestination(
            destinationType: .debt, destinationId: debt.id
        ).sorted { $0.allocatedAt > $1.allocatedAt }
    }

    private func getTransaction(for allocation: TransactionAllocation) -> Transaction? {
        return storageService.transactions.first { $0.id == allocation.transactionId }
    }

    private func handleBalanceAllocation(_ allocations: [AllocationItem]) {
        // Create a transaction to represent the debt balance transfer
        // Debt balance represents money OWED, so paying it off is an expense
        let transaction = Transaction(
            id: "",
            amount: debt.balance,
            date: Date(),
            title: "Transfer from \(debt.name) (Deleted)",
            isExpense: true,  // Expense - using money from destinations to pay off debt
            timestamp: Date()
        )

        // Save transaction to backend
        Task {
            do {
                let firestoreId = try await backendService.createTransaction(transaction)

                // Save locally
                storageService.saveTransaction(
                    Transaction(
                        id: firestoreId,
                        amount: transaction.amount,
                        date: transaction.date,
                        title: transaction.title,
                        isExpense: transaction.isExpense,
                        timestamp: transaction.timestamp
                    )
                )

                // Create allocations - use same isExpense as transaction
                for allocation in allocations {
                    _ = allocationService.createAllocation(
                        transactionId: firestoreId,
                        destinationType: allocation.destinationType,
                        destinationId: allocation.destinationId,
                        amount: allocation.amount,
                        isExpense: true  // Expense - redistributing debt balance subtracts from destinations
                    )
                }

                await MainActor.run {
                    // Now delete the debt
                    debtService.deleteDebt(debtId: debt.id)
                    dismiss()
                }
            } catch {
                print("❌ [DebtDetailView] Error saving allocation transaction: \(error)")
            }
        }
    }

    private func deleteDebt() {
        debtService.deleteDebt(debtId: debt.id)
        dismiss()
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Edit Debt View

struct EditDebtView: View {
    let debt: Debt

    @Environment(\.dismiss) var dismiss
    @StateObject private var debtService = DebtService.shared

    @State private var name: String
    @State private var description: String
    @State private var icon: String
    @State private var goal: String
    @State private var hasDeadline: Bool
    @State private var deadline: Date

    init(debt: Debt) {
        self.debt = debt
        _name = State(initialValue: debt.name)
        _description = State(initialValue: debt.description)
        _icon = State(initialValue: debt.icon)
        _goal = State(initialValue: String(format: "%.0f", debt.goal))
        _hasDeadline = State(initialValue: debt.deadline != nil)
        _deadline = State(initialValue: debt.deadline ?? Date())
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Debt Details")) {
                    TextField("Name", text: $name)
                    TextField("Description (optional)", text: $description)

                    NavigationLink(destination: IconPickerView(selectedIcon: $icon)) {
                        HStack {
                            Text("Icon")
                            Spacer()
                            Image(systemName: icon)
                                .foregroundColor(.orange)
                        }
                    }
                }

                Section(header: Text("Total to Pay Off")) {
                    HStack {
                        Text("$")
                            .foregroundColor(.secondary)
                        TextField("0.00", text: $goal)
                            .keyboardType(.decimalPad)
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

                Section {
                    HStack {
                        Text("Current Balance:")
                        Spacer()
                        Text("$\(String(format: "%.2f", debt.balance))")
                            .foregroundColor(.secondary)
                    }

                    Text("Balance decreases as you allocate income transactions to this debt.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Edit Debt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveDebt()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private var isValid: Bool {
        !name.isEmpty && Double(goal) != nil
    }

    private func saveDebt() {
        guard let goalValue = Double(goal) else { return }

        let deadlineValue = hasDeadline ? deadline : nil

        debtService.updateDebt(
            debtId: debt.id,
            name: name,
            icon: icon,
            description: description,
            goal: goalValue,
            deadline: deadlineValue
        )

        dismiss()
    }
}

// MARK: - Preview

struct DebtDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            DebtDetailView(
                debt: Debt(
                    id: "test",
                    name: "Furniture",
                    icon: "creditcard",
                    description: "New apartment furniture",
                    balance: 800.0,
                    goal: 1200.0,
                    deadline: Date(),
                    createdAt: Date(),
                    isActive: true
                ))
        }
    }
}
