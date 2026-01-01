import SwiftUI

struct EditTransactionView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var storageService = TransactionStorageService.shared
    @StateObject private var budgetService = BudgetService.shared
    @StateObject private var fundService = FundService.shared
    @StateObject private var debtService = DebtService.shared
    @StateObject private var allocationService = AllocationService.shared
    @StateObject private var backendService = BackendService.shared

    let originalTransaction: Transaction
    let originalAllocations: [TransactionAllocation]

    // Form fields matching Transaction model
    @State private var amount: String = ""
    @State private var title: String = ""
    @State private var date: Date = Date()
    @State private var isExpense: Bool = true

    // Allocation management
    @State private var allocations: [AllocationItem] = []
    @State private var showAddAllocation: Bool = false

    // UI state
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var isSaving: Bool = false

    var body: some View {
        NavigationView {
            Form {
                // MARK: - Transaction Details
                Section(header: Text("Details")) {
                    // Amount (numbers and decimal only)
                    HStack {
                        Text("$")
                            .foregroundColor(.secondary)
                        TextField("0.00", text: $amount)
                            .keyboardType(.decimalPad)
                            .onChange(of: amount) { newValue in
                                // Filter to only allow numbers and one decimal point
                                let filtered = newValue.filter { "0123456789.".contains($0) }
                                if filtered.filter({ $0 == "." }).count > 1 {
                                    // Only allow one decimal point
                                    amount = String(filtered.dropLast())
                                } else {
                                    amount = filtered
                                }
                            }
                    }

                    // Title (merchant/description)
                    TextField("Title/Merchant", text: $title)
                        .autocapitalization(.words)

                    // Date (Apple-style date picker)
                    DatePicker(
                        "Date",
                        selection: $date,
                        displayedComponents: [.date]
                    )
                }

                // MARK: - Transaction Type (Checkbox style)
                Section(header: Text("Type")) {
                    Toggle(isOn: $isExpense) {
                        HStack {
                            Image(
                                systemName: isExpense
                                    ? "arrow.up.circle.fill" : "arrow.down.circle.fill"
                            )
                            .foregroundColor(isExpense ? .red : .green)
                            Text(isExpense ? "Expense" : "Income")
                                .fontWeight(.medium)
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: isExpense ? .red : .green))
                }

                // MARK: - Allocations
                Section(
                    header: HStack {
                        Text("Allocations")
                        Spacer()
                        Text(allocationStatusText)
                            .font(.caption)
                            .foregroundColor(isAllocationValid ? .green : .orange)
                    }
                ) {
                    if allocations.isEmpty {
                        Text("No allocations yet. Add at least one allocation.")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    } else {
                        ForEach(allocations) { allocation in
                            AllocationRow(
                                allocation: allocation,
                                onDelete: {
                                    deleteAllocation(allocation)
                                }
                            )
                        }
                    }

                    Button(action: {
                        showAddAllocation = true
                    }) {
                        Label("Add Allocation", systemImage: "plus.circle.fill")
                            .foregroundColor(.blue)
                    }
                }

                // MARK: - Save Button
                Section {
                    Button(action: saveTransaction) {
                        HStack {
                            Spacer()
                            if isSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                Text("Saving...")
                                    .fontWeight(.semibold)
                            } else {
                                Text("Save Changes")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(!isFormValid || isSaving)
                }
            }
            .navigationTitle("Edit Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
            }
            .sheet(isPresented: $showAddAllocation) {
                AddAllocationView(
                    transactionAmount: Double(amount) ?? 0.0,
                    currentAllocations: allocations,
                    isExpense: isExpense,
                    transactionDate: date,
                    onAdd: { newAllocation in
                        allocations.append(newAllocation)
                    }
                )
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                loadData()
            }
        }
    }

    // MARK: - Computed Properties

    private var isFormValid: Bool {
        let hasAmount = !amount.isEmpty && Double(amount) != nil
        let hasTitle = !title.isEmpty
        let hasValidAllocations = isAllocationValid

        return hasAmount && hasTitle && hasValidAllocations
    }

    private var isAllocationValid: Bool {
        guard let amountValue = Double(amount), amountValue > 0 else {
            return false
        }

        let totalAllocated = allocations.reduce(0.0) { $0 + $1.amount }
        return abs(totalAllocated - amountValue) < 0.01
    }

    private var allocationStatusText: String {
        guard let amountValue = Double(amount), amountValue > 0 else {
            return ""
        }

        let totalAllocated = allocations.reduce(0.0) { $0 + $1.amount }
        let remaining = amountValue - totalAllocated

        if abs(remaining) < 0.01 {
            return "✓ Fully Allocated"
        } else if remaining > 0 {
            return "$\(String(format: "%.2f", remaining)) remaining"
        } else {
            return "$\(String(format: "%.2f", abs(remaining))) over"
        }
    }

    // MARK: - Methods

    private func loadData() {
        // Pre-fill form with current transaction data
        amount = String(format: "%.2f", originalTransaction.amount)
        title = originalTransaction.title
        date = originalTransaction.date
        isExpense = originalTransaction.isExpense

        // Convert existing allocations to AllocationItems
        allocations = originalAllocations.map { allocation in
            AllocationItem(
                destinationType: allocation.destinationType,
                destinationId: allocation.destinationId,
                amount: allocation.amount
            )
        }
    }

    private func deleteAllocation(_ allocation: AllocationItem) {
        allocations.removeAll { $0.id == allocation.id }
    }

    private func saveTransaction() {
        guard let amountValue = Double(amount) else {
            showErrorAlert("Please enter a valid amount")
            return
        }

        guard !allocations.isEmpty else {
            showErrorAlert("Please add at least one allocation")
            return
        }

        guard isAllocationValid else {
            showErrorAlert("Allocations must equal the transaction amount")
            return
        }

        isSaving = true

        Task {
            do {
                // Step 1: Calculate the differences to handle money correctly
                let oldAmount = originalTransaction.amount
                let newAmount = amountValue
                let oldIsExpense = originalTransaction.isExpense
                let newIsExpense = isExpense

                // Step 2: If amount or expense type changed, we need to reverse old allocations
                // and apply new ones to prevent double counting
                if oldAmount != newAmount || oldIsExpense != newIsExpense {
                    // Reverse all old allocations
                    for oldAllocation in originalAllocations {
                        reverseAllocationBalance(
                            allocation: oldAllocation,
                            isExpense: oldIsExpense
                        )
                    }

                    // Delete old allocations from Firestore and local
                    for oldAllocation in originalAllocations {
                        allocationService.deleteAllocation(allocationId: oldAllocation.id)
                    }

                    // Create new allocations with new amounts
                    for allocation in allocations {
                        _ = allocationService.createAllocation(
                            transactionId: originalTransaction.id,
                            destinationType: allocation.destinationType,
                            destinationId: allocation.destinationId,
                            amount: allocation.amount,
                            isExpense: newIsExpense
                        )
                    }
                } else {
                    // Amount and type unchanged - handle allocation differences
                    let oldAllocSet = Set(
                        originalAllocations.map {
                            "\($0.destinationType.rawValue):\($0.destinationId):\($0.amount)"
                        })
                    let newAllocSet = Set(
                        allocations.map {
                            "\($0.destinationType.rawValue):\($0.destinationId):\($0.amount)"
                        })

                    // Find allocations to delete (in old but not in new)
                    for oldAlloc in originalAllocations {
                        let key =
                            "\(oldAlloc.destinationType.rawValue):\(oldAlloc.destinationId):\(oldAlloc.amount)"
                        if !newAllocSet.contains(key) {
                            allocationService.deleteAllocation(allocationId: oldAlloc.id)
                        }
                    }

                    // Find allocations to add (in new but not in old)
                    for newAlloc in allocations {
                        let key =
                            "\(newAlloc.destinationType.rawValue):\(newAlloc.destinationId):\(newAlloc.amount)"
                        if !oldAllocSet.contains(key) {
                            _ = allocationService.createAllocation(
                                transactionId: originalTransaction.id,
                                destinationType: newAlloc.destinationType,
                                destinationId: newAlloc.destinationId,
                                amount: newAlloc.amount,
                                isExpense: newIsExpense
                            )
                        }
                    }
                }

                // Step 3: Update the transaction itself
                let dateFormatter = ISO8601DateFormatter()
                let updates: [String: Any] = [
                    "amount": amountValue,
                    "title": title,
                    "is_expense": isExpense,
                    "date": dateFormatter.string(from: date),
                ]

                // Update in Firestore
                try await backendService.updateTransaction(
                    transactionId: originalTransaction.id, updates: updates)

                // Step 4: Update local storage
                await MainActor.run {
                    if let index = storageService.transactions.firstIndex(where: {
                        $0.id == originalTransaction.id
                    }) {
                        let updatedTransaction = Transaction(
                            id: originalTransaction.id,
                            amount: amountValue,
                            date: date,
                            title: title,
                            isExpense: isExpense,
                            timestamp: originalTransaction.timestamp
                        )
                        storageService.transactions[index] = updatedTransaction
                        storageService.persistTransactions()
                    }

                    // Update category spending (instant UI update)
                    budgetService.updateCategorySpending(with: storageService.transactions)

                    // Update snapshots
                    if let monthlyTakeHome = budgetService.userIncome?.monthlyTakeHome {
                        SnapshotService.shared.updateSnapshotsIfNeeded(
                            monthlyTakeHome: monthlyTakeHome,
                            transactions: storageService.transactions
                        )
                    }

                    print(
                        "✅ [EditTransaction] Updated transaction in Firestore: \(title) - $\(amountValue) (ID: \(originalTransaction.id))"
                    )

                    isSaving = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    showErrorAlert("Failed to update transaction: \(error.localizedDescription)")
                    print("❌ [EditTransaction] Error updating transaction: \(error)")
                }
            }
        }
    }

    private func reverseAllocationBalance(
        allocation: TransactionAllocation, isExpense: Bool
    ) {
        // Reverse the balance change that was made when this allocation was created
        switch allocation.destinationType {
        case .category:
            // Categories are handled by BudgetService recalculation
            break

        case .fund:
            // Reverse: Income allocations added to fund, Expense allocations subtracted
            let adjustedAmount = isExpense ? allocation.amount : -allocation.amount
            FundService.shared.updateBalance(
                fundId: allocation.destinationId, amount: adjustedAmount)

        case .debt:
            // Reverse: Income allocations reduced debt, Expense allocations increased debt
            let adjustedAmount = isExpense ? -allocation.amount : allocation.amount
            DebtService.shared.updateBalance(
                debtId: allocation.destinationId, amount: adjustedAmount)
        }
    }

    private func showErrorAlert(_ message: String) {
        errorMessage = message
        showError = true
    }
}
