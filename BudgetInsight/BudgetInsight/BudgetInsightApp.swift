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
        }
    }
}
