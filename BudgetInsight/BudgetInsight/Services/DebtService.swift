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
        }
    }

    // MARK: - Firestore Data Fetching

    func fetchDataFromFirestore() async {
        print("🔄 [DebtService] Fetching debts from Firestore...")

        do {
            let firestoreDebts = try await BackendService.shared.fetchDebts()
            print("✅ [DebtService] Fetched \(firestoreDebts.count) debts from Firestore")

            // Debug: Print details of fetched debts
            for debt in firestoreDebts {
                print(
                    "   - Debt: \(debt.name), ID: \(debt.id), Active: \(debt.isActive), Balance: \(debt.balance)"
                )
            }

            await MainActor.run {
                // Replace with Firestore data as source of truth
                self.debts = firestoreDebts
                self.saveDebts()

                print("📊 [DebtService] Total debts: \(self.debts.count)")
                print("📊 [DebtService] Active debts: \(self.getActiveDebts().count)")
            }
        } catch {
            print("❌ [DebtService] Error fetching debts from Firestore: \(error)")
            print(
                "⚠️ [DebtService] Using local data only. Make sure backend is deployed and running.")
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
                print("✅ [DebtService] Created Debt in Firestore with ID: \(firestoreId)")

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
            } catch {
                print("❌ [DebtService] Error creating Debt in Firestore: \(error)")
            }
        }

        return newDebt
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
                        print("✅ [DebtService] Updated Debt in Firestore")
                    } catch {
                        print("❌ [DebtService] Error updating Debt in Firestore: \(error)")
                    }
                }
            }
        }
    }

    func updateBalance(debtId: String, amount: Double) {
        if let index = debts.firstIndex(where: { $0.id == debtId && $0.isActive }) {
            debts[index].balance += amount
            saveDebts()

            // Update in Firestore
            Task {
                do {
                    try await BackendService.shared.updateDebt(
                        debtId: debtId,
                        updates: ["balance": debts[index].balance]
                    )
                    print("✅ [DebtService] Updated Debt balance in Firestore")
                } catch {
                    print("❌ [DebtService] Error updating Debt balance in Firestore: \(error)")
                }
            }
        }
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
                    print("✅ [DebtService] Marked Debt as inactive in Firestore")
                } catch {
                    print("❌ [DebtService] Error deleting Debt: \(error)")
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
