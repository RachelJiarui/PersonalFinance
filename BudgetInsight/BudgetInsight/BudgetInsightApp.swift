import SwiftUI

@main
struct BudgetInsightApp: App {
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
        }
    }

    private func handleIncomingURL(_ url: URL) {
        guard url.scheme == "budgetinsight" else { return }

        switch url.host {
        case "gmail-connected":
            print("✅ Gmail successfully connected!")
        // Could show a success toast here

        case "gmail-error":
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                let message = components.queryItems?.first(where: { $0.name == "message" })?.value
            {
                print("❌ Gmail connection error: \(message)")
                // Could show an error alert here
            }

        default:
            print("⚠️ Unknown URL: \(url)")
        }
    }
}
