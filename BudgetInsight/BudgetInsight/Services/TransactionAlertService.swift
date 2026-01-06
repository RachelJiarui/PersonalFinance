import Foundation

/// Service for managing Transaction Alerts
@MainActor
class TransactionAlertService: ObservableObject {
    static let shared = TransactionAlertService()

    @Published var alerts: [TransactionAlert] = []
    @Published var isLoading: Bool = false

    private let backendService = BackendService.shared

    private init() {}

    // MARK: - Fetching

    /// Fetch all transaction alerts from backend
    func fetchAlerts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            alerts = try await backendService.fetchTransactionAlerts()
        } catch {
            print("❌ [TransactionAlertService] Error fetching alerts: \(error)")
        }
    }

    /// Get unresolved alerts
    var unresolvedAlerts: [TransactionAlert] {
        alerts.filter { !$0.isResolved }
    }

    /// Get resolved alerts
    var resolvedAlerts: [TransactionAlert] {
        alerts.filter { $0.isResolved }
    }

    // MARK: - Linking

    /// Link a transaction to an alert (marks alert as resolved)
    func linkTransactionToAlert(transactionId: String, alertId: String) async throws {
        // Update alert in backend
        let updates: [String: Any] = [
            "is_resolved": true,
            "linked_transaction_id": transactionId,
        ]

        try await backendService.updateTransactionAlert(alertId: alertId, updates: updates)

        // Update local alert
        if let index = alerts.firstIndex(where: { $0.id == alertId }) {
            var updatedAlert = alerts[index]
            updatedAlert.isResolved = true
            updatedAlert.linkedTransactionId = transactionId
            alerts[index] = updatedAlert
        }
    }

    /// Unlink a transaction from an alert (marks alert as unresolved)
    func unlinkTransactionFromAlert(alertId: String) async throws {
        // Update alert in backend
        let updates: [String: Any] = [
            "is_resolved": false,
            "linked_transaction_id": NSNull(),
        ]

        try await backendService.updateTransactionAlert(alertId: alertId, updates: updates)

        // Update local alert
        if let index = alerts.firstIndex(where: { $0.id == alertId }) {
            var updatedAlert = alerts[index]
            updatedAlert.isResolved = false
            updatedAlert.linkedTransactionId = nil
            alerts[index] = updatedAlert
        }
    }

    /// Change which alert a transaction is linked to
    func relinkTransaction(transactionId: String, oldAlertId: String?, newAlertId: String?)
        async throws
    {
        // Unlink from old alert if exists
        if let oldAlertId = oldAlertId {
            try await unlinkTransactionFromAlert(alertId: oldAlertId)
        }

        // Link to new alert if exists
        if let newAlertId = newAlertId {
            try await linkTransactionToAlert(transactionId: transactionId, alertId: newAlertId)
        }
    }

    // MARK: - Deletion

    /// Delete an alert
    func deleteAlert(_ alert: TransactionAlert) async throws {
        try await backendService.deleteTransactionAlert(alertId: alert.id)
        alerts.removeAll { $0.id == alert.id }
    }
}
