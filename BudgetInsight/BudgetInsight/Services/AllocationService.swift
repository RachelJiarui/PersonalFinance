import Foundation

class AllocationService: ObservableObject {
    static let shared = AllocationService()

    @Published var allocations: [TransactionAllocation] = []

    private let userDefaults = UserDefaults.standard
    private let allocationsKey = "transaction_allocations"

    private init() {
        loadAllocations()

        // Fetch data from Firestore on initialization
        Task {
            await fetchDataFromFirestore()
        }
    }

    // MARK: - Firestore Data Fetching

    func fetchDataFromFirestore() async {
        print("🔄 [AllocationService] Fetching allocations from Firestore...")

        do {
            let firestoreAllocations = try await BackendService.shared.fetchAllocations()
            print(
                "✅ [AllocationService] Fetched \(firestoreAllocations.count) allocations from Firestore"
            )

            await MainActor.run {
                // Merge Firestore data with local data instead of replacing
                // Keep local allocations that aren't in Firestore yet (empty IDs)
                let localOnlyAllocations = self.allocations.filter { $0.id.isEmpty }

                // Combine: Firestore allocations + local-only allocations
                self.allocations = firestoreAllocations + localOnlyAllocations
                self.saveAllocations()

                print(
                    "📊 [AllocationService] Total allocations after merge: \(self.allocations.count)"
                )
            }
        } catch {
            print("❌ [AllocationService] Error fetching allocations from Firestore: \(error)")
            print("⚠️ [AllocationService] Using local data only. Backend may not be deployed.")
            // Don't clear local allocations on error - keep what we have
        }
    }

    // MARK: - Allocation Management

    func createAllocation(
        transactionId: String,
        destinationType: AllocationType,
        destinationId: String,
        amount: Double,
        isExpense: Bool? = nil
    ) -> TransactionAllocation {
        // Validate that the destination exists
        let isValid = validateDestination(type: destinationType, id: destinationId)
        if !isValid {
            print("⚠️ [AllocationService] WARNING: Creating allocation with invalid destination!")
            print("   Type: \(destinationType.rawValue), ID: \(destinationId)")
            print("   Transaction ID: \(transactionId), Amount: $\(amount)")
        }

        let newAllocation = TransactionAllocation(
            id: "",  // Firestore will generate this
            transactionId: transactionId,
            destinationType: destinationType,
            destinationId: destinationId,
            amount: amount,
            allocatedAt: Date()
        )

        allocations.append(newAllocation)
        saveAllocations()

        // Save to Firestore
        Task {
            do {
                let firestoreId = try await BackendService.shared.createAllocation(newAllocation)
                print(
                    "✅ [AllocationService] Created Allocation in Firestore with ID: \(firestoreId)"
                )

                await MainActor.run {
                    self.updateAllocationWithId(
                        tempAllocation: newAllocation, firestoreId: firestoreId)
                }
            } catch {
                print("❌ [AllocationService] Error creating Allocation in Firestore: \(error)")
            }
        }

        // Determine if transaction is expense or income
        let transactionIsExpense: Bool
        if let providedIsExpense = isExpense {
            transactionIsExpense = providedIsExpense
        } else {
            // Fallback: Look up the transaction
            let transaction = TransactionStorageService.shared.transactions.first {
                $0.id == transactionId
            }
            transactionIsExpense = transaction?.isExpense ?? true
        }

        // Update destination balances based on allocation type
        updateDestinationBalance(
            destinationType: destinationType, destinationId: destinationId, amount: amount,
            isExpense: transactionIsExpense)

        return newAllocation
    }

    func updateAllocationWithId(tempAllocation: TransactionAllocation, firestoreId: String) {
        if let index = allocations.firstIndex(where: {
            $0.transactionId == tempAllocation.transactionId
                && $0.destinationId == tempAllocation.destinationId && $0.id.isEmpty
        }) {
            var updated = allocations[index]
            updated.id = firestoreId
            allocations[index] = updated
            saveAllocations()
        }
    }

    func updateAllocation(allocationId: String, amount: Double) {
        if let index = allocations.firstIndex(where: { $0.id == allocationId }) {
            let oldAmount = allocations[index].amount
            let destinationType = allocations[index].destinationType
            let destinationId = allocations[index].destinationId
            let transactionId = allocations[index].transactionId

            allocations[index] = TransactionAllocation(
                id: allocationId,
                transactionId: transactionId,
                destinationType: destinationType,
                destinationId: destinationId,
                amount: amount,
                allocatedAt: allocations[index].allocatedAt
            )
            saveAllocations()

            // Update in Firestore
            Task {
                do {
                    try await BackendService.shared.updateAllocation(
                        allocationId: allocationId,
                        updates: ["amount": amount]
                    )
                    print("✅ [AllocationService] Updated Allocation in Firestore")
                } catch {
                    print("❌ [AllocationService] Error updating Allocation in Firestore: \(error)")
                }
            }

            // Get transaction type
            let transaction = TransactionStorageService.shared.transactions.first {
                $0.id == transactionId
            }
            let isExpense = transaction?.isExpense ?? true

            // Adjust destination balance
            let amountDiff = amount - oldAmount
            updateDestinationBalance(
                destinationType: destinationType, destinationId: destinationId, amount: amountDiff,
                isExpense: isExpense)
        }
    }

    func deleteAllocation(allocationId: String) {
        if let index = allocations.firstIndex(where: { $0.id == allocationId }) {
            let allocation = allocations[index]

            // Get transaction type
            let transaction = TransactionStorageService.shared.transactions.first {
                $0.id == allocation.transactionId
            }
            let isExpense = transaction?.isExpense ?? true

            // Reverse the balance change
            updateDestinationBalance(
                destinationType: allocation.destinationType,
                destinationId: allocation.destinationId,
                amount: -allocation.amount,
                isExpense: isExpense
            )

            allocations.remove(at: index)
            saveAllocations()

            // Delete from Firestore
            Task {
                do {
                    try await BackendService.shared.deleteAllocation(allocationId)
                    print("✅ [AllocationService] Deleted Allocation from Firestore")
                } catch {
                    print("❌ [AllocationService] Error deleting Allocation: \(error)")
                }
            }
        }
    }

    func getAllocationsForTransaction(_ transactionId: String) -> [TransactionAllocation] {
        return allocations.filter { $0.transactionId == transactionId }
    }

    func getAllocationsForDestination(
        destinationType: AllocationType, destinationId: String
    ) -> [TransactionAllocation] {
        return allocations.filter {
            $0.destinationType == destinationType && $0.destinationId == destinationId
        }
    }

    func validateAllocations(for transactionId: String, expectedAmount: Double) -> Bool {
        let transactionAllocations = getAllocationsForTransaction(transactionId)
        let totalAllocated = transactionAllocations.reduce(0.0) { $0 + $1.amount }
        return abs(totalAllocated - expectedAmount) < 0.01  // Allow for floating point errors
    }

    func getTotalAllocated(for transactionId: String) -> Double {
        let transactionAllocations = getAllocationsForTransaction(transactionId)
        return transactionAllocations.reduce(0.0) { $0 + $1.amount }
    }

    // MARK: - Balance Updates

    private func updateDestinationBalance(
        destinationType: AllocationType, destinationId: String, amount: Double, isExpense: Bool
    ) {
        switch destinationType {
        case .category:
            // Category spending is handled by BudgetService
            // This will trigger a refresh when allocations change
            break

        case .fund:
            // Update fund balance
            // Income allocations ADD to fund (saving money), Expense allocations SUBTRACT from fund (spending money)
            let adjustedAmount = isExpense ? -amount : amount
            FundService.shared.updateBalance(fundId: destinationId, amount: adjustedAmount)

        case .debt:
            // Update debt balance - debts work in reverse of funds
            // Income allocations REDUCE debt (subtract), Expense allocations INCREASE debt (add)
            let adjustedAmount = isExpense ? amount : -amount
            DebtService.shared.updateBalance(debtId: destinationId, amount: adjustedAmount)
        }
    }

    func clearAllData() {
        allocations = []
        userDefaults.removeObject(forKey: allocationsKey)
    }

    // MARK: - Validation

    private func validateDestination(type: AllocationType, id: String) -> Bool {
        switch type {
        case .category:
            return BudgetService.shared.getCategoryById(id) != nil
        case .fund:
            return FundService.shared.funds.contains(where: { $0.id == id })
        case .debt:
            return DebtService.shared.debts.contains(where: { $0.id == id })
        }
    }

    // MARK: - Persistence

    private func saveAllocations() {
        if let encoded = try? JSONEncoder().encode(allocations) {
            userDefaults.set(encoded, forKey: allocationsKey)
        }
    }

    private func loadAllocations() {
        if let data = userDefaults.data(forKey: allocationsKey),
            let decoded = try? JSONDecoder().decode([TransactionAllocation].self, from: data)
        {
            allocations = decoded
            print(
                "💾 [AllocationService] Loaded \(allocations.count) allocations from local storage")
        } else {
            print("⚠️ [AllocationService] No allocations found in local storage")
        }
    }
}
