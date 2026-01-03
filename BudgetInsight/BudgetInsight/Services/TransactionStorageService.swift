import Combine
import Foundation
import WidgetKit

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
        guard let data = SharedUserDefaults.shared.data(forKey: transactionsKey) else {
            transactions = []
            print("⚠️ [TransactionStorageService] No transactions found in local storage")
            return
        }

        do {
            transactions = try JSONDecoder().decode([Transaction].self, from: data)
            print(
                "💾 [TransactionStorageService] Loaded \(transactions.count) transactions from local storage"
            )

            // Debug: Show date range of transactions
            if !transactions.isEmpty {
                let dates = transactions.map { $0.date }
                if let minDate = dates.min(), let maxDate = dates.max() {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .short
                    print(
                        "   Date range: \(formatter.string(from: minDate)) to \(formatter.string(from: maxDate))"
                    )
                }
            }
        } catch {
            print("❌ [TransactionStorageService] Failed to decode transactions: \(error)")
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
            SharedUserDefaults.shared.set(data, forKey: transactionsKey)
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            print("Failed to encode transactions: \(error)")
        }
    }

    // MARK: - Month-End Balancing Helper Methods

    /// Get all transactions for a specific month
    func getTransactionsForMonth(year: Int, month: Int) -> [Transaction] {
        let calendar = Calendar.current
        return transactions.filter { transaction in
            let txYear = calendar.component(.year, from: transaction.date)
            let txMonth = calendar.component(.month, from: transaction.date)
            return txYear == year && txMonth == month
        }
    }

    /// Get total income for a specific month
    func getTotalIncomeForMonth(year: Int, month: Int) -> Double {
        return getTransactionsForMonth(year: year, month: month)
            .filter { !$0.isExpense }
            .reduce(0.0) { $0 + $1.amount }
    }

    /// Get total expenses for a specific month
    func getTotalExpensesForMonth(year: Int, month: Int) -> Double {
        return getTransactionsForMonth(year: year, month: month)
            .filter { $0.isExpense }
            .reduce(0.0) { $0 + $1.amount }
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
