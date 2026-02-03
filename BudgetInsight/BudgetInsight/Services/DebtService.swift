import Foundation

class DebtService: ObservableObject {
    static let shared = DebtService()

    @Published var debts: [Debt] = []

    private let userDefaults = UserDefaults.standard
    private let debtsKey = "debts"

    private init() {
        loadDebts()

        // Fetch data from Firestore on initialization
        Task {
            await fetchDataFromFirestore()
            await ensureDefaultDebtExists()
        }
    }

    // MARK: - Default Debt Management

    /// Ensures the default "General Debt" debt exists
    private func ensureDefaultDebtExists() async {
        // Check if default debt already exists
        let hasDefaultDebt = debts.contains { $0.isDefault && $0.name == "General Debt" }

        if !hasDefaultDebt {
            let defaultDebt = Debt(
                id: "",
                name: "General Debt",
                icon: "creditcard",
                description: "Default debt bucket",
                balance: 0.0,
                goal: 0.0,
                deadline: nil,
                createdAt: Date(),
                isActive: true,
                isDefault: true
            )

            // Save to Firestore
            do {
                let firestoreId = try await BackendService.shared.createDebt(defaultDebt)

                await MainActor.run {
                    let debtWithId = Debt(
                        id: firestoreId,
                        name: "General Debt",
                        icon: "creditcard",
                        description: "Default debt bucket",
                        balance: 0.0,
                        goal: 0.0,
                        deadline: nil,
                        createdAt: defaultDebt.createdAt,
                        isActive: true,
                        isDefault: true
                    )

                    if !self.debts.contains(where: { $0.id == firestoreId }) {
                        self.debts.append(debtWithId)
                        self.saveDebts()
                    }
                }
            } catch {
                print("❌ [DebtService] Error creating default debt: \(error)")
            }
        }
    }

    func getDefaultDebt() -> Debt? {
        return debts.first { $0.isDefault && $0.name == "General Debt" && $0.isActive }
    }

    // MARK: - Firestore Data Fetching

    func fetchDataFromFirestore() async {
        do {
            let firestoreDebts = try await BackendService.shared.fetchDebts()

            await MainActor.run {
                // Replace with Firestore data as source of truth
                self.debts = firestoreDebts
                self.saveDebts()
            }
        } catch {
            print("❌ [DebtService] Error fetching debts: \(error)")
            // Continue using local data - don't clear the array
        }
    }

    // MARK: - Debt Management

    func createDebt(
        name: String,
        icon: String,
        description: String,
        balance: Double,
        goal: Double,
        deadline: Date? = nil
    ) -> Debt {
        let newDebt = Debt(
            id: "",  // Temporary - will be replaced with Firestore ID
            name: name,
            icon: icon,
            description: description,
            balance: balance,
            goal: goal,
            deadline: deadline,
            createdAt: Date(),
            isActive: true
        )

        // Save to Firestore immediately and wait for ID
        Task {
            do {
                let firestoreId = try await BackendService.shared.createDebt(newDebt)

                await MainActor.run {
                    // Create debt with actual Firestore ID
                    let debtWithId = Debt(
                        id: firestoreId,
                        name: name,
                        icon: icon,
                        description: description,
                        balance: balance,
                        goal: goal,
                        deadline: deadline,
                        createdAt: newDebt.createdAt,
                        isActive: true
                    )

                    // Only add if not already present (avoid duplicates)
                    if !self.debts.contains(where: { $0.id == firestoreId }) {
                        self.debts.append(debtWithId)
                        self.saveDebts()
                    }
                }

                // If goal > 0, create a transaction and allocation to record this expense
                if goal > 0 {
                    await self.createInitialDebtTransaction(
                        debtId: firestoreId,
                        debtName: name,
                        amount: goal
                    )
                }
            } catch {
                print("❌ [DebtService] Error creating Debt in Firestore: \(error)")
            }
        }

        return newDebt
    }

    /// Creates a transaction and allocation for the initial debt amount
    /// This ensures the debt expense shows up in month-end calculations
    private func createInitialDebtTransaction(
        debtId: String,
        debtName: String,
        amount: Double
    ) async {
        // Create an expense transaction for the debt amount
        let transaction = Transaction(
            id: "",
            amount: amount,
            date: Date(),
            title: "Debt: \(debtName)",
            isExpense: true,
            timestamp: Date()
        )

        do {
            // Save transaction to Firestore
            let transactionId = try await BackendService.shared.createTransaction(transaction)

            // Save transaction locally
            await MainActor.run {
                var transactionWithId = transaction
                transactionWithId.id = transactionId
                TransactionStorageService.shared.saveTransaction(transactionWithId)
            }

            // Create allocation linking transaction to debt
            // Skip balance update since debt balance is already set to goal
            await MainActor.run {
                _ = AllocationService.shared.createAllocation(
                    transactionId: transactionId,
                    destinationType: .debt,
                    destinationId: debtId,
                    amount: amount,
                    isExpense: true,
                    skipBalanceUpdate: true
                )
            }

            print("✅ [DebtService] Created initial transaction and allocation for debt \(debtName)")
        } catch {
            print("❌ [DebtService] Error creating initial debt transaction: \(error)")
        }
    }

    func updateDebt(
        debtId: String,
        name: String? = nil,
        icon: String? = nil,
        description: String? = nil,
        goal: Double? = nil,
        deadline: Date? = nil
    ) {
        if let index = debts.firstIndex(where: { $0.id == debtId && $0.isActive }) {
            var updates: [String: Any] = [:]

            if let name = name {
                debts[index].name = name
                updates["name"] = name
            }
            if let icon = icon {
                debts[index].icon = icon
                updates["icon"] = icon
            }
            if let description = description {
                debts[index].description = description
                updates["description"] = description
            }
            if let goal = goal {
                debts[index].goal = goal
                updates["goal"] = goal
            }
            if let deadline = deadline {
                debts[index].deadline = deadline
                let dateFormatter = ISO8601DateFormatter()
                updates["deadline"] = dateFormatter.string(from: deadline)
            }

            saveDebts()

            // Update in Firestore if there are any updates
            if !updates.isEmpty {
                Task {
                    do {
                        try await BackendService.shared.updateDebt(debtId: debtId, updates: updates)
                    } catch {
                        print("❌ [DebtService] Error updating debt: \(error)")
                    }
                }
            }
        }
    }

    func updateBalance(debtId: String, amount: Double) {
        if let index = debts.firstIndex(where: { $0.id == debtId && $0.isActive }) {
            let newBalance = debts[index].balance + amount

            // Prevent balance from going below 0 (can't have negative debt)
            guard newBalance >= 0 else {
                print(
                    "❌ [DebtService] Cannot update balance: would go below 0 (current: \(debts[index].balance), change: \(amount))"
                )
                return
            }

            debts[index].balance = newBalance
            saveDebts()

            // Update in Firestore
            Task {
                do {
                    try await BackendService.shared.updateDebt(
                        debtId: debtId,
                        updates: ["balance": newBalance]
                    )
                } catch {
                    print("❌ [DebtService] Error updating debt balance: \(error)")
                }
            }
        }
    }

    /// Validates if a balance update is possible without going below 0
    func canUpdateBalance(debtId: String, amount: Double) -> Bool {
        guard let debt = debts.first(where: { $0.id == debtId && $0.isActive }) else {
            return false
        }
        return (debt.balance + amount) >= 0
    }

    func deleteDebt(debtId: String) {
        // Mark as inactive instead of deleting (for historical data integrity)
        if let index = debts.firstIndex(where: { $0.id == debtId }) {
            debts[index].isActive = false
            saveDebts()

            // Mark as inactive in Firestore
            Task {
                do {
                    try await BackendService.shared.deleteDebt(debtId)
                } catch {
                    print("❌ [DebtService] Error deleting debt: \(error)")
                }
            }
        }
    }

    func getDebtById(_ id: String) -> Debt? {
        return debts.first { $0.id == id }
    }

    func getActiveDebts() -> [Debt] {
        return debts.filter { $0.isActive }
    }

    func clearAllData() {
        debts = []
        userDefaults.removeObject(forKey: debtsKey)
    }

    // MARK: - Persistence

    private func saveDebts() {
        if let encoded = try? JSONEncoder().encode(debts) {
            userDefaults.set(encoded, forKey: debtsKey)
        }
    }

    private func loadDebts() {
        if let data = userDefaults.data(forKey: debtsKey),
            let decoded = try? JSONDecoder().decode([Debt].self, from: data)
        {
            debts = decoded
        }
    }
}
