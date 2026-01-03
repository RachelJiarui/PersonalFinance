import Foundation

/// Shared UserDefaults container for data sharing between main app and widget
enum SharedUserDefaults {
    static let appGroupId = "group.com.budgetinsight.shared"

    static var shared: UserDefaults {
        guard let defaults = UserDefaults(suiteName: appGroupId) else {
            fatalError("Unable to create UserDefaults with suite name: \(appGroupId)")
        }
        return defaults
    }

    /// Migrate data from standard UserDefaults to shared container (one-time migration)
    static func migrateToSharedContainer() {
        let standard = UserDefaults.standard
        let shared = Self.shared

        // Keys to migrate
        let keys = [
            "budget_plan",
            "budget_categories",
            "transactions",
            "transaction_allocations",
            "funds",
            "debts",
            "period_snapshots",
            "has_balanced_months",
        ]

        for key in keys {
            // Only migrate if data exists in standard but not in shared
            if let data = standard.data(forKey: key),
                shared.data(forKey: key) == nil
            {
                shared.set(data, forKey: key)
                print("Migrated \(key) to shared container")
            }
        }

        shared.synchronize()
    }
}
