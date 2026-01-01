import SwiftUI

struct ReviewDataView: View {
    let year: Int
    let month: Int
    @Environment(\.dismiss) var dismiss
    @StateObject private var transactionService = TransactionStorageService.shared
    @StateObject private var budgetService = BudgetService.shared
    @StateObject private var allocationService = AllocationService.shared
    @State private var showAddTransaction = false
    @State private var transactionToDelete: Transaction?
    @State private var showDeleteConfirmation = false

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
                    .id(transactionService.transactions.count)

                    // Transactions Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("All Transactions (\(monthTransactions.count))")
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
                                    SimpleTransactionRow(transaction: transaction)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        transactionToDelete = transaction
                                        showDeleteConfirmation = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
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
            .sheet(isPresented: $showAddTransaction) {
                RestrictedDateManualEntryView(year: year, month: month)
            }
            .alert("Delete Transaction", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    if let transaction = transactionToDelete {
                        deleteTransaction(transaction)
                    }
                }
            } message: {
                if let transaction = transactionToDelete {
                    Text(
                        "Are you sure you want to delete '\(transaction.title)' for $\(String(format: "%.2f", transaction.amount))? This cannot be undone."
                    )
                }
            }
        }
    }

    private func deleteTransaction(_ transaction: Transaction) {
        // Delete allocations first
        let allocations = allocationService.allocations.filter {
            $0.transactionId == transaction.id
        }
        for allocation in allocations {
            allocationService.deleteAllocation(allocationId: allocation.id)
        }

        // Delete transaction
        transactionService.deleteTransaction(id: transaction.id)

        print("✅ [ReviewData] Deleted transaction: \(transaction.title)")
    }
}

// MARK: - Restricted Date Manual Entry
struct RestrictedDateManualEntryView: View {
    let year: Int
    let month: Int

    @Environment(\.dismiss) var dismiss
    @StateObject private var storageService = TransactionStorageService.shared
    @StateObject private var budgetService = BudgetService.shared
    @StateObject private var allocationService = AllocationService.shared
    @StateObject private var backendService = BackendService.shared

    @State private var amount: String = ""
    @State private var title: String = ""
    @State private var date: Date = Date()
    @State private var isExpense: Bool = true
    @State private var allocations: [AllocationItem] = []
    @State private var showAddAllocation: Bool = false
    @State private var errorMessage: String = ""
    @State private var isSaving: Bool = false

    private var isFormValid: Bool {
        let hasAmount = !amount.isEmpty && Double(amount) != nil
        let hasTitle = !title.isEmpty
        let hasValidAllocations = isAllocationValid
        let isDateInCorrectMonth = isDateInMonth()

        return hasAmount && hasTitle && hasValidAllocations && isDateInCorrectMonth
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

    private func isDateInMonth() -> Bool {
        let calendar = Calendar.current
        let dateYear = calendar.component(.year, from: date)
        let dateMonth = calendar.component(.month, from: date)
        return dateYear == year && dateMonth == month
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Details")) {
                    HStack {
                        Text("$")
                            .foregroundColor(.secondary)
                        TextField("0.00", text: $amount)
                            .keyboardType(.decimalPad)
                            .onChange(of: amount) { newValue in
                                let filtered = newValue.filter { "0123456789.".contains($0) }
                                if filtered.filter({ $0 == "." }).count > 1 {
                                    amount = String(filtered.dropLast())
                                } else {
                                    amount = filtered
                                }
                            }
                    }

                    TextField("Title/Merchant", text: $title)
                        .autocapitalization(.words)

                    DatePicker("Date", selection: $date, displayedComponents: [.date])

                    if !isDateInMonth() {
                        Text("⚠️ Date must be in \(monthName) \(String(year))")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

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
                                })
                        }
                    }

                    Button(action: { showAddAllocation = true }) {
                        Label("Add Allocation", systemImage: "plus.circle.fill")
                            .foregroundColor(.blue)
                    }
                }

                // Error Message
                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                Section {
                    Button(action: saveTransaction) {
                        HStack {
                            Spacer()
                            if isSaving {
                                ProgressView()
                                Text("Saving...")
                                    .fontWeight(.semibold)
                            } else {
                                Text("Save Transaction")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(!isFormValid || isSaving)
                }
            }
            .navigationTitle("Add Transaction")
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
            .onAppear {
                // Set default date to first day of the month
                let calendar = Calendar.current
                if let firstDay = calendar.date(
                    from: DateComponents(year: year, month: month, day: 1))
                {
                    date = firstDay
                }
            }
        }
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

        guard isDateInMonth() else {
            showErrorAlert("Transaction date must be in \(monthName) \(year)")
            return
        }

        isSaving = true

        let newTransaction = Transaction(
            id: "",
            amount: amountValue,
            date: date,
            title: title,
            isExpense: isExpense,
            timestamp: Date()
        )

        Task {
            do {
                // Save to Firestore first to get the real ID
                let firestoreId = try await backendService.createTransaction(newTransaction)

                await MainActor.run {
                    // Update transaction with Firestore ID
                    let transactionWithId = Transaction(
                        id: firestoreId,
                        amount: amountValue,
                        date: date,
                        title: title,
                        isExpense: isExpense,
                        timestamp: newTransaction.timestamp
                    )

                    // Save to local storage
                    storageService.saveTransaction(transactionWithId)

                    // Create allocations with the real transaction ID
                    for allocation in allocations {
                        _ = allocationService.createAllocation(
                            transactionId: firestoreId,
                            destinationType: allocation.destinationType,
                            destinationId: allocation.destinationId,
                            amount: allocation.amount,
                            isExpense: isExpense
                        )
                    }

                    print(
                        "✅ [ReviewData] Created transaction: \(title) - $\(amountValue) (ID: \(firestoreId))"
                    )

                    isSaving = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    showErrorAlert("Failed to save transaction: \(error.localizedDescription)")
                    isSaving = false
                }
            }
        }
    }

    private func showErrorAlert(_ message: String) {
        errorMessage = message
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
