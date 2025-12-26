import Foundation

class BudgetService: ObservableObject {
    static let shared = BudgetService()

    @Published var budgets: [Budget] = []
    @Published var spendingSummary: SpendingSummary?

    private let userDefaults = UserDefaults.standard
    private let budgetsKey = "saved_budgets"

    private init() {
        loadBudgets()
    }

    func calculateSpendingSummary(transactions: [Transaction]) -> SpendingSummary {
        let calendar = Calendar.current
        let now = Date()
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)

        let currentMonthTransactions = transactions.filter { transaction in
            let month = calendar.component(.month, from: transaction.date)
            let year = calendar.component(.year, from: transaction.date)
            return month == currentMonth && year == currentYear
        }

        var categoryBreakdown: [TransactionCategory: Double] = [:]
        var totalIncome: Double = 0
        var totalExpenses: Double = 0

        for transaction in currentMonthTransactions {
            let category = TransactionCategory.categorize(transaction.category)

            if transaction.amount < 0 {
                totalIncome += abs(transaction.amount)
            } else {
                totalExpenses += transaction.amount
                categoryBreakdown[category, default: 0] += transaction.amount
            }
        }

        let topCategory = categoryBreakdown.max(by: { $0.value < $1.value })?.key

        let previousMonth = calendar.date(byAdding: .month, value: -1, to: now)!
        let previousMonthTransactions = transactions.filter { transaction in
            let month = calendar.component(.month, from: transaction.date)
            let year = calendar.component(.year, from: transaction.date)
            let prevMonth = calendar.component(.month, from: previousMonth)
            let prevYear = calendar.component(.year, from: previousMonth)
            return month == prevMonth && year == prevYear
        }

        let previousExpenses = previousMonthTransactions.reduce(0.0) { sum, transaction in
            transaction.amount > 0 ? sum + transaction.amount : sum
        }

        let monthOverMonth = previousExpenses > 0 ? ((totalExpenses - previousExpenses) / previousExpenses) * 100 : 0

        return SpendingSummary(
            totalIncome: totalIncome,
            totalExpenses: totalExpenses,
            categoryBreakdown: categoryBreakdown,
            monthOverMonth: monthOverMonth,
            topSpendingCategory: topCategory
        )
    }

    func updateBudgets(with transactions: [Transaction]) {
        print("\n💰 [BudgetService] Updating budgets with \(transactions.count) transactions...")

        let summary = calculateSpendingSummary(transactions: transactions)
        self.spendingSummary = summary

        print("📈 [BudgetService] Spending Summary:")
        print("   Income: $\(summary.totalIncome)")
        print("   Expenses: $\(summary.totalExpenses)")
        print("   Net Cash Flow: $\(summary.netCashFlow)")
        print("   Savings Rate: \(summary.savingsRate)%")
        print("   Category Breakdown:")
        for (category, amount) in summary.categoryBreakdown.sorted(by: { $0.value > $1.value }) {
            print("     - \(category.rawValue): $\(amount)")
        }

        let calendar = Calendar.current
        let now = Date()
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)

        print("\n📊 [BudgetService] Updating budget categories...")
        for index in budgets.indices {
            let category = budgets[index].category

            let monthlySpent = transactions.filter { transaction in
                let month = calendar.component(.month, from: transaction.date)
                let year = calendar.component(.year, from: transaction.date)
                let txCategory = TransactionCategory.categorize(transaction.category)
                return month == currentMonth && year == currentYear && txCategory == category && transaction.amount > 0
            }.reduce(0.0) { $0 + $1.amount }

            let yearlySpent = transactions.filter { transaction in
                let year = calendar.component(.year, from: transaction.date)
                let txCategory = TransactionCategory.categorize(transaction.category)
                return year == currentYear && txCategory == category && transaction.amount > 0
            }.reduce(0.0) { $0 + $1.amount }

            budgets[index].currentMonthSpent = monthlySpent
            budgets[index].currentYearSpent = yearlySpent

            print("   \(category.rawValue): $\(monthlySpent) / $\(budgets[index].monthlyLimit) monthly")
        }

        saveBudgets()
        print("✅ [BudgetService] Budgets updated and saved\n")
    }

    func createDefaultBudgets() {
        budgets = [
            Budget(id: UUID(), category: .food, monthlyLimit: 600, yearlyLimit: 7200, currentMonthSpent: 0, currentYearSpent: 0),
            Budget(id: UUID(), category: .shopping, monthlyLimit: 400, yearlyLimit: 4800, currentMonthSpent: 0, currentYearSpent: 0),
            Budget(id: UUID(), category: .transportation, monthlyLimit: 300, yearlyLimit: 3600, currentMonthSpent: 0, currentYearSpent: 0),
            Budget(id: UUID(), category: .entertainment, monthlyLimit: 200, yearlyLimit: 2400, currentMonthSpent: 0, currentYearSpent: 0),
            Budget(id: UUID(), category: .utilities, monthlyLimit: 250, yearlyLimit: 3000, currentMonthSpent: 0, currentYearSpent: 0)
        ]
        saveBudgets()
    }

    func updateBudgetLimit(budgetId: UUID, monthlyLimit: Double, yearlyLimit: Double) {
        if let index = budgets.firstIndex(where: { $0.id == budgetId }) {
            budgets[index].monthlyLimit = monthlyLimit
            budgets[index].yearlyLimit = yearlyLimit
            saveBudgets()
        }
    }

    private func saveBudgets() {
        if let encoded = try? JSONEncoder().encode(budgets) {
            userDefaults.set(encoded, forKey: budgetsKey)
        }
    }

    private func loadBudgets() {
        if let data = userDefaults.data(forKey: budgetsKey),
           let decoded = try? JSONDecoder().decode([Budget].self, from: data) {
            budgets = decoded
        } else {
            createDefaultBudgets()
        }
    }
}
