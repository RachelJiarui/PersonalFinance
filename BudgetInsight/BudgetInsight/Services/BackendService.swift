import Foundation
import Combine

class BackendService: ObservableObject {
    static let shared = BackendService()

    // TODO: Update this URL after deploying to Google Cloud Run
    private let baseURL = "http://localhost:8080/api"

    @Published var currentUserId: String?
    @Published var isRegistered: Bool = false

    private var cancellables = Set<AnyCancellable>()

    private init() {
        loadUserId()
    }

    // MARK: - User Registration

    func registerUser(email: String, deviceToken: String? = nil) async throws -> String {
        let url = URL(string: "\(baseURL)/users/register")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "email": email,
            "device_token": deviceToken as Any
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw BackendError.invalidResponse
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let userId = json["user_id"] as? String else {
            throw BackendError.invalidData
        }

        await MainActor.run {
            self.currentUserId = userId
            self.isRegistered = true
            self.saveUserId(userId)
        }

        return userId
    }

    func updateDeviceToken(_ token: String) async throws {
        guard let userId = currentUserId else {
            throw BackendError.notRegistered
        }

        let url = URL(string: "\(baseURL)/users/\(userId)/device-token")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["device_token": token]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw BackendError.invalidResponse
        }
    }

    // MARK: - Transaction Alerts

    func fetchTransactionAlerts(status: String = "all") async throws -> [TransactionAlert] {
        guard let userId = currentUserId else {
            throw BackendError.notRegistered
        }

        let url = URL(string: "\(baseURL)/users/\(userId)/transaction-alerts?status=\(status)")!
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw BackendError.invalidResponse
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let alertsArray = json["alerts"] as? [[String: Any]] else {
            throw BackendError.invalidData
        }

        var alerts: [TransactionAlert] = []
        for alertDict in alertsArray {
            if let id = alertDict["id"] as? String,
               let emailId = alertDict["email_id"] as? String,
               let merchant = alertDict["merchant"] as? String,
               let amount = alertDict["amount"] as? Double,
               let dateString = alertDict["date"] as? String,
               let date = ISO8601DateFormatter().date(from: dateString),
               let rawEmailBody = alertDict["raw_email_body"] as? String {

                let alert = TransactionAlert(
                    id: id,
                    emailId: emailId,
                    merchant: merchant,
                    date: date,
                    amount: amount,
                    rawEmailBody: rawEmailBody
                )
                alerts.append(alert)
            }
        }

        return alerts
    }

    func deleteTransactionAlert(_ alertId: String) async throws {
        guard let userId = currentUserId else {
            throw BackendError.notRegistered
        }

        let url = URL(string: "\(baseURL)/users/\(userId)/transaction-alerts/\(alertId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw BackendError.invalidResponse
        }
    }

    func unlinkTransactionAlert(_ alertId: String) async throws {
        guard let userId = currentUserId else {
            throw BackendError.notRegistered
        }

        let url = URL(string: "\(baseURL)/users/\(userId)/transaction-alerts/\(alertId)/unlink")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw BackendError.invalidResponse
        }
    }

    // MARK: - Transaction Sync

    func syncTransactions() async throws -> [Transaction] {
        guard let userId = currentUserId else {
            throw BackendError.notRegistered
        }

        let url = URL(string: "\(baseURL)/users/\(userId)/transactions")!
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw BackendError.invalidResponse
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let transactionsArray = json["transactions"] as? [[String: Any]] else {
            throw BackendError.invalidData
        }

        var transactions: [Transaction] = []
        for transactionDict in transactionsArray {
            if let amount = transactionDict["amount"] as? Double,
               let merchant = transactionDict["merchant"] as? String,
               let dateString = transactionDict["date"] as? String,
               let date = ISO8601DateFormatter().date(from: dateString) {

                let transaction = Transaction(
                    amount: amount,
                    merchant: merchant,
                    date: date,
                    category: .other
                )
                transactions.append(transaction)
            }
        }

        return transactions
    }

    func uploadTransaction(_ transaction: Transaction) async throws {
        guard let userId = currentUserId else {
            throw BackendError.notRegistered
        }

        let url = URL(string: "\(baseURL)/users/\(userId)/transactions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let dateFormatter = ISO8601DateFormatter()
        var body: [String: Any] = [
            "amount": transaction.amount,
            "merchant": transaction.merchant,
            "date": dateFormatter.string(from: transaction.date)
        ]

        // Add linked alert ID if present
        if let linkedAlertId = transaction.linkedEmailAlertId {
            body["linkedEmailAlertId"] = linkedAlertId
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
            throw BackendError.invalidResponse
        }
    }

    func updateTransaction(_ transactionId: String, updateData: [String: Any]) async throws {
        guard let userId = currentUserId else {
            throw BackendError.notRegistered
        }

        let url = URL(string: "\(baseURL)/users/\(userId)/transactions/\(transactionId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: updateData)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw BackendError.invalidResponse
        }
    }

    func deleteTransaction(_ transactionId: String) async throws {
        guard let userId = currentUserId else {
            throw BackendError.notRegistered
        }

        let url = URL(string: "\(baseURL)/users/\(userId)/transactions/\(transactionId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw BackendError.invalidResponse
        }
    }

    func linkTransactionToAlert(transactionId: String, alertId: String) async throws {
        guard let userId = currentUserId else {
            throw BackendError.notRegistered
        }

        let url = URL(string: "\(baseURL)/users/\(userId)/transactions/\(transactionId)/link-alert")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["alert_id": alertId]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw BackendError.invalidResponse
        }
    }

    // MARK: - Budget Sync

    func syncBudget() async throws {
        guard let userId = currentUserId else {
            throw BackendError.notRegistered
        }

        let budgetService = BudgetService.shared
        guard let allocation = budgetService.budgetAllocation,
              let income = budgetService.userIncome else {
            return
        }

        let url = URL(string: "\(baseURL)/users/\(userId)/budget")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let categories = allocation.categories.map { category in
            return [
                "name": category.name,
                "percentage": category.percentage,
                "icon": category.icon,
                "color": category.color
            ] as [String: Any]
        }

        let body: [String: Any] = [
            "annual_salary": income.annualSalary,
            "contribution_401k": income.contribution401k,
            "monthly_take_home": income.monthlyTakeHome,
            "categories": categories
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw BackendError.invalidResponse
        }
    }

    func fetchBudget() async throws -> (UserIncome, BudgetAllocation)? {
        guard let userId = currentUserId else {
            throw BackendError.notRegistered
        }

        let url = URL(string: "\(baseURL)/users/\(userId)/budget")!
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendError.invalidResponse
        }

        // If no budget exists, return nil
        if httpResponse.statusCode == 404 {
            return nil
        }

        guard httpResponse.statusCode == 200 else {
            throw BackendError.invalidResponse
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let annualSalary = json["annual_salary"] as? Double,
              let contribution401k = json["contribution_401k"] as? Double,
              let categoriesArray = json["categories"] as? [[String: Any]] else {
            throw BackendError.invalidData
        }

        // Recreate UserIncome using TaxService
        let income = TaxService.shared.calculateAllTaxes(
            annualSalary: annualSalary,
            contribution401k: contribution401k
        )

        // Recreate BudgetAllocation
        var categories: [BudgetCategory] = []
        for categoryDict in categoriesArray {
            if let name = categoryDict["name"] as? String,
               let percentage = categoryDict["percentage"] as? Double,
               let icon = categoryDict["icon"] as? String,
               let color = categoryDict["color"] as? String {

                let category = BudgetCategory(
                    name: name,
                    percentage: percentage,
                    icon: icon,
                    color: color
                )
                categories.append(category)
            }
        }

        let allocation = BudgetAllocation(categories: categories)

        return (income, allocation)
    }

    func deleteBudget() async throws {
        guard let userId = currentUserId else {
            throw BackendError.notRegistered
        }

        let url = URL(string: "\(baseURL)/users/\(userId)/budget")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw BackendError.invalidResponse
        }
    }

    func updateBudgetCategories(_ categories: [BudgetCategory]) async throws {
        guard let userId = currentUserId else {
            throw BackendError.notRegistered
        }

        let url = URL(string: "\(baseURL)/users/\(userId)/budget/categories")!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let categoriesArray = categories.map { category in
            return [
                "name": category.name,
                "percentage": category.percentage,
                "icon": category.icon,
                "color": category.color
            ] as [String: Any]
        }

        let body: [String: Any] = ["categories": categoriesArray]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw BackendError.invalidResponse
        }
    }

    func updateBudgetIncome(_ income: UserIncome) async throws {
        guard let userId = currentUserId else {
            throw BackendError.notRegistered
        }

        let url = URL(string: "\(baseURL)/users/\(userId)/budget/income")!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "annual_salary": income.annualSalary,
            "contribution_401k": income.contribution401k
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw BackendError.invalidResponse
        }
    }

    // MARK: - Snapshot Sync

    func syncSnapshots() async throws {
        guard let userId = currentUserId else {
            throw BackendError.notRegistered
        }

        let snapshotService = SnapshotService.shared

        // Upload monthly snapshots
        for snapshot in snapshotService.monthlySnapshots {
            try await uploadSnapshot(userId: userId, snapshot: snapshot, isYearly: false)
        }

        // Upload yearly snapshots
        for snapshot in snapshotService.yearlySnapshots {
            try await uploadSnapshot(userId: userId, snapshot: snapshot, isYearly: true)
        }
    }

    private func uploadSnapshot(userId: String, snapshot: PeriodSnapshot, isYearly: Bool) async throws {
        let url = URL(string: "\(baseURL)/users/\(userId)/snapshots")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let dateFormatter = ISO8601DateFormatter()
        var body: [String: Any] = [
            "year": snapshot.year,
            "monthly_take_home": snapshot.monthlyTakeHome,
            "total_spending": snapshot.totalSpending,
            "savings": snapshot.savings,
            "transaction_count": snapshot.transactionCount,
            "created_at": dateFormatter.string(from: snapshot.createdAt)
        ]

        if let month = snapshot.month {
            body["month"] = month
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw BackendError.invalidResponse
        }
    }

    // MARK: - Persistence

    private func saveUserId(_ userId: String) {
        UserDefaults.standard.set(userId, forKey: "backend_user_id")
    }

    private func loadUserId() {
        if let userId = UserDefaults.standard.string(forKey: "backend_user_id") {
            self.currentUserId = userId
            self.isRegistered = true
        }
    }

    func clearUserData() {
        UserDefaults.standard.removeObject(forKey: "backend_user_id")
        self.currentUserId = nil
        self.isRegistered = false
    }
}

// MARK: - Errors

enum BackendError: LocalizedError {
    case notRegistered
    case invalidResponse
    case invalidData

    var errorDescription: String? {
        switch self {
        case .notRegistered:
            return "User is not registered with the backend server"
        case .invalidResponse:
            return "Invalid response from backend server"
        case .invalidData:
            return "Invalid data received from backend server"
        }
    }
}
