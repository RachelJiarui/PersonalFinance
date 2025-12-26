import Foundation
import Combine
import AuthenticationServices
import UIKit

/// Handles Gmail API integration for monitoring Discover transaction alert emails
/// Uses OAuth 2.0 for authentication and polls for new transaction alerts
class EmailService: NSObject, ObservableObject {
    static let shared = EmailService()

    @Published var isAuthenticated: Bool = false
    @Published var isPolling: Bool = false

    private var accessToken: String?
    private var refreshToken: String?
    private var tokenExpirationDate: Date?

    // Gmail API configuration
    private let clientId = "575183170824-u52q55tqf9epn33rp7u2ujej5q33skvd.apps.googleusercontent.com"
    private let clientSecret = "" // Not needed for iOS
    private let redirectUri = "com.googleusercontent.apps.575183170824-u52q55tqf9epn33rp7u2ujej5q33skvd:/oauth2redirect"
    private let scopes = "https://www.googleapis.com/auth/gmail.readonly"

    // Email filtering criteria
    private let discoverEmailAddress = "discover@services.discover.com"
    private let transactionAlertSubject = "Transaction Alert"

    private override init() {
        super.init()
        loadTokensFromKeychain()
    }

    // MARK: - Authentication

    /// Start OAuth 2.0 authentication flow
    /// Opens browser for user to grant Gmail access
    func authenticate() async throws {
        // Build OAuth URL
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scopes),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]

        guard let authURL = components.url else {
            throw EmailServiceError.invalidAuthURL
        }

        print("📧 [EmailService] Opening OAuth URL: \(authURL)")

        // Use ASWebAuthenticationSession for OAuth flow
        let callbackURL = try await withCheckedThrowingContinuation { @Sendable (continuation: CheckedContinuation<URL, Error>) in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "com.googleusercontent.apps.575183170824-u52q55tqf9epn33rp7u2ujej5q33skvd"
            ) { @Sendable callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let callbackURL = callbackURL else {
                    continuation.resume(throwing: EmailServiceError.invalidResponse)
                    return
                }

                continuation.resume(returning: callbackURL)
            }

            DispatchQueue.main.async {
                session.presentationContextProvider = self
                session.prefersEphemeralWebBrowserSession = false
                session.start()
            }
        }

        // Extract authorization code from callback URL
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw EmailServiceError.invalidResponse
        }

        print("✅ [EmailService] Received authorization code")

        // Exchange code for tokens
        try await exchangeCodeForTokens(code: code)
    }

    /// Exchange authorization code for access and refresh tokens
    private func exchangeCodeForTokens(code: String) async throws {
        let tokenURL = URL(string: "https://oauth2.googleapis.com/token")!

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let params = [
            "code": code,
            "client_id": clientId,
            "client_secret": clientSecret,
            "redirect_uri": redirectUri,
            "grant_type": "authorization_code"
        ]

        let bodyString = params.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw EmailServiceError.tokenExchangeFailed
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)

        // Store tokens
        self.accessToken = tokenResponse.accessToken
        self.refreshToken = tokenResponse.refreshToken

        // Calculate expiration (typically 1 hour from now)
        self.tokenExpirationDate = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))

        // Save to keychain
        try saveTokensToKeychain()

        await MainActor.run {
            self.isAuthenticated = true
        }

        print("✅ [EmailService] Successfully authenticated with Gmail")
    }

    /// Refresh access token using refresh token
    private func refreshAccessToken() async throws {
        guard let refreshToken = refreshToken else {
            throw EmailServiceError.noRefreshToken
        }

        let tokenURL = URL(string: "https://oauth2.googleapis.com/token")!

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let params = [
            "refresh_token": refreshToken,
            "client_id": clientId,
            "client_secret": clientSecret,
            "grant_type": "refresh_token"
        ]

        let bodyString = params.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw EmailServiceError.tokenRefreshFailed
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)

        self.accessToken = tokenResponse.accessToken
        self.tokenExpirationDate = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))

        try saveTokensToKeychain()

        print("✅ [EmailService] Successfully refreshed access token")
    }

    /// Check if token is expired and refresh if needed
    private func ensureValidToken() async throws {
        guard let expirationDate = tokenExpirationDate else {
            throw EmailServiceError.noAccessToken
        }

        // Refresh if token expires in less than 5 minutes
        if Date().addingTimeInterval(300) > expirationDate {
            try await refreshAccessToken()
        }
    }

    // MARK: - Email Polling

    /// Poll Gmail for new Discover transaction alert emails
    /// Returns array of new TransactionAlert objects
    func pollForNewAlerts() async throws -> [TransactionAlert] {
        print("📧 [EmailService] Polling for new transaction alerts...")

        try await ensureValidToken()

        guard let accessToken = accessToken else {
            throw EmailServiceError.noAccessToken
        }

        // Build Gmail API search query
        // Search for: from:discover@services.discover.com subject:"Transaction Alert"
        let query = "from:\(discoverEmailAddress) subject:\"\(transactionAlertSubject)\""
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        let listURL = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages?q=\(encodedQuery)&maxResults=10")!

        var request = URLRequest(url: listURL)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            print("❌ [EmailService] Failed to list messages")
            throw EmailServiceError.apiRequestFailed
        }

        let messageList = try JSONDecoder().decode(MessageListResponse.self, from: data)

        guard let messages = messageList.messages, !messages.isEmpty else {
            print("📧 [EmailService] No new transaction alerts found")
            return []
        }

        print("📧 [EmailService] Found \(messages.count) potential alerts, fetching details...")

        // Fetch full message content for each email
        var alerts: [TransactionAlert] = []

        for message in messages {
            do {
                if let alert = try await fetchAndParseEmail(messageId: message.id, accessToken: accessToken) {
                    alerts.append(alert)
                }
            } catch {
                print("⚠️ [EmailService] Failed to parse email \(message.id): \(error)")
                continue
            }
        }

        print("✅ [EmailService] Successfully parsed \(alerts.count) transaction alerts")
        return alerts
    }

    /// Fetch full email content and parse into TransactionAlert
    private func fetchAndParseEmail(messageId: String, accessToken: String) async throws -> TransactionAlert? {
        let messageURL = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/\(messageId)")!

        var request = URLRequest(url: messageURL)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        let message = try JSONDecoder().decode(GmailMessage.self, from: data)

        // Extract email body (handle both plain text and HTML)
        guard let body = extractEmailBody(from: message) else {
            print("⚠️ [EmailService] Could not extract body from message \(messageId)")
            return nil
        }

        // Parse the email content
        let timestamp = Double(message.internalDate) ?? 0
        return parseDiscoverEmail(emailId: messageId, content: body, receivedAt: Date(timeIntervalSince1970: timestamp / 1000))
    }

    /// Extract email body from Gmail message (handles multipart MIME)
    private func extractEmailBody(from message: GmailMessage) -> String? {
        // Try to get HTML body first, fallback to plain text
        if let htmlBody = extractPart(from: message.payload, mimeType: "text/html") {
            return htmlBody
        }

        if let plainBody = extractPart(from: message.payload, mimeType: "text/plain") {
            return plainBody
        }

        return nil
    }

    /// Recursively extract message part by MIME type
    private func extractPart(from part: MessagePart, mimeType: String) -> String? {
        // Check if this part matches
        if part.mimeType == mimeType, let bodyData = part.body.data {
            // Decode base64url
            let base64 = bodyData
                .replacingOccurrences(of: "-", with: "+")
                .replacingOccurrences(of: "_", with: "/")

            if let data = Data(base64Encoded: base64),
               let text = String(data: data, encoding: .utf8) {
                return text
            }
        }

        // Recursively search in parts
        if let parts = part.parts {
            for subpart in parts {
                if let result = extractPart(from: subpart, mimeType: mimeType) {
                    return result
                }
            }
        }

        return nil
    }

    // MARK: - Email Parsing

    /// Parse Discover transaction alert email into TransactionAlert object
    /// Expected format:
    ///   Merchant: SOME STORE NAME
    ///   Date: December 25, 2025
    ///   Amount: $9.99
    func parseDiscoverEmail(emailId: String, content: String, receivedAt: Date) -> TransactionAlert? {
        print("📧 [EmailService] Parsing email content...")

        // Extract merchant
        guard let merchant = extractField(from: content, pattern: "Merchant:\\s*([^\\n<]+)") else {
            print("⚠️ [EmailService] Could not extract merchant")
            return nil
        }

        // Extract amount
        guard let amountString = extractField(from: content, pattern: "Amount:\\s*\\$([0-9,]+\\.?[0-9]*)"),
              let amount = parseAmount(amountString) else {
            print("⚠️ [EmailService] Could not extract amount")
            return nil
        }

        // Extract date
        guard let dateString = extractField(from: content, pattern: "Date:\\s*([^\\n<]+)"),
              let date = parseDate(dateString) else {
            print("⚠️ [EmailService] Could not extract date")
            return nil
        }

        print("✅ [EmailService] Parsed: \(merchant) - $\(amount) on \(date)")

        return TransactionAlert(
            emailId: emailId,
            merchant: merchant.trimmingCharacters(in: .whitespaces),
            date: date,
            amount: amount,
            rawEmailBody: content,
            receivedAt: receivedAt
        )
    }

    /// Extract field using regex pattern
    private func extractField(from content: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let nsContent = content as NSString
        let matches = regex.matches(in: content, range: NSRange(location: 0, length: nsContent.length))

        guard let match = matches.first, match.numberOfRanges > 1 else {
            return nil
        }

        let range = match.range(at: 1)
        return nsContent.substring(with: range)
    }

    /// Parse amount string (handles commas and dollar signs)
    private func parseAmount(_ amountString: String) -> Double? {
        let cleaned = amountString.replacingOccurrences(of: ",", with: "")
        return Double(cleaned)
    }

    /// Parse date string (handles various formats)
    private func parseDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")

        // Try common formats
        let formats = [
            "MMMM d, yyyy",      // December 25, 2025
            "MMM d, yyyy",       // Dec 25, 2025
            "MM/dd/yyyy",        // 12/25/2025
            "M/d/yyyy"           // 12/5/2025
        ]

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: dateString.trimmingCharacters(in: .whitespaces)) {
                return date
            }
        }

        return nil
    }

    // MARK: - Token Storage

    private func saveTokensToKeychain() throws {
        if let accessToken = accessToken,
           let data = accessToken.data(using: .utf8) {
            try KeychainService.shared.save(key: "gmail_access_token", data: data)
        }

        if let refreshToken = refreshToken,
           let data = refreshToken.data(using: .utf8) {
            try KeychainService.shared.save(key: "gmail_refresh_token", data: data)
        }

        if let expirationDate = tokenExpirationDate {
            let timestamp = String(expirationDate.timeIntervalSince1970)
            if let data = timestamp.data(using: .utf8) {
                try KeychainService.shared.save(key: "gmail_token_expiration", data: data)
            }
        }
    }

    private func loadTokensFromKeychain() {
        do {
            if let data = try? KeychainService.shared.load(key: "gmail_access_token") {
                self.accessToken = String(data: data, encoding: .utf8)
            }

            if let data = try? KeychainService.shared.load(key: "gmail_refresh_token") {
                self.refreshToken = String(data: data, encoding: .utf8)
            }

            if let data = try? KeychainService.shared.load(key: "gmail_token_expiration"),
               let timestampString = String(data: data, encoding: .utf8),
               let timestamp = Double(timestampString) {
                self.tokenExpirationDate = Date(timeIntervalSince1970: timestamp)
            }

            // Check if we have valid tokens
            if accessToken != nil, refreshToken != nil {
                self.isAuthenticated = true
            }
        }
    }

    func disconnect() {
        try? KeychainService.shared.delete(key: "gmail_access_token")
        try? KeychainService.shared.delete(key: "gmail_refresh_token")
        try? KeychainService.shared.delete(key: "gmail_token_expiration")

        self.accessToken = nil
        self.refreshToken = nil
        self.tokenExpirationDate = nil
        self.isAuthenticated = false

        print("✅ [EmailService] Disconnected from Gmail")
    }
}

// MARK: - Error Types

enum EmailServiceError: Error {
    case invalidAuthURL
    case tokenExchangeFailed
    case tokenRefreshFailed
    case noAccessToken
    case noRefreshToken
    case apiRequestFailed
    case parsingFailed
    case invalidResponse
    case notImplemented
}

// MARK: - API Response Models

struct TokenResponse: Codable {
    let accessToken: String
    let expiresIn: Int
    let refreshToken: String?
    let scope: String
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
        case tokenType = "token_type"
    }
}

struct MessageListResponse: Codable {
    let messages: [MessageReference]?
    let resultSizeEstimate: Int?
}

struct MessageReference: Codable {
    let id: String
    let threadId: String
}

struct GmailMessage: Codable {
    let id: String
    let threadId: String
    let internalDate: String
    let payload: MessagePart
}

struct MessagePart: Codable {
    let mimeType: String
    let body: MessageBody
    let parts: [MessagePart]?
}

struct MessageBody: Codable {
    let size: Int
    let data: String?
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension EmailService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}
