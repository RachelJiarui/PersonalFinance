import Foundation

class SimpleFinService: ObservableObject {
    static let shared = SimpleFinService()

    @Published var isConnected: Bool = false
    @Published var transactions: [Transaction] = []
    @Published var isLoading: Bool = false
    @Published var accounts: [SimpleFinAccount] = []

    private var accessURL: String?

    private init() {
        loadAccessURL()
        isConnected = accessURL != nil
    }

    func claimSetupToken(_ setupToken: String) async throws {
        guard let claimURLString = String(data: Data(base64Encoded: setupToken) ?? Data(), encoding: .utf8),
              let claimURL = URL(string: claimURLString) else {
            throw SimpleFinError.invalidSetupToken
        }

        var request = URLRequest(url: claimURL)
        request.httpMethod = "POST"

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw SimpleFinError.claimFailed
        }

        guard let accessURLString = String(data: data, encoding: .utf8) else {
            throw SimpleFinError.invalidResponse
        }

        try saveAccessURL(accessURLString)

        await MainActor.run {
            self.accessURL = accessURLString
            self.isConnected = true
        }
    }

    func fetchAccounts() async throws -> SimpleFinAccountSet {
        print("📡 [SimpleFin] Starting fetchAccounts...")

        guard let accessURLString = accessURL else {
            print("❌ [SimpleFin] No access URL found")
            throw SimpleFinError.noAccessURL
        }

        guard let components = URLComponents(string: accessURLString),
              let username = components.user,
              let password = components.password else {
            print("❌ [SimpleFin] Invalid access URL - missing credentials")
            throw SimpleFinError.invalidAccessURL
        }

        // Calculate start date (90 days ago to get recent transaction history)
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        let startTimestamp = Int(startDate.timeIntervalSince1970)

        // Build URL with start-date parameter
        guard var urlComponents = URLComponents(string: "\(accessURLString)/accounts") else {
            print("❌ [SimpleFin] Failed to construct URL components")
            throw SimpleFinError.invalidAccessURL
        }

        urlComponents.queryItems = [
            URLQueryItem(name: "start-date", value: "\(startTimestamp)")
        ]

        guard let url = urlComponents.url else {
            print("❌ [SimpleFin] Failed to construct URL with query parameters")
            throw SimpleFinError.invalidAccessURL
        }

        print("📡 [SimpleFin] Fetching from URL with start-date: \(startTimestamp) (\(startDate))")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let credentials = "\(username):\(password)"
        if let credentialData = credentials.data(using: .utf8) {
            let base64Credentials = credentialData.base64EncodedString()
            request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            print("❌ [SimpleFin] Request failed with status code: \(statusCode)")
            throw SimpleFinError.requestFailed
        }

        print("✅ [SimpleFin] Received response with \(data.count) bytes")

        // Print raw JSON for debugging
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📄 [SimpleFin] Raw JSON response:")
            print(jsonString)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let accountSet = try decoder.decode(SimpleFinAccountSet.self, from: data)
        print("✅ [SimpleFin] Decoded \(accountSet.accounts.count) accounts")

        return accountSet
    }

    func syncTransactions() async {
        print("\n🔄 [SimpleFin] Starting syncTransactions...")
        await MainActor.run { isLoading = true }

        do {
            let accountSet = try await fetchAccounts()

            print("📊 [SimpleFin] Processing accounts...")
            for account in accountSet.accounts {
                print("  💳 Account: \(account.name) (ID: \(account.id))")
                print("     Balance: $\(account.balanceInDollars)")
                print("     Transactions: \(account.transactions.count)")
            }

            let allTransactions: [Transaction] = accountSet.accounts.flatMap { account in
                account.transactions.map { transaction in
                    convertToTransaction(transaction, accountId: account.id)
                }
            }

            let allAccounts: [SimpleFinAccount] = accountSet.accounts

            print("✅ [SimpleFin] Total transactions converted: \(allTransactions.count)")
            print("   Sample transactions:")
            for (index, tx) in allTransactions.prefix(5).enumerated() {
                print("   \(index + 1). \(tx.merchantName ?? "Unknown") - $\(tx.amount) on \(tx.date)")
            }

            await MainActor.run {
                self.transactions = allTransactions.sorted { $0.date > $1.date }
                self.accounts = allAccounts
                self.isLoading = false
                print("✅ [SimpleFin] Sync complete. Stored \(self.transactions.count) transactions\n")
            }
        } catch {
            print("❌ [SimpleFin] Failed to sync transactions: \(error)")
            await MainActor.run { isLoading = false }
        }
    }

    private func convertToTransaction(_ sfTransaction: SimpleFinTransaction, accountId: String) -> Transaction {
        let categories = categorizeTransaction(sfTransaction)

        return Transaction(
            id: sfTransaction.id,
            accountId: accountId,
            amount: abs(Double(sfTransaction.amount) ?? 0.0),
            date: Date(timeIntervalSince1970: TimeInterval(sfTransaction.posted)),
            merchantName: sfTransaction.description,
            category: categories,
            pending: sfTransaction.pending ?? false
        )
    }

    private func categorizeTransaction(_ transaction: SimpleFinTransaction) -> [String] {
        let description = transaction.description.lowercased()

        if description.contains("restaurant") || description.contains("cafe") ||
           description.contains("coffee") || description.contains("food") ||
           description.contains("mcdonald") || description.contains("starbucks") {
            return ["Food and Drink", "Restaurants"]
        } else if description.contains("amazon") || description.contains("target") ||
                  description.contains("walmart") || description.contains("store") {
            return ["Shops", "General Merchandise"]
        } else if description.contains("gas") || description.contains("uber") ||
                  description.contains("lyft") || description.contains("transit") {
            return ["Transportation", "Gas"]
        } else if description.contains("netflix") || description.contains("spotify") ||
                  description.contains("movie") || description.contains("hulu") {
            return ["Recreation", "Entertainment"]
        } else if description.contains("electric") || description.contains("water") ||
                  description.contains("internet") || description.contains("phone") {
            return ["Service", "Utilities"]
        } else if description.contains("doctor") || description.contains("pharmacy") ||
                  description.contains("hospital") || description.contains("medical") {
            return ["Healthcare", "Medical"]
        } else if description.contains("hotel") || description.contains("airbnb") ||
                  description.contains("flight") || description.contains("airline") {
            return ["Travel"]
        } else if description.contains("paycheck") || description.contains("deposit") ||
                  description.contains("salary") || description.contains("payment received") {
            return ["Income", "Paycheck"]
        }

        return ["Other"]
    }

    private func saveAccessURL(_ url: String) throws {
        guard let data = url.data(using: .utf8) else {
            throw SimpleFinError.invalidResponse
        }
        try KeychainService.shared.save(key: "simplefin_access_url", data: data)
    }

    private func loadAccessURL() {
        do {
            let data = try KeychainService.shared.load(key: "simplefin_access_url")
            accessURL = String(data: data, encoding: .utf8)
        } catch {
            accessURL = nil
        }
    }

    func disconnect() {
        do {
            try KeychainService.shared.delete(key: "simplefin_access_url")
            isConnected = false
            transactions = []
            accounts = []
            accessURL = nil
        } catch {
            print("Failed to disconnect: \(error)")
        }
    }
}

enum SimpleFinError: Error {
    case invalidSetupToken
    case claimFailed
    case noAccessURL
    case invalidAccessURL
    case requestFailed
    case invalidResponse
}

struct SimpleFinAccountSet: Codable {
    let accounts: [SimpleFinAccount]
    let errors: [String]?
}

struct SimpleFinAccount: Codable, Identifiable {
    let id: String
    let name: String
    let currency: String
    let balance: String
    let availableBalance: String?
    let balanceDate: Int?
    let transactions: [SimpleFinTransaction]

    var balanceInDollars: Double {
        Double(balance) ?? 0.0
    }

    var availableBalanceInDollars: Double? {
        guard let available = availableBalance else { return nil }
        return Double(available)
    }
}

struct SimpleFinTransaction: Codable, Identifiable {
    let id: String
    let posted: Int
    let amount: String
    let description: String
    let pending: Bool?
    let memo: String?

    var amountInDollars: Double {
        Double(amount) ?? 0.0
    }
}
