import Combine
import Foundation

class BackendService: ObservableObject {
    static let shared = BackendService()

    // Backend URL
    private let baseURL: String

    @Published var isConnected: Bool = false

    private var cancellables = Set<AnyCancellable>()

    private init() {
        // Try to get Cloud Run URL from environment or use production URL
        if let cloudRunURL = ProcessInfo.processInfo.environment["BACKEND_URL"] {
            self.baseURL = cloudRunURL
        } else {
            // Production Cloud Run URL
            self.baseURL = "https://budgetinsight-backend-ofgbl6d3ea-uc.a.run.app/api"
        }
    }

    // MARK: - Health Check

    func checkHealth() async throws -> Bool {
        let url = URL(string: "\(baseURL.replacingOccurrences(of: "/api", with: ""))/health")!
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200
        else {
            return false
        }

        return true
    }

    // MARK: - Device Token

    func updateDeviceToken(_ token: String) async throws {
        let url = URL(string: "\(baseURL)/settings/device-token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["device_token": token]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200
        else {
            throw BackendError.invalidResponse
        }
    }

    // MARK: - Transactions

    func fetchTransactions() async throws -> [Transaction] {
        let url = URL(string: "\(baseURL)/transactions")!
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200
        else {
            throw BackendError.invalidResponse
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let transactionsArray = json["transactions"] as? [[String: Any]]
        else {
            throw BackendError.invalidData
        }

        let dateFormatter = ISO8601DateFormatter()
        var transactions: [Transaction] = []

        for dict in transactionsArray {
            if let id = dict["id"] as? String,
                let amount = dict["amount"] as? Double,
                let title = dict["title"] as? String,
                let categoryId = dict["category_id"] as? String,
                let isExpense = dict["is_expense"] as? Bool,
                let dateString = dict["date"] as? String,
                let date = dateFormatter.date(from: dateString),
                let timestampString = dict["timestamp"] as? String,
                let timestamp = dateFormatter.date(from: timestampString)
            {

                let linkedEmailAlertId = dict["linked_email_alert_id"] as? String

                let transaction = Transaction(
                    id: id,
                    amount: amount,
                    date: date,
                    title: title,
                    categoryId: categoryId,
                    isExpense: isExpense,
                    timestamp: timestamp,
                    linkedEmailAlertId: linkedEmailAlertId
                )
                transactions.append(transaction)
            }
        }

        return transactions
    }

    func createTransaction(_ transaction: Transaction) async throws -> String {
        let url = URL(string: "\(baseURL)/transactions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let dateFormatter = ISO8601DateFormatter()
        var body: [String: Any] = [
            "amount": transaction.amount,
            "title": transaction.title,
            "category_id": transaction.categoryId,
            "is_expense": transaction.isExpense,
            "date": dateFormatter.string(from: transaction.date),
            "timestamp": dateFormatter.string(from: transaction.timestamp),
        ]

        if let linkedAlertId = transaction.linkedEmailAlertId {
            body["linked_email_alert_id"] = linkedAlertId
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
            (200...299).contains(httpResponse.statusCode)
        else {
            throw BackendError.invalidResponse
        }

        // Parse response to get Firestore-generated ID
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let id = json["id"] as? String
        else {
            throw BackendError.invalidData
        }

        return id
    }

    func deleteTransaction(_ transactionId: String) async throws {
        let url = URL(string: "\(baseURL)/transactions/\(transactionId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200
        else {
            throw BackendError.invalidResponse
        }
    }

    func linkTransactionToAlert(transactionId: String, alertId: String) async throws {
        let url = URL(string: "\(baseURL)/transactions/\(transactionId)/link-alert")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["alert_id": alertId]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200
        else {
            throw BackendError.invalidResponse
        }
    }

    // MARK: - Transaction Alerts

    func fetchTransactionAlerts(resolved: Bool? = nil) async throws -> [TransactionAlert] {
        var urlString = "\(baseURL)/transaction-alerts"
        if let resolved = resolved {
            let status = resolved ? "linked" : "unlinked"
            urlString += "?status=\(status)"
        }

        let url = URL(string: urlString)!
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200
        else {
            throw BackendError.invalidResponse
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let alertsArray = json["alerts"] as? [[String: Any]]
        else {
            throw BackendError.invalidData
        }

        let dateFormatter = ISO8601DateFormatter()
        var alerts: [TransactionAlert] = []

        for dict in alertsArray {
            if let id = dict["id"] as? String,
                let emailId = dict["email_id"] as? String,
                let merchant = dict["merchant"] as? String,
                let amount = dict["amount"] as? Double,
                let dateString = dict["date"] as? String,
                let date = dateFormatter.date(from: dateString),
                let rawEmailBody = dict["raw_email_body"] as? String,
                let receivedAtString = dict["received_at"] as? String,
                let receivedAt = dateFormatter.date(from: receivedAtString)
            {

                let linkedTransactionId = dict["linked_transaction_id"] as? String

                let alert = TransactionAlert(
                    id: id,
                    emailId: emailId,
                    merchant: merchant,
                    date: date,
                    amount: amount,
                    rawEmailBody: rawEmailBody,
                    receivedAt: receivedAt,
                    linkedTransactionId: linkedTransactionId
                )
                alerts.append(alert)
            }
        }

        return alerts
    }

    func deleteTransactionAlert(_ alertId: String) async throws {
        let url = URL(string: "\(baseURL)/transaction-alerts/\(alertId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200
        else {
            throw BackendError.invalidResponse
        }
    }

    func unlinkTransactionAlert(_ alertId: String) async throws {
        let url = URL(string: "\(baseURL)/transaction-alerts/\(alertId)/unlink")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200
        else {
            throw BackendError.invalidResponse
        }
    }

    // MARK: - Budget Categories

    func fetchBudgetCategories() async throws -> [BudgetCategory] {
        let url = URL(string: "\(baseURL)/budget-categories")!
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200
        else {
            throw BackendError.invalidResponse
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let categoriesArray = json["categories"] as? [[String: Any]]
        else {
            throw BackendError.invalidData
        }

        var categories: [BudgetCategory] = []

        for dict in categoriesArray {
            if let id = dict["id"] as? String,
                let name = dict["name"] as? String,
                let percentage = dict["percentage"] as? Double,
                let icon = dict["icon"] as? String,
                let isActive = dict["is_active"] as? Bool
            {

                let category = BudgetCategory(
                    id: id,
                    name: name,
                    percentage: percentage,
                    icon: icon,
                    isActive: isActive
                )
                categories.append(category)
            }
        }

        return categories
    }

    func createBudgetCategory(_ category: BudgetCategory) async throws -> String {
        let url = URL(string: "\(baseURL)/budget-categories")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "name": category.name,
            "percentage": category.percentage,
            "icon": category.icon,
            "is_active": category.isActive,
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
            (200...299).contains(httpResponse.statusCode)
        else {
            throw BackendError.invalidResponse
        }

        // Parse response to get Firestore-generated ID
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let id = json["id"] as? String
        else {
            throw BackendError.invalidData
        }

        return id
    }

    func updateBudgetCategory(categoryId: String, updates: [String: Any]) async throws {
        let url = URL(string: "\(baseURL)/budget-categories/\(categoryId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: updates)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200
        else {
            throw BackendError.invalidResponse
        }
    }

    func deleteBudgetCategory(_ categoryId: String) async throws {
        let url = URL(string: "\(baseURL)/budget-categories/\(categoryId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200
        else {
            throw BackendError.invalidResponse
        }
    }

    // MARK: - Budget Plans

    func fetchActiveBudgetPlan() async throws -> BudgetPlan? {
        let url = URL(string: "\(baseURL)/budget-plans/active")!
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendError.invalidResponse
        }

        if httpResponse.statusCode == 404 {
            return nil
        }

        guard httpResponse.statusCode == 200 else {
            throw BackendError.invalidResponse
        }

        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let id = dict["id"] as? String,
            let year = dict["year"] as? Int,
            let annualSalaryGross = dict["annual_salary_gross"] as? Double,
            let userIncomeId = dict["user_income_id"] as? String,
            let categoryIds = dict["category_ids"] as? [String]
        else {
            throw BackendError.invalidData
        }

        return BudgetPlan(
            id: id,
            year: year,
            annualSalaryGross: annualSalaryGross,
            userIncomeId: userIncomeId,
            categoryIds: categoryIds
        )
    }

    func createBudgetPlan(_ plan: BudgetPlan) async throws -> String {
        let url = URL(string: "\(baseURL)/budget-plans")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "year": plan.year,
            "annual_salary_gross": plan.annualSalaryGross,
            "user_income_id": plan.userIncomeId,
            "category_ids": plan.categoryIds,
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
            (200...299).contains(httpResponse.statusCode)
        else {
            throw BackendError.invalidResponse
        }

        // Parse response to get Firestore-generated ID
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let id = json["id"] as? String
        else {
            throw BackendError.invalidData
        }

        return id
    }

    // MARK: - User Income

    func fetchUserIncome(incomeId: String) async throws -> UserIncome? {
        let url = URL(string: "\(baseURL)/user-incomes/\(incomeId)")!
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendError.invalidResponse
        }

        if httpResponse.statusCode == 404 {
            return nil
        }

        guard httpResponse.statusCode == 200 else {
            throw BackendError.invalidResponse
        }

        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let id = dict["id"] as? String,
            let year = dict["year"] as? Int,
            let annualSalary = dict["annual_salary"] as? Double,
            let contribution401k = dict["contribution_401k"] as? Double,
            let federalTax = dict["federal_tax"] as? Double,
            let socialSecurityTax = dict["social_security_tax"] as? Double,
            let medicareTax = dict["medicare_tax"] as? Double,
            let nyStateTax = dict["ny_state_tax"] as? Double,
            let nycTax = dict["nyc_tax"] as? Double
        else {
            throw BackendError.invalidData
        }

        return UserIncome(
            id: id,
            year: year,
            annualSalary: annualSalary,
            contribution401k: contribution401k,
            federalTax: federalTax,
            socialSecurityTax: socialSecurityTax,
            medicareTax: medicareTax,
            nyStateTax: nyStateTax,
            nycTax: nycTax
        )
    }

    func createUserIncome(_ income: UserIncome) async throws -> String {
        let url = URL(string: "\(baseURL)/user-incomes")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "year": income.year,
            "annual_salary": income.annualSalary,
            "contribution_401k": income.contribution401k,
            "federal_tax": income.federalTax,
            "social_security_tax": income.socialSecurityTax,
            "medicare_tax": income.medicareTax,
            "ny_state_tax": income.nyStateTax,
            "nyc_tax": income.nycTax,
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
            (200...299).contains(httpResponse.statusCode)
        else {
            throw BackendError.invalidResponse
        }

        // Parse response to get Firestore-generated ID
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let id = json["id"] as? String
        else {
            throw BackendError.invalidData
        }

        return id
    }

    // MARK: - Snapshots

    func fetchSnapshots(periodType: String = "monthly") async throws -> [PeriodSnapshot] {
        let url = URL(string: "\(baseURL)/snapshots?type=\(periodType)")!
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200
        else {
            throw BackendError.invalidResponse
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let snapshotsArray = json["snapshots"] as? [[String: Any]]
        else {
            throw BackendError.invalidData
        }

        let dateFormatter = ISO8601DateFormatter()
        var snapshots: [PeriodSnapshot] = []

        for dict in snapshotsArray {
            if let idString = dict["id"] as? String,
                let id = UUID(uuidString: idString),
                let year = dict["year"] as? Int,
                let monthlyTakeHome = dict["monthly_take_home"] as? Double,
                let totalSpending = dict["total_spending"] as? Double,
                let savings = dict["savings"] as? Double,
                let transactionCount = dict["transaction_count"] as? Int,
                let createdAtString = dict["created_at"] as? String,
                let createdAt = dateFormatter.date(from: createdAtString)
            {

                let month = dict["month"] as? Int

                let snapshot = PeriodSnapshot(
                    id: id,
                    year: year,
                    month: month,
                    monthlyTakeHome: monthlyTakeHome,
                    totalSpending: totalSpending,
                    savings: savings,
                    createdAt: createdAt,
                    transactionCount: transactionCount
                )
                snapshots.append(snapshot)
            }
        }

        return snapshots
    }

    func createSnapshot(_ snapshot: PeriodSnapshot) async throws -> String {
        let url = URL(string: "\(baseURL)/snapshots")!
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
            "created_at": dateFormatter.string(from: snapshot.createdAt),
        ]

        if let month = snapshot.month {
            body["month"] = month
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
            (200...299).contains(httpResponse.statusCode)
        else {
            throw BackendError.invalidResponse
        }

        // Parse response to get Firestore-generated ID
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let id = json["id"] as? String
        else {
            throw BackendError.invalidData
        }

        return id
    }
}

// MARK: - Errors

public enum BackendError: LocalizedError {
    case invalidResponse
    case invalidData
    case notConnected

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from backend server"
        case .invalidData:
            return "Invalid data received from backend server"
        case .notConnected:
            return "Not connected to backend server"
        }
    }
}
