import SwiftUI

struct FundDetailView: View {
    let fund: Fund

    @StateObject private var fundService = FundService.shared
    @StateObject private var allocationService = AllocationService.shared
    @StateObject private var storageService = TransactionStorageService.shared
    @StateObject private var backendService = BackendService.shared

    @State private var showEditFund = false
    @State private var showDeleteConfirmation = false
    @State private var showAllocateBalance = false

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
        .sheet(isPresented: $showAllocateBalance) {
            AllocateBalanceView(
                balanceAmount: fund.balance,
                balanceType: "Fund",
                sourceName: fund.name,
                sourceId: fund.id,
                onComplete: { allocations in
                    handleBalanceAllocation(allocations)
                }
            )
        }
        .alert("Delete Fund?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            if fund.balance > 0 {
                Button("Continue", role: .none) {
                    showAllocateBalance = true
                }
            } else {
                Button("Delete", role: .destructive) {
                    deleteFund()
                }
            }
        } message: {
            if fund.balance > 0 {
                Text(
                    "This fund has a balance of $\(String(format: "%.2f", fund.balance)). You must allocate this money before deleting."
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

    private func handleBalanceAllocation(_ allocations: [AllocationItem]) {
        // Create a transaction to represent the fund balance transfer
        let transaction = Transaction(
            id: "",
            amount: fund.balance,
            date: Date(),
            title: "Transfer from \(fund.name) (Deleted)",
            isExpense: false,  // It's income since we're moving money out
            timestamp: Date(),
            linkedEmailAlertId: nil
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
                        timestamp: transaction.timestamp,
                        linkedEmailAlertId: nil
                    )
                )

                // Create allocations
                for allocation in allocations {
                    _ = allocationService.createAllocation(
                        transactionId: firestoreId,
                        destinationType: allocation.destinationType,
                        destinationId: allocation.destinationId,
                        amount: allocation.amount
                    )
                }

                await MainActor.run {
                    // Now delete the fund
                    fundService.deleteFund(fundId: fund.id)
                    dismiss()
                }
            } catch {
                print("❌ [FundDetailView] Error saving allocation transaction: \(error)")
            }
        }
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

// MARK: - Allocate Balance View

struct AllocateBalanceView: View {
    @Environment(\.dismiss) var dismiss

    let balanceAmount: Double
    let balanceType: String  // "Fund" or "Debt"
    let sourceName: String
    let sourceId: String  // ID of the fund/debt being deleted
    let onComplete: ([AllocationItem]) -> Void

    @StateObject private var budgetService = BudgetService.shared
    @StateObject private var fundService = FundService.shared
    @StateObject private var debtService = DebtService.shared

    @State private var allocations: [AllocationItem] = []
    @State private var showAddAllocation: Bool = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Balance to Allocate")) {
                    HStack {
                        Text(balanceType)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("$\(String(format: "%.2f", balanceAmount))")
                            .font(.title3)
                            .fontWeight(.bold)
                    }
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
                        Text("Add allocations to move this \(balanceType.lowercased())'s balance")
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

                Section {
                    Text(
                        "You must allocate the entire balance before deleting this \(balanceType.lowercased()). This ensures no money is lost."
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                Section {
                    Button(action: {
                        completeAllocation()
                    }) {
                        HStack {
                            Spacer()
                            Text("Complete & Delete \(balanceType)")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(!isAllocationValid)
                }
            }
            .navigationTitle("Allocate \(sourceName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showAddAllocation) {
                AddAllocationViewExcludingSource(
                    transactionAmount: balanceAmount,
                    currentAllocations: allocations,
                    isExpense: false,  // Balance transfers are income to destinations
                    excludeType: balanceType == "Fund" ? .fund : .debt,
                    excludeId: sourceId,
                    onAdd: { newAllocation in
                        allocations.append(newAllocation)
                    }
                )
            }
        }
    }

    private var isAllocationValid: Bool {
        guard balanceAmount > 0 else {
            return true  // No balance, no allocation needed
        }

        let totalAllocated = allocations.reduce(0.0) { $0 + $1.amount }
        return abs(totalAllocated - balanceAmount) < 0.01
    }

    private var allocationStatusText: String {
        guard balanceAmount > 0 else {
            return ""
        }

        let totalAllocated = allocations.reduce(0.0) { $0 + $1.amount }
        let remaining = balanceAmount - totalAllocated

        if abs(remaining) < 0.01 {
            return "✓ Fully Allocated"
        } else if remaining > 0 {
            return "$\(String(format: "%.2f", remaining)) remaining"
        } else {
            return "$\(String(format: "%.2f", abs(remaining))) over"
        }
    }

    private func deleteAllocation(_ allocation: AllocationItem) {
        allocations.removeAll { $0.id == allocation.id }
    }

    private func completeAllocation() {
        onComplete(allocations)
        dismiss()
    }
}

// MARK: - Add Allocation View Excluding Source

struct AddAllocationViewExcludingSource: View {
    @Environment(\.dismiss) var dismiss

    let transactionAmount: Double
    let currentAllocations: [AllocationItem]
    let isExpense: Bool
    let excludeType: AllocationType
    let excludeId: String
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
                .filter { fund in
                    // Exclude source fund and already allocated funds
                    guard !fund.id.isEmpty && !alreadyAllocatedIds.contains(fund.id) else {
                        return false
                    }

                    // Exclude the fund being deleted
                    if excludeType == .fund && fund.id == excludeId {
                        return false
                    }

                    return true
                }
                .map { (id: $0.id, name: $0.name, icon: $0.icon) }
        case .debt:
            return debtService.getActiveDebts()
                .filter { debt in
                    // Exclude source debt and already allocated debts
                    guard !debt.id.isEmpty && !alreadyAllocatedIds.contains(debt.id) else {
                        return false
                    }

                    // Exclude the debt being deleted
                    if excludeType == .debt && debt.id == excludeId {
                        return false
                    }

                    return true
                }
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
