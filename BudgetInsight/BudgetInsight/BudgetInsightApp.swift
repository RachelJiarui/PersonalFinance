import SwiftUI

@main
struct BudgetInsightApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) var scenePhase

    init() {
        // Migrate data to shared container on first launch
        SharedUserDefaults.migrateToSharedContainer()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .active {
                        handleAppBecameActive()
                    }
                }
        }
    }

    private func handleIncomingURL(_ url: URL) {
        guard url.scheme == "budgetinsight" else { return }

        switch url.host {
        case "gmail-connected":
            print("Gmail successfully connected!")
            GmailAuthService.shared.markReconnected()

        case "gmail-error":
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                let message = components.queryItems?.first(where: { $0.name == "message" })?.value
            {
                print("Gmail connection error: \(message)")
            }

        default:
            print("Unknown URL: \(url)")
        }
    }

    private func handleAppBecameActive() {
        // Check Gmail auth status when app becomes active
        Task {
            await GmailAuthService.shared.checkAndNotifyIfNeeded()
        }

        // Clear badge when app is opened
        GmailAuthService.shared.clearBadge()
    }
}
