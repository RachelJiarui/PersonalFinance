import SwiftUI

struct ManualEntryView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var storageService = TransactionStorageService.shared
    @StateObject private var budgetService = BudgetService.shared
    @StateObject private var backendService = BackendService.shared

    // Form fields matching Transaction model
    @State private var amount: String = ""
    @State private var title: String = ""
    @State private var date: Date = Date()
    @State private var selectedCategoryId: String = ""
    @State private var isExpense: Bool = true
    @State private var selectedAlertId: String? = nil

    // Matching
    @State private var matchingAlerts: [TransactionAlert] = []
    @State private var availableAlerts: [TransactionAlert] = []

    // UI state
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var isSaving: Bool = false

    // Pre-fill from alert (optional)
    var prefilledAlert: TransactionAlert?

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
                                updateMatchingAlerts()
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
                    .onChange(of: date) { _ in
                        updateMatchingAlerts()
                    }

                    // Category Picker
                    if budgetService.getActiveCategories().isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("No Categories Available")
                                    .foregroundColor(.orange)
                            }
                            Text(
                                "Please create budget categories in the 'My Budget' tab before adding transactions."
                            )
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    } else {
                        NavigationLink(
                            destination: CategorySelectionView(
                                selectedCategoryId: $selectedCategoryId,
                                categories: budgetService.getActiveCategories())
                        ) {
                            HStack {
                                Text("Category")
                                Spacer()
                                if let selectedCategory = budgetService.getActiveCategories().first(
                                    where: { $0.id == selectedCategoryId })
                                {
                                    Image(systemName: selectedCategory.icon)
                                        .foregroundColor(.blue)
                                    Text(selectedCategory.name)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("Select Category")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
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

                // MARK: - Link to Transaction Alert (Optional)
                Section(header: Text("Link to Email Alert (Optional)")) {
                    Picker("Transaction Alert", selection: $selectedAlertId) {
                        Text("None").tag(nil as String?)

                        if !matchingAlerts.isEmpty {
                            Text("── Matching Alerts ──").tag(nil as String?)
                            ForEach(matchingAlerts) { alert in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(alert.merchant)
                                        Text(
                                            "$\(String(format: "%.2f", alert.amount)) • \(formattedDate(alert.date))"
                                        )
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                                .tag(alert.id as String?)
                            }
                        }

                        if !availableAlerts.isEmpty {
                            Text("── All Unresolved Alerts ──").tag(nil as String?)
                            ForEach(availableAlerts) { alert in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(alert.merchant)
                                        Text(
                                            "$\(String(format: "%.2f", alert.amount)) • \(formattedDate(alert.date))"
                                        )
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    }
                                }
                                .tag(alert.id as String?)
                            }
                        }
                    }

                    if !matchingAlerts.isEmpty {
                        Text("💡 \(matchingAlerts.count) alert(s) match this amount and date")
                            .font(.caption)
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
        // Check if categories exist
        guard !budgetService.getActiveCategories().isEmpty else {
            print("❌ [ManualEntry] Form invalid: No categories")
            return false
        }

        // Check required fields
        let isValid =
            !amount.isEmpty && !title.isEmpty && !selectedCategoryId.isEmpty
            && Double(amount) != nil

        if !isValid {
            print(
                "❌ [ManualEntry] Form invalid - amount: '\(amount)', title: '\(title)', categoryId: '\(selectedCategoryId)'"
            )
        }

        return isValid
    }

    // MARK: - Methods

    private func loadData() {
        // Load all unresolved alerts
        availableAlerts = storageService.getUnlinkedAlerts()

        // Debug: Print all categories and their IDs
        let categories = budgetService.getActiveCategories()
        print("🔍 [ManualEntry] Available categories:")
        for category in categories {
            print("   - \(category.name): id='\(category.id)' (isEmpty: \(category.id.isEmpty))")
        }

        // Set default category if available
        if selectedCategoryId.isEmpty, let firstCategory = categories.first,
            !firstCategory.id.isEmpty
        {
            selectedCategoryId = firstCategory.id
            print(
                "✅ [ManualEntry] Auto-selected category: \(firstCategory.name) (id: \(firstCategory.id))"
            )
        }

        // Pre-fill if alert was provided
        if let alert = prefilledAlert {
            amount = String(format: "%.2f", alert.amount)
            title = alert.merchant
            date = alert.date
            selectedAlertId = alert.id
            updateMatchingAlerts()
        }
    }

    private func updateMatchingAlerts() {
        guard let amountValue = Double(amount) else {
            matchingAlerts = []
            return
        }

        matchingAlerts = storageService.findMatchingAlerts(amount: amountValue, date: date)

        // Auto-select if only one match and none selected
        if matchingAlerts.count == 1, selectedAlertId == nil {
            selectedAlertId = matchingAlerts.first?.id
            // Pre-fill title from alert if empty
            if title.isEmpty, let alert = matchingAlerts.first {
                title = alert.merchant
            }
        }
    }

    private func saveTransaction() {
        guard let amountValue = Double(amount) else {
            showErrorAlert("Please enter a valid amount")
            return
        }

        guard !selectedCategoryId.isEmpty else {
            showErrorAlert("Please select a category")
            return
        }

        guard !budgetService.getActiveCategories().isEmpty else {
            showErrorAlert("Please create budget categories in 'My Budget' tab first")
            return
        }

        isSaving = true

        // Create new transaction with empty ID (Firestore will generate)
        var transaction = Transaction(
            id: "",  // Firestore auto-generates
            amount: amountValue,
            date: date,
            title: title,
            categoryId: selectedCategoryId,
            isExpense: isExpense,
            timestamp: Date(),
            linkedEmailAlertId: selectedAlertId
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

                // If linked to alert, update alert to link back to transaction
                if let alertId = selectedAlertId {
                    storageService.linkAlert(id: alertId, toTransactionId: firestoreId)

                    // Try to update backend link (may fail if alert doesn't exist in Firestore)
                    do {
                        try await backendService.linkTransactionToAlert(
                            transactionId: firestoreId,
                            alertId: alertId
                        )
                        print("✅ [ManualEntry] Linked transaction to alert in Firestore")
                    } catch {
                        print(
                            "⚠️ [ManualEntry] Could not link alert in Firestore (alert may not exist): \(error)"
                        )
                        // Don't fail the whole transaction - it was saved successfully
                    }
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

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Category Selection View

struct CategorySelectionView: View {
    @Binding var selectedCategoryId: String
    let categories: [BudgetCategory]
    @Environment(\.dismiss) var dismiss

    var body: some View {
        List {
            ForEach(categories) { category in
                Button(action: {
                    selectedCategoryId = category.id
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: category.icon)
                            .foregroundColor(.blue)
                            .frame(width: 30)
                        Text(category.name)
                            .foregroundColor(.primary)
                        Spacer()
                        if selectedCategoryId == category.id {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
        .navigationTitle("Select Category")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

struct ManualEntryView_Previews: PreviewProvider {
    static var previews: some View {
        ManualEntryView()

        ManualEntryView(
            prefilledAlert: TransactionAlert(
                id: "test123",
                emailId: "gmail123",
                merchant: "Target",
                date: Date(),
                amount: 45.99,
                rawEmailBody: "Test",
                receivedAt: Date()
            ))
    }
}
