import SwiftUI
import WidgetKit

/// Main widget configuration
struct BudgetInsightWidget: Widget {
    let kind: String = "BudgetInsightWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BudgetWidgetProvider()) { entry in
            BudgetInsightWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Budget Tracker")
        .description("Track your monthly budget spending at a glance.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
        ])
    }
}

/// Main widget entry view that switches based on widget size
struct BudgetInsightWidgetEntryView: View {
    @Environment(\.widgetFamily) var widgetFamily
    let entry: BudgetWidgetEntry

    var body: some View {
        switch widgetFamily {
        case .systemSmall:
            SmallBudgetWidget(entry: entry)
        case .systemMedium:
            MediumBudgetWidget(entry: entry)
        case .accessoryCircular, .accessoryRectangular, .accessoryInline:
            if #available(iOS 16.0, *) {
                LockScreenBudgetWidget(entry: entry)
            } else {
                SmallBudgetWidget(entry: entry)
            }
        default:
            SmallBudgetWidget(entry: entry)
        }
    }
}

/// Widget preview
struct BudgetInsightWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            BudgetInsightWidgetEntryView(
                entry: BudgetWidgetEntry(
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
            )
            .previewContext(WidgetPreviewContext(family: .systemSmall))

            BudgetInsightWidgetEntryView(
                entry: BudgetWidgetEntry(
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
                        CategoryWidgetData(
                            id: "3",
                            name: "Entertainment",
                            icon: "tv.fill",
                            spent: 89.12,
                            budget: 300.00,
                            spendingRatio: 0.30,
                            color: .green
                        ),
                    ]
                )
            )
            .previewContext(WidgetPreviewContext(family: .systemMedium))
        }
    }
}
