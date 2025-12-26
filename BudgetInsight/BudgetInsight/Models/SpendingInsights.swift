import Foundation

struct SpendingInsight: Identifiable {
    let id = UUID()
    let type: InsightType
    let title: String
    let message: String
    let impact: Impact
    let category: TransactionCategory?

    enum InsightType {
        case warning
        case recommendation
        case achievement
    }

    enum Impact {
        case high
        case medium
        case low
    }
}

class InsightEngine {
    static func generateInsights(
        budgets: [Budget],
        transactions: [Transaction],
        summary: SpendingSummary
    ) -> [SpendingInsight] {
        var insights: [SpendingInsight] = []

        for budget in budgets {
            if budget.isOverMonthlyBudget {
                insights.append(SpendingInsight(
                    type: .warning,
                    title: "Budget Exceeded",
                    message: "You've exceeded your \(budget.category.rawValue) budget by $\(String(format: "%.2f", abs(budget.monthlyRemaining)))",
                    impact: .high,
                    category: budget.category
                ))
            } else if budget.status == .warning {
                insights.append(SpendingInsight(
                    type: .recommendation,
                    title: "Approaching Limit",
                    message: "You've used \(String(format: "%.0f", budget.monthlyPercentage))% of your \(budget.category.rawValue) budget",
                    impact: .medium,
                    category: budget.category
                ))
            }
        }

        if summary.savingsRate > 20 {
            insights.append(SpendingInsight(
                type: .achievement,
                title: "Great Saving!",
                message: "You're saving \(String(format: "%.0f", summary.savingsRate))% of your income this month",
                impact: .high,
                category: nil
            ))
        }

        if let topCategory = summary.topSpendingCategory {
            let amount = summary.categoryBreakdown[topCategory] ?? 0
            insights.append(SpendingInsight(
                type: .recommendation,
                title: "Top Spending Category",
                message: "\(topCategory.rawValue) is your highest expense at $\(String(format: "%.2f", amount))",
                impact: .medium,
                category: topCategory
            ))
        }

        return insights.sorted { $0.impact.priority > $1.impact.priority }
    }
}

extension SpendingInsight.Impact {
    var priority: Int {
        switch self {
        case .high: return 3
        case .medium: return 2
        case .low: return 1
        }
    }
}
