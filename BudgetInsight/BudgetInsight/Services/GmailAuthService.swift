import Foundation
import UserNotifications

class GmailAuthService: ObservableObject {
    static let shared = GmailAuthService()

    @Published var isAuthFailed: Bool = false
    @Published var pendingReconnect: Bool = false

    private let lastNotificationKey = "gmail_auth_last_notification"

    private init() {}

    func checkAndNotifyIfNeeded() async {
        // First check if widget already detected auth failure
        if SharedUserDefaults.shared.bool(forKey: "gmail_auth_failed") {
            print("Widget detected Gmail auth failure")
            await MainActor.run { self.isAuthFailed = true }
            await scheduleAuthFailureNotification()
            return
        }

        // Otherwise check directly with backend
        do {
            let status = try await BackendService.shared.checkGmailAuthStatus()
            if !status.authenticated {
                print("Gmail credentials invalid: \(status.errorCode ?? "unknown")")
                await MainActor.run { self.isAuthFailed = true }
                await scheduleAuthFailureNotification()
            } else {
                SharedUserDefaults.shared.set(false, forKey: "gmail_auth_failed")
                await MainActor.run { self.isAuthFailed = false }
            }
        } catch {
            print("Failed to check Gmail auth status: \(error)")
        }
    }

    func markReconnected() {
        isAuthFailed = false
        SharedUserDefaults.shared.set(false, forKey: "gmail_auth_failed")
        clearBadge()
        resetNotificationTimer()
    }

    /// Schedule a local notification for auth failure
    private func scheduleAuthFailureNotification() async {
        // Debounce: only notify once per 24 hours
        if wasNotificationSentRecently() {
            print("Auth failure notification already sent recently, skipping")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Gmail Connection Lost"
        content.body =
            "Tap to reconnect your Gmail account to continue receiving transaction alerts."
        content.sound = .default
        content.badge = 1
        content.userInfo = ["type": "gmail_auth_failure"]

        let request = UNNotificationRequest(
            identifier: "gmail_auth_failure",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            UserDefaults.standard.set(Date(), forKey: lastNotificationKey)
            print("Scheduled Gmail auth failure notification")
        } catch {
            print("Failed to schedule notification: \(error)")
        }
    }

    /// Check if notification was sent in the last 24 hours
    private func wasNotificationSentRecently() -> Bool {
        guard let lastSent = UserDefaults.standard.object(forKey: lastNotificationKey) as? Date
        else {
            return false
        }
        let hoursSinceLastNotification = Date().timeIntervalSince(lastSent) / 3600
        return hoursSinceLastNotification < 24
    }

    /// Clear the notification badge
    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0) { error in
            if let error = error {
                print("Failed to clear badge: \(error)")
            }
        }
    }

    /// Reset the notification timer (call after successful re-authentication)
    func resetNotificationTimer() {
        UserDefaults.standard.removeObject(forKey: lastNotificationKey)
    }
}
