import Foundation

/// Data provider for widgets - loads and calculates budget data from shared UserDefaults
struct WidgetDataProvider {

    /// Load budget categories from shared container
    static func loadBudgetCategories() -> [BudgetCategory] {
        guard let data = SharedUserDefaults.shared.data(forKey: "budget_categories"),
            let categories = try? JSONDecoder().decode([BudgetCategory].self, from: data)
        else {
            print("⚠️ [Widget] No budget categories found in shared container")
            return []
        }
        return categories
    }

    /// Load budget plan from shared container
    static func loadBudgetPlan() -> BudgetPlan? {
        guard let data = SharedUserDefaults.shared.data(forKey: "budget_plan"),
            let plan = try? JSONDecoder().decode(BudgetPlan.self, from: data)
        else {
            print("⚠️ [Widget] No budget plan found in shared container")
            return nil
        }
        return plan
    }

    /// Load transactions from shared container
    static func loadTransactions() -> [Transaction] {
        guard let data = SharedUserDefaults.shared.data(forKey: "stored_transactions"),
            let transactions = try? JSONDecoder().decode([Transaction].self, from: data)
        else {
            print("⚠️ [Widget] No transactions found in shared container")
            return []
        }
        return transactions
    }

    /// Load allocations from shared container
    static func loadAllocations() -> [TransactionAllocation] {
        guard let data = SharedUserDefaults.shared.data(forKey: "transaction_allocations"),
            let allocations = try? JSONDecoder().decode([TransactionAllocation].self, from: data)
        else {
            print("⚠️ [Widget] No allocations found in shared container")
            return []
        }
        return allocations
    }

    /// Get starred and active categories (up to 4)
    static func getStarredCategories(limit: Int = 4) -> [BudgetCategory] {
        let categories = loadBudgetCategories()
        return Array(categories.filter { $0.isStarred && $0.isActive }.prefix(limit))
    }

    /// Calculate category spending for current month (replicates BudgetService logic)
    static func calculateCategorySpending() -> [String: Double] {
        let transactions = loadTransactions()
        let allocations = loadAllocations()

        let calendar = Calendar.current
        let now = Date()
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)

        var categorySpending: [String: Double] = [:]

        // Filter to current month transactions
        let currentMonthTransactions = transactions.filter { transaction in
            let month = calendar.component(.month, from: transaction.date)
            let year = calendar.component(.year, from: transaction.date)
            return month == currentMonth && year == currentYear
        }

        // Calculate spending per category
        for transaction in currentMonthTransactions {
            let categoryAllocations = allocations.filter {
                $0.transactionId == transaction.id && $0.destinationType == .category
            }

            for allocation in categoryAllocations {
                if transaction.isExpense {
                    categorySpending[allocation.destinationId, default: 0] += allocation.amount
                } else {
                    // Income reduces spending (reimbursement)
                    categorySpending[allocation.destinationId, default: 0] -= allocation.amount
                }
            }
        }

        return categorySpending
    }

    /// Calculate total spending across all categories this month
    static func calculateTotalSpending() -> Double {
        let categorySpending = calculateCategorySpending()
        return categorySpending.values.reduce(0, +)
    }

    /// Calculate total budget across all active categories
    static func calculateTotalBudget() -> Double {
        guard let plan = loadBudgetPlan() else { return 0 }
        let categories = loadBudgetCategories().filter { $0.isActive }
        return categories.reduce(0) { total, category in
            total + category.dollarAmount(monthlyTakeHome: plan.monthlyTakeHome)
        }
    }

    /// Calculate spending ratio (0.0 to 1.0+)
    static func calculateSpendingRatio(spent: Double, budget: Double) -> Double {
        guard budget > 0 else { return 0 }
        return spent / budget
    }

    /// Calculate ring color based on spending vs time progress (matches DashboardCategoryCard logic)
    static func calculateRingColor(spendingRatio: Double) -> WidgetColor {
        let timeRatio = calculateTimeRatio()
        // Round to match displayed percentage (e.g., 0.998 -> 1.0 for "100%")
        let roundedRatio = round(spendingRatio * 100) / 100

        if roundedRatio >= 1.0 {
            return .red  // Over budget
        } else if roundedRatio <= timeRatio {
            return .green  // On track
        } else if roundedRatio <= 1.15 * timeRatio {
            return .yellow  // Slightly ahead
        } else {
            return .red  // Way ahead of schedule
        }
    }

    /// Calculate how far through the month we are (0.0 to 1.0)
    static func calculateTimeRatio() -> Double {
        let calendar = Calendar.current
        let now = Date()
        let dayOfMonth = Double(calendar.component(.day, from: now))
        let daysInMonth = Double(calendar.range(of: .day, in: .month, for: now)?.count ?? 30)
        return dayOfMonth / daysInMonth
    }
}

/// Widget color enum (since we can't import SwiftUI Color in widget data provider)
enum WidgetColor {
    case green
    case yellow
    case red
}
