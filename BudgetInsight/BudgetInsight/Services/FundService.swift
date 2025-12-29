import Foundation

class FundService: ObservableObject {
    static let shared = FundService()

    @Published var funds: [Fund] = []

    private let userDefaults = UserDefaults.standard
    private let fundsKey = "funds"

    private init() {
        loadFunds()

        // Fetch data from Firestore on initialization
        Task {
            await fetchDataFromFirestore()
        }
    }

    // MARK: - Firestore Data Fetching

    func fetchDataFromFirestore() async {
        print("🔄 [FundService] Fetching funds from Firestore...")

        do {
            let firestoreFunds = try await BackendService.shared.fetchFunds()
            print("✅ [FundService] Fetched \(firestoreFunds.count) funds from Firestore")

            // Debug: Print details of fetched funds
            for fund in firestoreFunds {
                print(
                    "   - Fund: \(fund.name), ID: \(fund.id), Active: \(fund.isActive), Balance: \(fund.balance)"
                )
            }

            await MainActor.run {
                // Replace with Firestore data as source of truth
                self.funds = firestoreFunds
                self.saveFunds()

                print("📊 [FundService] Total funds: \(self.funds.count)")
                print("📊 [FundService] Active funds: \(self.getActiveFunds().count)")
            }
        } catch {
            print("❌ [FundService] Error fetching funds from Firestore: \(error)")
            print(
                "⚠️ [FundService] Using local data only. Make sure backend is deployed and running.")
            // Continue using local data - don't clear the array
        }
    }

    // MARK: - Fund Management

    func createFund(
        name: String,
        icon: String,
        description: String,
        balance: Double = 0.0,
        goal: Double? = nil,
        deadline: Date? = nil
    ) -> Fund {
        let newFund = Fund(
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
                let firestoreId = try await BackendService.shared.createFund(newFund)
                print("✅ [FundService] Created Fund in Firestore with ID: \(firestoreId)")

                await MainActor.run {
                    // Create fund with actual Firestore ID
                    let fundWithId = Fund(
                        id: firestoreId,
                        name: name,
                        icon: icon,
                        description: description,
                        balance: balance,
                        goal: goal,
                        deadline: deadline,
                        createdAt: newFund.createdAt,
                        isActive: true
                    )

                    // Only add if not already present (avoid duplicates)
                    if !self.funds.contains(where: { $0.id == firestoreId }) {
                        self.funds.append(fundWithId)
                        self.saveFunds()
                    }
                }
            } catch {
                print("❌ [FundService] Error creating Fund in Firestore: \(error)")
            }
        }

        return newFund
    }

    func updateFund(
        fundId: String,
        name: String? = nil,
        icon: String? = nil,
        description: String? = nil,
        goal: Double? = nil,
        deadline: Date? = nil
    ) {
        if let index = funds.firstIndex(where: { $0.id == fundId && $0.isActive }) {
            var updates: [String: Any] = [:]

            if let name = name {
                funds[index].name = name
                updates["name"] = name
            }
            if let icon = icon {
                funds[index].icon = icon
                updates["icon"] = icon
            }
            if let description = description {
                funds[index].description = description
                updates["description"] = description
            }
            if let goal = goal {
                funds[index].goal = goal
                updates["goal"] = goal
            }
            if let deadline = deadline {
                funds[index].deadline = deadline
                let dateFormatter = ISO8601DateFormatter()
                updates["deadline"] = dateFormatter.string(from: deadline)
            }

            saveFunds()

            // Update in Firestore if there are any updates
            if !updates.isEmpty {
                Task {
                    do {
                        try await BackendService.shared.updateFund(fundId: fundId, updates: updates)
                        print("✅ [FundService] Updated Fund in Firestore")
                    } catch {
                        print("❌ [FundService] Error updating Fund in Firestore: \(error)")
                    }
                }
            }
        }
    }

    func updateBalance(fundId: String, amount: Double) {
        if let index = funds.firstIndex(where: { $0.id == fundId && $0.isActive }) {
            funds[index].balance += amount
            saveFunds()

            // Update in Firestore
            Task {
                do {
                    try await BackendService.shared.updateFund(
                        fundId: fundId,
                        updates: ["balance": funds[index].balance]
                    )
                    print("✅ [FundService] Updated Fund balance in Firestore")
                } catch {
                    print("❌ [FundService] Error updating Fund balance in Firestore: \(error)")
                }
            }
        }
    }

    func deleteFund(fundId: String) {
        // Mark as inactive instead of deleting (for historical data integrity)
        if let index = funds.firstIndex(where: { $0.id == fundId }) {
            funds[index].isActive = false
            saveFunds()

            // Mark as inactive in Firestore
            Task {
                do {
                    try await BackendService.shared.deleteFund(fundId)
                    print("✅ [FundService] Marked Fund as inactive in Firestore")
                } catch {
                    print("❌ [FundService] Error deleting Fund: \(error)")
                }
            }
        }
    }

    func getFundById(_ id: String) -> Fund? {
        return funds.first { $0.id == id }
    }

    func getActiveFunds() -> [Fund] {
        return funds.filter { $0.isActive }
    }

    func clearAllData() {
        funds = []
        userDefaults.removeObject(forKey: fundsKey)
    }

    // MARK: - Persistence

    private func saveFunds() {
        if let encoded = try? JSONEncoder().encode(funds) {
            userDefaults.set(encoded, forKey: fundsKey)
        }
    }

    private func loadFunds() {
        if let data = userDefaults.data(forKey: fundsKey),
            let decoded = try? JSONDecoder().decode([Fund].self, from: data)
        {
            funds = decoded
        }
    }
}
