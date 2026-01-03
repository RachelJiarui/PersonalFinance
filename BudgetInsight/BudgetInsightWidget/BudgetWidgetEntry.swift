import SwiftUI
import WidgetKit

/// Widget entry containing snapshot of budget data at a point in time
struct BudgetWidgetEntry: TimelineEntry {
    let date: Date
    let totalSpent: Double
    let totalBudget: Double
    let spendingRatio: Double
    let color: WidgetColor
    let starredCategories: [CategoryWidgetData]
}

/// Simplified category data for widget display
struct CategoryWidgetData: Identifiable {
    let id: String
    let name: String
    let icon: String
    let spent: Double
    let budget: Double
    let spendingRatio: Double
    let color: WidgetColor
}

/// Timeline provider for budget widgets
struct BudgetWidgetProvider: TimelineProvider {

    func placeholder(in context: Context) -> BudgetWidgetEntry {
        BudgetWidgetEntry(
            date: Date(),
            totalSpent: 1234.56,
            totalBudget: 3000.00,
            spendingRatio: 0.41,
            color: .green,
            starredCategories: [
                CategoryWidgetData(
                    id: "1",
                    name: "Groceries",
                    icon: "cart.fill",
                    spent: 345.67,
                    budget: 800.00,
                    spendingRatio: 0.43,
                    color: .green
                ),
                CategoryWidgetData(
                    id: "2",
                    name: "Transport",
                    icon: "car.fill",
                    spent: 123.45,
                    budget: 400.00,
                    spendingRatio: 0.31,
                    color: .green
                ),
            ]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (BudgetWidgetEntry) -> Void) {
        let entry = createEntry()
        completion(entry)
    }

    func getTimeline(
        in context: Context, completion: @escaping (Timeline<BudgetWidgetEntry>) -> Void
    ) {
        let entry = createEntry()

        // Refresh every 15 minutes
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))

        completion(timeline)
    }

    /// Create widget entry from current budget data
    private func createEntry() -> BudgetWidgetEntry {
        let categorySpending = WidgetDataProvider.calculateCategorySpending()
        let totalSpent = WidgetDataProvider.calculateTotalSpending()
        let totalBudget = WidgetDataProvider.calculateTotalBudget()
        let spendingRatio = WidgetDataProvider.calculateSpendingRatio(
            spent: totalSpent,
            budget: totalBudget
        )
        let color = WidgetDataProvider.calculateRingColor(spendingRatio: spendingRatio)

        // Get starred categories
        let starredCategories = WidgetDataProvider.getStarredCategories(limit: 4)
        let plan = WidgetDataProvider.loadBudgetPlan()

        let categoryData = starredCategories.compactMap { category -> CategoryWidgetData? in
            guard let plan = plan else { return nil }

            let spent = categorySpending[category.id] ?? 0
            let budget = category.dollarAmount(monthlyTakeHome: plan.monthlyTakeHome)
            let ratio = category.spendingRatio(
                currentSpent: spent,
                monthlyTakeHome: plan.monthlyTakeHome
            )
            let categoryColor = WidgetDataProvider.calculateRingColor(spendingRatio: ratio)

            return CategoryWidgetData(
                id: category.id,
                name: category.name,
                icon: category.icon,
                spent: spent,
                budget: budget,
                spendingRatio: ratio,
                color: categoryColor
            )
        }

        return BudgetWidgetEntry(
            date: Date(),
            totalSpent: totalSpent,
            totalBudget: totalBudget,
            spendingRatio: spendingRatio,
            color: color,
            starredCategories: categoryData
        )
    }
}
