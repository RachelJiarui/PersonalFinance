import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {

        // Request notification permissions
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ Notification permission granted")
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            } else if let error = error {
                print("❌ Notification permission error: \(error)")
            }
        }

        return true
    }

    // MARK: - Push Notification Registration

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("✅ Device Token: \(token)")

        // Save token and upload to backend
        Task {
            do {
                try await BackendService.shared.updateDeviceToken(token)
                print("✅ Device token uploaded to backend")
            } catch {
                print("⚠️ Failed to upload device token: \(error)")
            }
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Failed to register for remote notifications: \(error)")
    }

    // MARK: - Notification Handling

    // Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("📱 Received notification while in foreground")

        let userInfo = notification.request.content.userInfo
        handleNotification(userInfo: userInfo)

        // Show banner and play sound even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    // Handle notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        print("📱 User tapped notification")

        let userInfo = response.notification.request.content.userInfo
        handleNotification(userInfo: userInfo)

        completionHandler()
    }

    // MARK: - Notification Processing

    private func handleNotification(userInfo: [AnyHashable: Any]) {
        print("📱 Processing notification: \(userInfo)")

        // Check notification type
        if let type = userInfo["type"] as? String {
            switch type {
            case "transaction_alert":
                // New transaction alert received - sync alerts from backend
                Task {
                    await syncTransactionAlerts()
                }

            case "new_transaction":
                // Legacy transaction notification
                Task {
                    await syncTransactions()
                }

            default:
                print("⚠️ Unknown notification type: \(type)")
            }
        } else {
            // Fallback: try to sync both
            Task {
                await syncTransactionAlerts()
                await syncTransactions()
            }
        }
    }

    // MARK: - Background Sync Methods

    private func syncTransactionAlerts() async {
        do {
            // Fetch unlinked alerts from backend
            let alerts = try await BackendService.shared.fetchTransactionAlerts(status: "unlinked")

            await MainActor.run {
                // Store alerts in UserDefaults for instant access
                if let encoded = try? JSONEncoder().encode(alerts) {
                    UserDefaults.standard.set(encoded, forKey: "cached_transaction_alerts")
                    UserDefaults.standard.set(Date(), forKey: "cached_alerts_timestamp")
                }

                // Post notification to update UI
                NotificationCenter.default.post(name: NSNotification.Name("TransactionAlertsUpdated"), object: alerts)
            }

            print("✅ Synced \(alerts.count) transaction alerts from push notification")
        } catch {
            print("❌ Failed to sync transaction alerts: \(error)")
        }
    }

    private func syncTransactions() async {
        do {
            let transactions = try await BackendService.shared.syncTransactions()

            // Update local storage
            await MainActor.run {
                let storageService = TransactionStorageService.shared
                for transaction in transactions {
                    // Only add if not already exists
                    if !storageService.transactions.contains(where: { $0.id == transaction.id }) {
                        storageService.saveTransaction(transaction)
                    }
                }

                // Update budgets
                BudgetService.shared.updateBudgets(with: storageService.transactions)
                BudgetService.shared.updateCategorySpending(with: storageService.transactions)

                // Update snapshots
                if let monthlyTakeHome = BudgetService.shared.userIncome?.monthlyTakeHome {
                    SnapshotService.shared.updateSnapshotsIfNeeded(
                        monthlyTakeHome: monthlyTakeHome,
                        transactions: storageService.transactions
                    )
                }
            }

            print("✅ Synced transactions from push notification")
        } catch {
            print("❌ Failed to sync transactions: \(error)")
        }
    }
}
