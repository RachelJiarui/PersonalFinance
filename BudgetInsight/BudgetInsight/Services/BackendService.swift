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
            self.baseURL = "https://budgetinsight-backend-575183170824.us-central1.run.app/api"
        }
        print("🌐 [BackendService] Initialized with base URL: \(self.baseURL)")
    }

    // MARK: - Health Check

    func checkHealth() async throws -> Bool {
        let url = URL(string: "\(baseURL.replacingOccurrences(of: "/api", with: ""))/health")!
        let (_, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200
        else {
            return false
        }

        return true
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
                let isExpense = dict["is_expense"] as? Bool,
                let dateString = dict["date"] as? String,
                let date = dateFormatter.date(from: dateString),
                let timestampString = dict["timestamp"] as? String,
                let timestamp = dateFormatter.date(from: timestampString)
            {
                // Optional transaction_alert_id field
                let transactionAlertId = dict["transaction_alert_id"] as? String

                let transaction = Transaction(
                    id: id,
                    amount: amount,
                    date: date,
                    title: title,
                    isExpense: isExpense,
                    timestamp: timestamp,
                    transactionAlertId: transactionAlertId
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
            "is_expense": transaction.isExpense,
            "date": dateFormatter.string(from: transaction.date),
            "timestamp": dateFormatter.string(from: transaction.timestamp),
        ]

        // Add transaction_alert_id if present
        if let alertId = transaction.transactionAlertId {
            body["transaction_alert_id"] = alertId
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendError.invalidResponse
        }

        if !(200...299).contains(httpResponse.statusCode) {
            // Try to parse error message from response
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let errorMessage = errorJson["error"] as? String
            {
                print("❌ [BackendService] Budget plan creation failed: \(errorMessage)")
            } else {
                print(
                    "❌ [BackendService] Budget plan creation failed with status: \(httpResponse.statusCode)"
                )
            }
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

    func updateTransaction(transactionId: String, updates: [String: Any]) async throws {
        let url = URL(string: "\(baseURL)/transactions/\(transactionId)")!
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
                let isStarred = dict["is_starred"] as? Bool ?? false

                let category = BudgetCategory(
                    id: id,
                    name: name,
                    percentage: percentage,
                    icon: icon,
                    isActive: isActive,
                    isStarred: isStarred
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
            "is_starred": category.isStarred,
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendError.invalidResponse
        }

        if !(200...299).contains(httpResponse.statusCode) {
            // Try to parse error message from response
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let errorMessage = errorJson["error"] as? String
            {
                print(
                    "❌ [BackendService] Create budget plan failed (\(httpResponse.statusCode)): \(errorMessage)"
                )
            } else {
                print(
                    "❌ [BackendService] Create budget plan failed with status: \(httpResponse.statusCode)"
                )
            }
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

        return try parseBudgetPlanResponse(data)
    }

    func fetchBudgetPlanForDate(_ dateString: String) async throws -> BudgetPlan? {
        let url = URL(string: "\(baseURL)/budget-plans/for-date/\(dateString)")!
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendError.invalidResponse
        }

        if httpResponse.statusCode == 404 {
            return nil  // No plan found for this date
        }

        guard httpResponse.statusCode == 200 else {
            throw BackendError.invalidResponse
        }

        return try parseBudgetPlanResponse(data)
    }

    private func parseBudgetPlanResponse(_ data: Data) throws -> BudgetPlan {
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let id = dict["id"] as? String,
            let createdAtString = dict["created_at"] as? String,
            let annualSalary = dict["annual_salary"] as? Double,
            let contribution401k = dict["contribution_401k"] as? Double,
            let federalTax = dict["federal_tax"] as? Double,
            let socialSecurityTax = dict["social_security_tax"] as? Double,
            let medicareTax = dict["medicare_tax"] as? Double,
            let nyStateTax = dict["ny_state_tax"] as? Double,
            let nycTax = dict["nyc_tax"] as? Double,
            let categoryIds = dict["category_ids"] as? [String]
        else {
            throw BackendError.invalidData
        }

        let dateFormatter = ISO8601DateFormatter()
        guard let createdAt = dateFormatter.date(from: createdAtString) else {
            throw BackendError.invalidData
        }

        var endDate: Date?
        if let endDateString = dict["end_date"] as? String {
            endDate = dateFormatter.date(from: endDateString)
        }

        return BudgetPlan(
            id: id,
            createdAt: createdAt,
            endDate: endDate,
            annualSalary: annualSalary,
            contribution401k: contribution401k,
            federalTax: federalTax,
            socialSecurityTax: socialSecurityTax,
            medicareTax: medicareTax,
            nyStateTax: nyStateTax,
            nycTax: nycTax,
            categoryIds: categoryIds
        )
    }

    func createBudgetPlan(_ plan: BudgetPlan) async throws -> String {
        let url = URL(string: "\(baseURL)/budget-plans")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let dateFormatter = ISO8601DateFormatter()

        var body: [String: Any] = [
            "created_at": dateFormatter.string(from: plan.createdAt),
            "annual_salary": plan.annualSalary,
            "contribution_401k": plan.contribution401k,
            "federal_tax": plan.federalTax,
            "social_security_tax": plan.socialSecurityTax,
            "medicare_tax": plan.medicareTax,
            "ny_state_tax": plan.nyStateTax,
            "nyc_tax": plan.nycTax,
            "category_ids": plan.categoryIds,
        ]

        // Add end_date (null for active plans)
        if let endDate = plan.endDate {
            body["end_date"] = dateFormatter.string(from: endDate)
        } else {
            body["end_date"] = NSNull()
        }

        print("🌐 [BackendService] Creating budget plan with body: \(body)")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        if let bodyString = String(data: request.httpBody!, encoding: .utf8) {
            print("📤 [BackendService] Request body JSON: \(bodyString)")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ [BackendService] Invalid response type")
            throw BackendError.invalidResponse
        }

        print("📥 [BackendService] Response status: \(httpResponse.statusCode)")

        if let responseString = String(data: data, encoding: .utf8) {
            print("📥 [BackendService] Response body: \(responseString)")
        }

        if !(200...299).contains(httpResponse.statusCode) {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let errorMessage = errorJson["error"] as? String
            {
                print(
                    "❌ [BackendService] Create budget plan failed (\(httpResponse.statusCode)): \(errorMessage)"
                )
            } else {
                print(
                    "❌ [BackendService] Create budget plan failed with status: \(httpResponse.statusCode)"
                )
            }
            throw BackendError.invalidResponse
        }

        // Parse response to get Firestore-generated ID
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let id = json["id"] as? String
        else {
            print("❌ [BackendService] Failed to parse response JSON or extract ID")
            throw BackendError.invalidData
        }

        print("✅ [BackendService] Successfully created budget plan with ID: \(id)")
        return id
    }

    func updateBudgetPlan(planId: String, updates: [String: Any]) async throws {
        let url = URL(string: "\(baseURL)/budget-plans/\(planId)")!
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

    func fetchBudgetPlan(planId: String) async throws -> BudgetPlan? {
        let url = URL(string: "\(baseURL)/budget-plans/\(planId)")!
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

        return try parseBudgetPlanResponse(data)
    }

    // MARK: - Funds

    func fetchFunds() async throws -> [Fund] {
        let url = URL(string: "\(baseURL)/funds")!
        print("🔗 [BackendService] Fetching funds from: \(url.absoluteString)")
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200
        else {
            if let httpResponse = response as? HTTPURLResponse {
                print("❌ [BackendService] Invalid response: HTTP \(httpResponse.statusCode)")
            }
            throw BackendError.invalidResponse
        }
        print("✅ [BackendService] Received funds response: HTTP 200")

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let fundsArray = json["funds"] as? [[String: Any]]
        else {
            print("❌ [BackendService] Failed to parse JSON response")
            throw BackendError.invalidData
        }

        // Backend returns dates in RFC 2822 format: "Mon, 29 Dec 2025 19:03:01 GMT"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        var funds: [Fund] = []

        for dict in fundsArray {
            if let id = dict["id"] as? String,
                let name = dict["name"] as? String,
                let icon = dict["icon"] as? String,
                let description = dict["description"] as? String,
                let balance = dict["balance"] as? Double,
                let isActive = dict["is_active"] as? Bool,
                let createdAtString = dict["created_at"] as? String,
                let createdAt = dateFormatter.date(from: createdAtString)
            {

                let goal = dict["goal"] as? Double
                let isDefault = dict["is_default"] as? Bool ?? false
                var deadline: Date?
                if let deadlineString = dict["deadline"] as? String {
                    deadline = dateFormatter.date(from: deadlineString)
                }

                let fund = Fund(
                    id: id,
                    name: name,
                    icon: icon,
                    description: description,
                    balance: balance,
                    goal: goal,
                    deadline: deadline,
                    createdAt: createdAt,
                    isActive: isActive,
                    isDefault: isDefault
                )
                funds.append(fund)
            } else {
                print("⚠️ [BackendService] Failed to parse fund: \(dict)")
            }
        }

        print("✅ [BackendService] Successfully parsed \(funds.count) funds")
        return funds
    }

    func createFund(_ fund: Fund) async throws -> String {
        let url = URL(string: "\(baseURL)/funds")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let dateFormatter = ISO8601DateFormatter()
        var body: [String: Any] = [
            "name": fund.name,
            "icon": fund.icon,
            "description": fund.description,
            "balance": fund.balance,
            "is_active": fund.isActive,
            "is_default": fund.isDefault,
            "created_at": dateFormatter.string(from: fund.createdAt),
        ]

        if let goal = fund.goal {
            body["goal"] = goal
        }
        if let deadline = fund.deadline {
            body["deadline"] = dateFormatter.string(from: deadline)
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
            (200...299).contains(httpResponse.statusCode)
        else {
            throw BackendError.invalidResponse
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let id = json["id"] as? String
        else {
            throw BackendError.invalidData
        }

        return id
    }

    func updateFund(fundId: String, updates: [String: Any]) async throws {
        let url = URL(string: "\(baseURL)/funds/\(fundId)")!
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

    func deleteFund(_ fundId: String) async throws {
        let url = URL(string: "\(baseURL)/funds/\(fundId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200
        else {
            throw BackendError.invalidResponse
        }
    }

    // MARK: - Debts

    func fetchDebts() async throws -> [Debt] {
        let url = URL(string: "\(baseURL)/debts")!
        print("🔗 [BackendService] Fetching debts from: \(url.absoluteString)")
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200
        else {
            if let httpResponse = response as? HTTPURLResponse {
                print("❌ [BackendService] Invalid response: HTTP \(httpResponse.statusCode)")
            }
            throw BackendError.invalidResponse
        }
        print("✅ [BackendService] Received debts response: HTTP 200")

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let debtsArray = json["debts"] as? [[String: Any]]
        else {
            print("❌ [BackendService] Failed to parse JSON response")
            throw BackendError.invalidData
        }

        // Backend returns dates in RFC 2822 format: "Mon, 29 Dec 2025 19:03:01 GMT"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        var debts: [Debt] = []

        for dict in debtsArray {
            if let id = dict["id"] as? String,
                let name = dict["name"] as? String,
                let icon = dict["icon"] as? String,
                let description = dict["description"] as? String,
                let balance = dict["balance"] as? Double,
                let goal = dict["goal"] as? Double,
                let isActive = dict["is_active"] as? Bool,
                let createdAtString = dict["created_at"] as? String,
                let createdAt = dateFormatter.date(from: createdAtString)
            {

                let isDefault = dict["is_default"] as? Bool ?? false
                var deadline: Date?
                if let deadlineString = dict["deadline"] as? String {
                    deadline = dateFormatter.date(from: deadlineString)
                }

                let debt = Debt(
                    id: id,
                    name: name,
                    icon: icon,
                    description: description,
                    balance: balance,
                    goal: goal,
                    deadline: deadline,
                    createdAt: createdAt,
                    isActive: isActive,
                    isDefault: isDefault
                )
                debts.append(debt)
            } else {
                print("⚠️ [BackendService] Failed to parse debt: \(dict)")
            }
        }

        print("✅ [BackendService] Successfully parsed \(debts.count) debts")
        return debts
    }

    func createDebt(_ debt: Debt) async throws -> String {
        let url = URL(string: "\(baseURL)/debts")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let dateFormatter = ISO8601DateFormatter()
        var body: [String: Any] = [
            "name": debt.name,
            "icon": debt.icon,
            "description": debt.description,
            "balance": debt.balance,
            "goal": debt.goal,
            "is_active": debt.isActive,
            "is_default": debt.isDefault,
            "created_at": dateFormatter.string(from: debt.createdAt),
        ]

        if let deadline = debt.deadline {
            body["deadline"] = dateFormatter.string(from: deadline)
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
            (200...299).contains(httpResponse.statusCode)
        else {
            throw BackendError.invalidResponse
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let id = json["id"] as? String
        else {
            throw BackendError.invalidData
        }

        return id
    }

    func updateDebt(debtId: String, updates: [String: Any]) async throws {
        let url = URL(string: "\(baseURL)/debts/\(debtId)")!
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

    func deleteDebt(_ debtId: String) async throws {
        let url = URL(string: "\(baseURL)/debts/\(debtId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200
        else {
            throw BackendError.invalidResponse
        }
    }

    // MARK: - Transaction Allocations

    func fetchAllocations(
        transactionId: String? = nil, destinationType: AllocationType? = nil,
        destinationId: String? = nil
    ) async throws -> [TransactionAllocation] {
        var urlString = "\(baseURL)/allocations"
        var queryParams: [String] = []

        if let transactionId = transactionId {
            queryParams.append("transaction_id=\(transactionId)")
        }
        if let destinationType = destinationType {
            queryParams.append("destination_type=\(destinationType.rawValue)")
        }
        if let destinationId = destinationId {
            queryParams.append("destination_id=\(destinationId)")
        }

        if !queryParams.isEmpty {
            urlString += "?" + queryParams.joined(separator: "&")
        }

        let url = URL(string: urlString)!
        print("🔗 [BackendService] Fetching allocations from: \(urlString)")
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200
        else {
            print(
                "❌ [BackendService] Allocations fetch failed with status: \((response as? HTTPURLResponse)?.statusCode ?? -1)"
            )
            throw BackendError.invalidResponse
        }

        print("✅ [BackendService] Received allocations response: HTTP \(httpResponse.statusCode)")

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let allocationsArray = json["allocations"] as? [[String: Any]]
        else {
            print("❌ [BackendService] Failed to parse allocations JSON")
            throw BackendError.invalidData
        }

        print("📊 [BackendService] Raw allocations count from backend: \(allocationsArray.count)")

        let dateFormatter = ISO8601DateFormatter()
        var allocations: [TransactionAllocation] = []

        for dict in allocationsArray {
            if let id = dict["id"] as? String,
                let transactionId = dict["transaction_id"] as? String,
                let destinationTypeString = dict["destination_type"] as? String,
                let destinationType = AllocationType(rawValue: destinationTypeString),
                let destinationId = dict["destination_id"] as? String,
                let amount = dict["amount"] as? Double,
                let allocatedAtString = dict["allocated_at"] as? String,
                let allocatedAt = dateFormatter.date(from: allocatedAtString)
            {

                let allocation = TransactionAllocation(
                    id: id,
                    transactionId: transactionId,
                    destinationType: destinationType,
                    destinationId: destinationId,
                    amount: amount,
                    allocatedAt: allocatedAt
                )
                allocations.append(allocation)
            } else {
                print("⚠️ [BackendService] Failed to parse allocation: \(dict)")
            }
        }

        print("✅ [BackendService] Successfully parsed \(allocations.count) allocations")

        return allocations
    }

    func createAllocation(_ allocation: TransactionAllocation) async throws -> String {
        let url = URL(string: "\(baseURL)/allocations")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let dateFormatter = ISO8601DateFormatter()
        let body: [String: Any] = [
            "transaction_id": allocation.transactionId,
            "destination_type": allocation.destinationType.rawValue,
            "destination_id": allocation.destinationId,
            "amount": allocation.amount,
            "allocated_at": dateFormatter.string(from: allocation.allocatedAt),
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
            (200...299).contains(httpResponse.statusCode)
        else {
            throw BackendError.invalidResponse
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let id = json["id"] as? String
        else {
            throw BackendError.invalidData
        }

        return id
    }

    func updateAllocation(allocationId: String, updates: [String: Any]) async throws {
        let url = URL(string: "\(baseURL)/allocations/\(allocationId)")!
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

    func deleteAllocation(_ allocationId: String) async throws {
        let url = URL(string: "\(baseURL)/allocations/\(allocationId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200
        else {
            throw BackendError.invalidResponse
        }
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

        var snapshots: [PeriodSnapshot] = []

        for dict in snapshotsArray {
            // Required fields (except id and created_at which we handle specially)
            guard let year = dict["year"] as? Int,
                let monthlyTakeHome = dict["monthly_take_home"] as? Double,
                let totalSpending = dict["total_spending"] as? Double,
                let savings = dict["savings"] as? Double,
                let budgetPlanId = dict["budget_plan_id"] as? String
            else {
                continue
            }

            // Parse transaction counts - support both old and new field names
            let expenseTransactionCount: Int
            let incomeTransactionCount: Int
            if let expenseCount = dict["expense_transaction_count"] as? Int,
                let incomeCount = dict["income_transaction_count"] as? Int
            {
                // New format with separate counts
                expenseTransactionCount = expenseCount
                incomeTransactionCount = incomeCount
            } else if let transactionCount = dict["transaction_count"] as? Int {
                // Legacy format - assume all were expense transactions
                expenseTransactionCount = transactionCount
                incomeTransactionCount = 0
            } else {
                continue
            }

            // Generate a deterministic UUID from the Firestore document ID
            // This ensures the same document always maps to the same UUID
            let id: UUID
            if let idString = dict["id"] as? String {
                // Create a deterministic UUID using a hash of the Firestore ID
                id = UUID(uuidString: idString) ?? uuidFromString(idString)
            } else {
                id = UUID()
            }

            // Parse created_at with fallback - Firestore timestamps may come in various formats
            let createdAt = parseFirestoreDate(dict["created_at"]) ?? Date()

            let month = dict["month"] as? Int

            let snapshot = PeriodSnapshot(
                id: id,
                year: year,
                month: month,
                monthlyTakeHome: monthlyTakeHome,
                totalSpending: totalSpending,
                savings: savings,
                budgetPlanId: budgetPlanId,
                createdAt: createdAt,
                expenseTransactionCount: expenseTransactionCount,
                incomeTransactionCount: incomeTransactionCount
            )
            snapshots.append(snapshot)
        }

        return snapshots
    }

    /// Creates a deterministic UUID from a string (for Firestore document IDs)
    private func uuidFromString(_ string: String) -> UUID {
        // Create a deterministic UUID by hashing the string
        // Use the string's hash to create a consistent UUID
        var hasher = Hasher()
        hasher.combine(string)
        let hash = hasher.finalize()

        // Create a UUID-like string from the hash
        let hashString = String(format: "%08x", abs(hash))
        let uuidString =
            "00000000-0000-0000-0000-\(hashString.padding(toLength: 12, withPad: "0", startingAt: 0))"
        return UUID(uuidString: uuidString) ?? UUID()
    }

    /// Parses Firestore dates which may come in various formats
    private func parseFirestoreDate(_ value: Any?) -> Date? {
        guard let value = value else { return nil }

        // Try as ISO8601 string first
        if let stringValue = value as? String {
            let iso8601Formatter = ISO8601DateFormatter()
            if let date = iso8601Formatter.date(from: stringValue) {
                return date
            }

            // Try with fractional seconds
            iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso8601Formatter.date(from: stringValue) {
                return date
            }

            // Try common date formats
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")

            let formats = [
                "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
                "yyyy-MM-dd'T'HH:mm:ssZ",
                "yyyy-MM-dd HH:mm:ss",
            ]

            for format in formats {
                dateFormatter.dateFormat = format
                if let date = dateFormatter.date(from: stringValue) {
                    return date
                }
            }
        }

        // Try as Unix timestamp (seconds or milliseconds)
        if let timestamp = value as? Double {
            // If timestamp is very large, it's likely milliseconds
            if timestamp > 1_000_000_000_000 {
                return Date(timeIntervalSince1970: timestamp / 1000)
            }
            return Date(timeIntervalSince1970: timestamp)
        }

        // Try as Firestore timestamp dictionary ({"_seconds": ..., "_nanoseconds": ...})
        if let timestampDict = value as? [String: Any],
            let seconds = timestampDict["_seconds"] as? Double
        {
            return Date(timeIntervalSince1970: seconds)
        }

        return nil
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
            "budget_plan_id": snapshot.budgetPlanId,
            "expense_transaction_count": snapshot.expenseTransactionCount,
            "income_transaction_count": snapshot.incomeTransactionCount,
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

    // MARK: - User Registration

    func registerUser(email: String) async throws -> String {
        let url = URL(string: "\(baseURL)/users/register")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["email": email]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 201 || httpResponse.statusCode == 200
        else {
            throw BackendError.invalidResponse
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let userId = json["user_id"] as? String
        else {
            throw BackendError.invalidData
        }

        // Mark as connected after successful registration
        await MainActor.run {
            self.isConnected = true
        }

        return userId
    }

    // MARK: - Month-End Balance API

    func createMonthEndBalance(_ balance: MonthEndBalance) async throws -> String {
        guard isConnected else {
            throw BackendError.notConnected
        }

        let url = URL(string: "\(baseURL)/api/month-end-balances")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(balance)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 201
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

    // MARK: - Gmail Integration

    func startGmailAuth() async throws -> GmailAuthResponse {
        print("📧 [BackendService] Starting Gmail auth request...")
        print("📧 [BackendService] Base URL: \(baseURL)")

        let url = URL(string: "\(baseURL)/gmail/auth/start")!
        print("📧 [BackendService] Request URL: \(url.absoluteString)")

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ [BackendService] Invalid response type")
            throw BackendError.invalidResponse
        }

        print("📧 [BackendService] Response status code: \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 else {
            print("❌ [BackendService] Non-200 status code: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("❌ [BackendService] Response body: \(responseString)")
            }
            throw BackendError.invalidResponse
        }

        if let responseString = String(data: data, encoding: .utf8) {
            print("📧 [BackendService] Response body: \(responseString)")
        }

        let decoded = try JSONDecoder().decode(GmailAuthResponse.self, from: data)
        print("✅ [BackendService] Successfully decoded auth response")
        return decoded
    }

    func fetchTransactionAlerts() async throws -> [TransactionAlert] {
        let url = URL(string: "\(baseURL)/transaction-alerts")!
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200
        else {
            throw BackendError.invalidResponse
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // Try multiple ISO8601 formats
            let formatters: [ISO8601DateFormatter] = [
                // With fractional seconds and timezone
                {
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    return formatter
                }(),
                // Standard ISO8601 with timezone
                ISO8601DateFormatter(),
                // Without timezone (e.g., "2026-01-05T00:00:00")
                {
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [
                        .withFullDate, .withTime, .withColonSeparatorInTime,
                        .withDashSeparatorInDate,
                    ]
                    return formatter
                }(),
            ]

            for formatter in formatters {
                if let date = formatter.date(from: dateString) {
                    return date
                }
            }

            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Invalid date format: \(dateString)"
                )
            )
        }

        let result = try decoder.decode(TransactionAlertsResponse.self, from: data)
        return result.alerts
    }

    func updateTransactionAlert(alertId: String, updates: [String: Any]) async throws {
        let url = URL(string: "\(baseURL)/transaction-alerts/\(alertId)")!
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

    func deleteTransactionAlert(alertId: String) async throws {
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

    // MARK: - Gmail Auth Status

    func checkGmailAuthStatus() async throws -> GmailAuthStatusResponse {
        let url = URL(string: "\(baseURL)/gmail/auth/status")!
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200
        else {
            throw BackendError.invalidResponse
        }

        return try JSONDecoder().decode(GmailAuthStatusResponse.self, from: data)
    }
}

// MARK: - Response Models

struct GmailAuthResponse: Codable {
    let authUrl: String

    enum CodingKeys: String, CodingKey {
        case authUrl = "auth_url"
    }
}

struct GmailAuthStatusResponse: Codable {
    let authenticated: Bool
    let errorCode: String?

    enum CodingKeys: String, CodingKey {
        case authenticated
        case errorCode = "error_code"
    }
}

struct TransactionAlertsResponse: Codable {
    let alerts: [TransactionAlert]
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
