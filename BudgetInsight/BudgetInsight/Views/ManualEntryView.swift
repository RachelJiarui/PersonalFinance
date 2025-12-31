import SwiftUI

struct AllocationItem: Identifiable {
    let id = UUID()
    var destinationType: AllocationType
    var destinationId: String
    var amount: Double
}

struct ManualEntryView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var storageService = TransactionStorageService.shared
    @StateObject private var budgetService = BudgetService.shared
    @StateObject private var fundService = FundService.shared
    @StateObject private var debtService = DebtService.shared
    @StateObject private var allocationService = AllocationService.shared
    @StateObject private var backendService = BackendService.shared

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
                                Text("Add Transaction")
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
        // Create default allocation if amount is set
        if !amount.isEmpty, let amountValue = Double(amount), allocations.isEmpty {
            // Default to first active category if available
            if let firstCategory = budgetService.getActiveCategories().first {
                allocations.append(
                    AllocationItem(
                        destinationType: .category,
                        destinationId: firstCategory.id,
                        amount: amountValue
                    )
                )
            }
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

        // Create new transaction with empty ID (Firestore will generate)
        var transaction = Transaction(
            id: "",  // Firestore auto-generates
            amount: amountValue,
            date: date,
            title: title,
            isExpense: isExpense,
            timestamp: Date()
        )

        // Save to backend first
        Task {
            do {
                // Create in Firestore and get generated ID
                let firestoreId = try await backendService.createTransaction(transaction)

                // Update transaction with real ID
                transaction.id = firestoreId

                // Save locally
                storageService.saveTransaction(transaction)

                // Create allocations
                for allocation in allocations {
                    _ = allocationService.createAllocation(
                        transactionId: firestoreId,
                        destinationType: allocation.destinationType,
                        destinationId: allocation.destinationId,
                        amount: allocation.amount,
                        isExpense: isExpense
                    )
                }

                // Update category spending (instant UI update)
                await MainActor.run {
                    budgetService.updateCategorySpending(with: storageService.transactions)

                    // Update snapshots
                    if let monthlyTakeHome = budgetService.userIncome?.monthlyTakeHome {
                        SnapshotService.shared.updateSnapshotsIfNeeded(
                            monthlyTakeHome: monthlyTakeHome,
                            transactions: storageService.transactions
                        )
                    }

                    print(
                        "✅ [ManualEntry] Saved transaction to Firestore: \(title) - $\(amountValue) (ID: \(firestoreId))"
                    )

                    isSaving = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    showErrorAlert("Failed to save transaction: \(error.localizedDescription)")
                    print("❌ [ManualEntry] Error saving to Firestore: \(error)")
                }
            }
        }
    }

    private func showErrorAlert(_ message: String) {
        errorMessage = message
        showError = true
    }
}

// MARK: - Allocation Row

struct AllocationRow: View {
    let allocation: AllocationItem
    let onDelete: () -> Void

    @StateObject private var budgetService = BudgetService.shared
    @StateObject private var fundService = FundService.shared
    @StateObject private var debtService = DebtService.shared

    var body: some View {
        HStack {
            Image(systemName: destinationIcon)
                .foregroundColor(destinationColor)
                .frame(width: 30)

            VStack(alignment: .leading) {
                Text(destinationName)
                    .font(.body)
                Text(allocation.destinationType.rawValue.capitalized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("$\(String(format: "%.2f", allocation.amount))")
                .fontWeight(.medium)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(BorderlessButtonStyle())
        }
    }

    private var destinationName: String {
        switch allocation.destinationType {
        case .category:
            return budgetService.getCategoryById(allocation.destinationId)?.name ?? "Unknown"
        case .fund:
            return fundService.getFundById(allocation.destinationId)?.name ?? "Unknown"
        case .debt:
            return debtService.getDebtById(allocation.destinationId)?.name ?? "Unknown"
        }
    }

    private var destinationIcon: String {
        switch allocation.destinationType {
        case .category:
            return budgetService.getCategoryById(allocation.destinationId)?.icon ?? "questionmark"
        case .fund:
            return fundService.getFundById(allocation.destinationId)?.icon ?? "dollarsign.circle"
        case .debt:
            return debtService.getDebtById(allocation.destinationId)?.icon ?? "creditcard"
        }
    }

    private var destinationColor: Color {
        switch allocation.destinationType {
        case .category:
            return .blue
        case .fund:
            return .green
        case .debt:
            return .orange
        }
    }
}

// MARK: - Add Allocation View

struct AddAllocationView: View {
    @Environment(\.dismiss) var dismiss

    let transactionAmount: Double
    let currentAllocations: [AllocationItem]
    let isExpense: Bool  // New parameter to determine transaction type
    let onAdd: (AllocationItem) -> Void

    @StateObject private var budgetService = BudgetService.shared
    @StateObject private var fundService = FundService.shared
    @StateObject private var debtService = DebtService.shared

    @State private var selectedType: AllocationType = .category
    @State private var selectedDestinationId: String = ""
    @State private var amount: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Destination Type")) {
                    Picker("Type", selection: $selectedType) {
                        Text("Category").tag(AllocationType.category)
                        Text("Fund").tag(AllocationType.fund)
                        Text("Debt").tag(AllocationType.debt)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: selectedType) { _ in
                        selectedDestinationId = ""
                    }
                }

                Section(header: Text("Select \(selectedType.rawValue.capitalized)")) {
                    ForEach(availableDestinations, id: \.id) { destination in
                        Button(action: {
                            selectedDestinationId = destination.id
                        }) {
                            HStack {
                                Image(systemName: destination.icon)
                                    .foregroundColor(typeColor)
                                    .frame(width: 30)
                                Text(destination.name)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedDestinationId == destination.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }

                    if availableDestinations.isEmpty {
                        Text("No \(selectedType.rawValue)s available")
                            .foregroundColor(.secondary)
                    }
                }

                Section(header: Text("Amount")) {
                    HStack {
                        Text("$")
                            .foregroundColor(.secondary)
                        TextField("0.00", text: $amount)
                            .keyboardType(.decimalPad)
                    }
                }

                if remainingAmount > 0 {
                    Section {
                        Text(
                            "Remaining to allocate: $\(String(format: "%.2f", remainingAmount))"
                        )
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }

                if let message = validationMessage {
                    Section {
                        Text(message)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Add Allocation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addAllocation()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                // Auto-select first available destination
                if let first = availableDestinations.first {
                    selectedDestinationId = first.id
                }

                // Pre-fill with remaining amount
                if currentAllocations.isEmpty {
                    amount = String(format: "%.2f", transactionAmount)
                }
            }
        }
    }

    private var remainingAmount: Double {
        let totalAllocated = currentAllocations.reduce(0.0) { $0 + $1.amount }
        return transactionAmount - totalAllocated
    }

    private var isValid: Bool {
        guard !selectedDestinationId.isEmpty,
            let amountValue = Double(amount),
            amountValue > 0
        else {
            return false
        }

        // For income transactions to categories, check against category spending
        if !isExpense && selectedType == .category {
            let categorySpending = budgetService.categorySpending[selectedDestinationId] ?? 0.0
            // Can't reimburse more than what was spent
            return amountValue <= categorySpending
        }

        return true
    }

    private var validationMessage: String? {
        guard !isExpense && selectedType == .category,
            let amountValue = Double(amount),
            amountValue > 0,
            !selectedDestinationId.isEmpty
        else {
            return nil
        }

        let categorySpending = budgetService.categorySpending[selectedDestinationId] ?? 0.0
        if amountValue > categorySpending {
            return
                "Cannot reimburse $\(String(format: "%.2f", amountValue)) to a category with only $\(String(format: "%.2f", categorySpending)) spent"
        }

        return nil
    }

    private var typeColor: Color {
        switch selectedType {
        case .category: return .blue
        case .fund: return .green
        case .debt: return .orange
        }
    }

    private var availableDestinations: [(id: String, name: String, icon: String)] {
        let alreadyAllocatedIds =
            currentAllocations
            .filter { $0.destinationType == selectedType }
            .map { $0.destinationId }

        switch selectedType {
        case .category:
            return budgetService.getActiveCategories()
                .filter { category in
                    // Basic filters
                    guard !category.id.isEmpty && !alreadyAllocatedIds.contains(category.id) else {
                        return false
                    }

                    // For income transactions, only show categories with spending > 0
                    if !isExpense {
                        let spending = budgetService.categorySpending[category.id] ?? 0.0
                        return spending > 0
                    }

                    return true
                }
                .map { (id: $0.id, name: $0.name, icon: $0.icon) }
        case .fund:
            return fundService.getActiveFunds()
                .filter { !$0.id.isEmpty && !alreadyAllocatedIds.contains($0.id) }
                .map { (id: $0.id, name: $0.name, icon: $0.icon) }
        case .debt:
            return debtService.getActiveDebts()
                .filter { !$0.id.isEmpty && !alreadyAllocatedIds.contains($0.id) }
                .map { (id: $0.id, name: $0.name, icon: $0.icon) }
        }
    }

    private func addAllocation() {
        guard let amountValue = Double(amount) else { return }

        let allocation = AllocationItem(
            destinationType: selectedType,
            destinationId: selectedDestinationId,
            amount: amountValue
        )

        onAdd(allocation)
        dismiss()
    }
}

// MARK: - Preview

struct ManualEntryView_Previews: PreviewProvider {
    static var previews: some View {
        ManualEntryView()
    }
}
