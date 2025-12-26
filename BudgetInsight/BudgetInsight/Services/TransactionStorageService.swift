import Foundation
import Combine

/// Handles local persistence of transactions and transaction alerts
/// NOTE: Currently uses UserDefaults for local storage. Prepared for future backend API integration (EC2).
class TransactionStorageService: ObservableObject {
    static let shared = TransactionStorageService()

    @Published var transactions: [Transaction] = []
    @Published var transactionAlerts: [TransactionAlert] = []

    private let transactionsKey = "stored_transactions"
    private let alertsKey = "transaction_alerts"

    private init() {
        loadTransactions()
        loadTransactionAlerts()
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
    private func persistTransactions() {
        do {
            let data = try JSONEncoder().encode(transactions)
            UserDefaults.standard.set(data, forKey: transactionsKey)
        } catch {
            print("Failed to encode transactions: \(error)")
        }
    }

    // MARK: - Transaction Alert Methods

    /// Save a new transaction alert to local storage
    func saveTransactionAlert(_ alert: TransactionAlert) {
        transactionAlerts.append(alert)
        persistTransactionAlerts()

        // TODO: Future - sync to backend API
        // syncAlertToRemote(alert)
    }

    /// Load all transaction alerts from local storage
    func loadTransactionAlerts() {
        guard let data = UserDefaults.standard.data(forKey: alertsKey) else {
            transactionAlerts = []
            return
        }

        do {
            transactionAlerts = try JSONDecoder().decode([TransactionAlert].self, from: data)
        } catch {
            print("Failed to decode transaction alerts: \(error)")
            transactionAlerts = []
        }

        // TODO: Future - sync from backend API
        // syncAlertsFromRemote()
    }

    /// Mark an alert as linked and remove it from the needs entry queue
    func linkAlert(id: String, toTransactionId transactionId: String) {
        if let index = transactionAlerts.firstIndex(where: { $0.id == id }) {
            transactionAlerts[index].isLinked = true
            persistTransactionAlerts()

            // TODO: Future - update backend API
            // updateAlertLinkStatus(id: id, linkedToTransaction: transactionId)
        }
    }

    /// Get unlinked alerts (needs entry queue)
    func getUnlinkedAlerts() -> [TransactionAlert] {
        return transactionAlerts.filter { !$0.isLinked }
    }

    /// Delete a transaction alert by ID
    func deleteTransactionAlert(id: String) {
        transactionAlerts.removeAll { $0.id == id }
        persistTransactionAlerts()

        // TODO: Future - delete from backend API
        // deleteAlertFromRemote(id)
    }

    /// Persist transaction alerts to UserDefaults
    private func persistTransactionAlerts() {
        do {
            let data = try JSONEncoder().encode(transactionAlerts)
            UserDefaults.standard.set(data, forKey: alertsKey)
        } catch {
            print("Failed to encode transaction alerts: \(error)")
        }
    }

    // MARK: - Matching Logic

    /// Find alerts that match a given amount and date
    /// Matching criteria: amount within $0.01 and same calendar day
    func findMatchingAlerts(amount: Double, date: Date) -> [TransactionAlert] {
        let calendar = Calendar.current

        return getUnlinkedAlerts().filter { alert in
            // Check if amounts match within $0.01
            let amountMatches = abs(alert.amount - amount) < 0.01

            // Check if dates are on the same day
            let dateMatches = calendar.isDate(alert.date, inSameDayAs: date)

            return amountMatches && dateMatches
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

    private func syncAlertToRemote(_ alert: TransactionAlert) async {
        // POST /api/transaction-alerts
        // Send alert to backend API
    }

    private func syncAlertsFromRemote() async {
        // GET /api/transaction-alerts
        // Fetch all alerts from backend
        // Merge with local storage
    }

    private func updateAlertLinkStatus(id: String, linkedToTransaction transactionId: String) async {
        // PATCH /api/transaction-alerts/{id}
        // Update isLinked status on backend
    }

    private func deleteAlertFromRemote(_ id: String) async {
        // DELETE /api/transaction-alerts/{id}
        // Remove alert from backend
    }
    */
}
