import SwiftUI

struct ManualEntryView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var storageService = TransactionStorageService.shared

    // Form fields
    @State private var amount: String = ""
    @State private var merchant: String = ""
    @State private var date: Date = Date()
    @State private var category: TransactionCategory = .other
    @State private var notes: String = ""

    // Matching
    @State private var matchingAlerts: [TransactionAlert] = []
    @State private var selectedAlertId: String? = nil
    @State private var showNoMatchOption: Bool = false

    // UI state
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    // Pre-fill from alert (optional)
    var prefilledAlert: TransactionAlert?

    var body: some View {
        NavigationView {
            Form {
                // MARK: - Transaction Details Section
                Section(header: Text("Transaction Details")) {
                    // Amount
                    HStack {
                        Text("$")
                        TextField("0.00", text: $amount)
                            .keyboardType(.decimalPad)
                            .onChange(of: amount) { _ in
                                updateMatchingAlerts()
                            }
                    }

                    // Merchant
                    TextField("Merchant Name", text: $merchant)

                    // Date
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                        .onChange(of: date) { _ in
                            updateMatchingAlerts()
                        }

                    // Category
                    Picker("Category", selection: $category) {
                        ForEach(TransactionCategory.allCases, id: \.self) { cat in
                            HStack {
                                Image(systemName: cat.icon)
                                Text(cat.rawValue)
                            }
                            .tag(cat)
                        }
                    }

                    // Notes (optional)
                    TextField("Notes (optional)", text: $notes)
                }

                // MARK: - Smart Matching Section
                if !matchingAlerts.isEmpty {
                    Section(header: Text("Matching Email Alerts")) {
                        Text("We found \(matchingAlerts.count) email alert(s) matching this amount and date:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        ForEach(matchingAlerts) { alert in
                            Button(action: {
                                selectedAlertId = alert.id
                                // Pre-fill merchant if not already filled
                                if merchant.isEmpty {
                                    merchant = alert.merchant
                                }
                            }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(alert.merchant)
                                            .font(.headline)
                                        Text("$\(String(format: "%.2f", alert.amount))")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    if selectedAlertId == alert.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }

                        Button(action: {
                            selectedAlertId = nil
                            showNoMatchOption = true
                        }) {
                            HStack {
                                Text("No Email Alert (Cash/Manual)")
                                Spacer()
                                if selectedAlertId == nil && showNoMatchOption {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }
                }

                // MARK: - Save Button
                Section {
                    Button(action: saveTransaction) {
                        HStack {
                            Spacer()
                            Text("Save Transaction")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(!isFormValid)
                }
            }
            .navigationTitle("Manual Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                // Pre-fill if alert was provided
                if let alert = prefilledAlert {
                    amount = String(format: "%.2f", alert.amount)
                    merchant = alert.merchant
                    date = alert.date
                    selectedAlertId = alert.id
                    updateMatchingAlerts()
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var isFormValid: Bool {
        guard !amount.isEmpty,
              !merchant.isEmpty,
              Double(amount) != nil else {
            return false
        }
        return true
    }

    // MARK: - Methods

    private func updateMatchingAlerts() {
        guard let amountValue = Double(amount) else {
            matchingAlerts = []
            return
        }

        matchingAlerts = storageService.findMatchingAlerts(amount: amountValue, date: date)

        // Auto-select if only one match
        if matchingAlerts.count == 1, selectedAlertId == nil {
            selectedAlertId = matchingAlerts.first?.id
        }
    }

    private func saveTransaction() {
        guard let amountValue = Double(amount) else {
            showErrorAlert("Please enter a valid amount")
            return
        }

        // Create new transaction
        let transaction = Transaction(
            id: UUID().uuidString,
            accountId: "manual", // No account ID for manual entries
            amount: amountValue,
            date: date,
            merchantName: merchant,
            category: [category.rawValue],
            pending: false,
            linkedEmailAlertId: selectedAlertId,
            isManualEntry: true
        )

        // Save transaction
        storageService.saveTransaction(transaction)

        // If linked to alert, mark alert as linked
        if let alertId = selectedAlertId {
            storageService.linkAlert(id: alertId, toTransactionId: transaction.id)
        }

        print("✅ [ManualEntry] Saved transaction: \(merchant) - $\(amountValue)")

        // Dismiss view
        dismiss()
    }

    private func showErrorAlert(_ message: String) {
        errorMessage = message
        showError = true
    }
}

// MARK: - Preview

struct ManualEntryView_Previews: PreviewProvider {
    static var previews: some View {
        ManualEntryView()

        ManualEntryView(prefilledAlert: TransactionAlert(
            emailId: "test123",
            merchant: "Target",
            date: Date(),
            amount: 45.99,
            rawEmailBody: "Test"
        ))
    }
}
