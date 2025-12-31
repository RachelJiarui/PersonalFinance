import Combine
import Foundation

/// Handles local persistence of transactions
/// NOTE: Currently uses UserDefaults for local storage. Prepared for future backend API integration (EC2).
class TransactionStorageService: ObservableObject {
    static let shared = TransactionStorageService()

    @Published var transactions: [Transaction] = []

    private let transactionsKey = "stored_transactions"

    private init() {
        loadTransactions()
    }

    // MARK: - Transaction Methods

    /// Save a new transaction to local storage
    func saveTransaction(_ transaction: Transaction) {
        transactions.append(transaction)
        persistTransactions()

        // TODO: Future - sync to backend API
        // syncTransactionToRemote(transaction)
    }

    /// Load all transactions from local storage
    func loadTransactions() {
        guard let data = UserDefaults.standard.data(forKey: transactionsKey) else {
            transactions = []
            return
        }

        do {
            transactions = try JSONDecoder().decode([Transaction].self, from: data)
        } catch {
            print("Failed to decode transactions: \(error)")
            transactions = []
        }

        // TODO: Future - sync from backend API
        // syncTransactionsFromRemote()
    }

    /// Delete a transaction by ID
    func deleteTransaction(id: String) {
        transactions.removeAll { $0.id == id }
        persistTransactions()

        // TODO: Future - delete from backend API
        // deleteTransactionFromRemote(id)
    }

    /// Persist transactions to UserDefaults
    func persistTransactions() {
        do {
            let data = try JSONEncoder().encode(transactions)
            UserDefaults.standard.set(data, forKey: transactionsKey)
        } catch {
            print("Failed to encode transactions: \(error)")
        }
    }

    // MARK: - Future Backend Integration (Stubs)

    // TODO: Implement when EC2 backend is ready

    /*
    private func syncTransactionToRemote(_ transaction: Transaction) async {
        // POST /api/transactions
        // Send transaction to backend API
    }
    
    private func syncTransactionsFromRemote() async {
        // GET /api/transactions
        // Fetch all transactions from backend
        // Merge with local storage (use server as source of truth)
    }
    
    private func deleteTransactionFromRemote(_ id: String) async {
        // DELETE /api/transactions/{id}
        // Remove transaction from backend
    }
    */
}
