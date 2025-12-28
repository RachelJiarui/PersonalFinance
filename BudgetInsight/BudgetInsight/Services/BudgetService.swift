import Foundation

class BudgetService: ObservableObject {
    static let shared = BudgetService()

    // New percentage-based budget system
    @Published var budgetPlan: BudgetPlan?
    @Published var budgetCategories: [BudgetCategory] = []
    @Published var userIncome: UserIncome?

    // Category spending tracking (categoryId -> amount spent this month)
    @Published var categorySpending: [String: Double] = [:]

    private let userDefaults = UserDefaults.standard
    private let budgetPlanKey = "budget_plan"
    private let categoriesKey = "budget_categories"
    private let incomeKey = "user_income"

    private init() {
        loadUserIncome()
        loadBudgetCategories()
        loadBudgetPlan()
    }

    // MARK: - User Income Management

    func updateUserIncome(annualSalary: Double, contribution401k: Double) {
        let calculatedIncome = TaxService.shared.calculateAllTaxes(
            annualSalary: annualSalary,
            contribution401k: contribution401k
        )

        let currentYear = Calendar.current.component(.year, from: Date())
        let incomeWithYear = UserIncome(
            id: calculatedIncome.id,
            year: currentYear,
            annualSalary: calculatedIncome.annualSalary,
            contribution401k: calculatedIncome.contribution401k,
            federalTax: calculatedIncome.federalTax,
            socialSecurityTax: calculatedIncome.socialSecurityTax,
            medicareTax: calculatedIncome.medicareTax,
            nyStateTax: calculatedIncome.nyStateTax,
            nycTax: calculatedIncome.nycTax
        )

        self.userIncome = incomeWithYear
        saveUserIncome()

        // Update or create budget plan
        updateBudgetPlanIncome(income: incomeWithYear)

        // Trigger UI update
        objectWillChange.send()
    }

    // MARK: - Budget Category Management

    func createCategory(name: String, percentage: Double, icon: String) -> BudgetCategory {
        // Create category with empty ID - will be set after backend saves it
        let newCategory = BudgetCategory(
            id: "",  // Firestore will generate this
            name: name,
            percentage: percentage,
            icon: icon,
            isActive: true
        )

        budgetCategories.append(newCategory)
        saveBudgetCategories()

        // Note: Budget plan will be updated once we get the real ID from backend
        return newCategory
    }

    func updateCategoryWithId(tempCategory: BudgetCategory, firestoreId: String) {
        // Find and update the category with the Firestore-generated ID
        if let index = budgetCategories.firstIndex(where: {
            $0.name == tempCategory.name && $0.id.isEmpty
        }) {
            var updated = budgetCategories[index]
            updated.id = firestoreId
            budgetCategories[index] = updated
            saveBudgetCategories()

            // Add to budget plan if exists
            if var plan = budgetPlan {
                plan.categoryIds.append(firestoreId)
                budgetPlan = plan
                saveBudgetPlan()
            }
        }
    }

    func updateCategoryPercentage(categoryId: String, newPercentage: Double) {
        if let index = budgetCategories.firstIndex(where: { $0.id == categoryId && $0.isActive }) {
            budgetCategories[index].percentage = newPercentage
            saveBudgetCategories()
        }
    }

    func updateCategory(
        categoryId: String, name: String? = nil, percentage: Double? = nil, icon: String? = nil
    ) {
        if let index = budgetCategories.firstIndex(where: { $0.id == categoryId && $0.isActive }) {
            if let name = name {
                budgetCategories[index].name = name
            }
            if let percentage = percentage {
                budgetCategories[index].percentage = percentage
            }
            if let icon = icon {
                budgetCategories[index].icon = icon
            }
            saveBudgetCategories()
        }
    }

    func deleteCategory(categoryId: String) {
        // Mark as inactive instead of deleting (for historical data integrity)
        if let index = budgetCategories.firstIndex(where: { $0.id == categoryId }) {
            budgetCategories[index].isActive = false
            saveBudgetCategories()

            // Remove from budget plan's active categories
            if var plan = budgetPlan {
                plan.categoryIds.removeAll { $0 == categoryId }
                budgetPlan = plan
                saveBudgetPlan()
            }
        }
    }

    func getActiveCategories() -> [BudgetCategory] {
        return budgetCategories.filter { $0.isActive }
    }

    func getCategoryById(_ id: String) -> BudgetCategory? {
        return budgetCategories.first { $0.id == id }
    }

    // MARK: - Budget Plan Management

    func updateBudgetPlanIncome(income: UserIncome) {
        if let plan = budgetPlan, plan.year == income.year {
            // Update existing plan
            let updatedPlan = BudgetPlan(
                id: plan.id,
                year: plan.year,
                annualSalaryGross: income.annualSalary,
                userIncomeId: income.id,
                categoryIds: plan.categoryIds
            )
            budgetPlan = updatedPlan
            saveBudgetPlan()
        } else {
            // Create new plan for current year
            let activeCategoryIds = getActiveCategories().map { $0.id }
            let newPlan = BudgetPlan(
                id: UUID().uuidString,
                year: income.year,
                annualSalaryGross: income.annualSalary,
                userIncomeId: income.id,
                categoryIds: activeCategoryIds
            )
            budgetPlan = newPlan
            saveBudgetPlan()
        }
    }

    func validateAllocation() -> (isValid: Bool, totalPercentage: Double) {
        let activeCategories = getActiveCategories()
        let total = activeCategories.reduce(0.0) { $0 + $1.percentage }
        return (total <= 100.01, total)  // Allow small floating point error
    }

    // MARK: - Category Spending Tracking

    func updateCategorySpending(with transactions: [Transaction]) {
        print(
            "\n💰 [BudgetService] Updating category spending with \(transactions.count) transactions..."
        )

        let calendar = Calendar.current
        let now = Date()
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)

        // Reset all spending
        categorySpending.removeAll()

        // Calculate current month spending per category
        let currentMonthTransactions = transactions.filter { transaction in
            let month = calendar.component(.month, from: transaction.date)
            let year = calendar.component(.year, from: transaction.date)
            return month == currentMonth && year == currentYear && transaction.isExpense
        }

        for transaction in currentMonthTransactions {
            let categoryId = transaction.categoryId
            categorySpending[categoryId, default: 0] += transaction.amount
        }

        print("📊 [BudgetService] Category spending updated:")
        for (categoryId, amount) in categorySpending {
            if let category = getCategoryById(categoryId) {
                print("   \(category.name): $\(String(format: "%.2f", amount))")
            }
        }
        print("✅ [BudgetService] Category spending update complete\n")
    }

    func getSpending(forCategoryId categoryId: String) -> Double {
        return categorySpending[categoryId] ?? 0.0
    }

    func getCategoryBudgetAmount(categoryId: String) -> Double? {
        guard let category = getCategoryById(categoryId),
            let income = userIncome
        else {
            return nil
        }
        return category.dollarAmount(monthlyTakeHome: income.monthlyTakeHome)
    }

    func getCategorySpendingRatio(categoryId: String) -> Double? {
        guard let category = getCategoryById(categoryId),
            let income = userIncome
        else {
            return nil
        }
        let spent = getSpending(forCategoryId: categoryId)
        return category.spendingRatio(currentSpent: spent, monthlyTakeHome: income.monthlyTakeHome)
    }

    // MARK: - Clear Data

    func clearAllData() {
        budgetPlan = nil
        budgetCategories = []
        userIncome = nil
        categorySpending = [:]

        userDefaults.removeObject(forKey: budgetPlanKey)
        userDefaults.removeObject(forKey: categoriesKey)
        userDefaults.removeObject(forKey: incomeKey)
    }

    // MARK: - Persistence

    private func saveBudgetPlan() {
        if let encoded = try? JSONEncoder().encode(budgetPlan) {
            userDefaults.set(encoded, forKey: budgetPlanKey)
        }
    }

    private func loadBudgetPlan() {
        if let data = userDefaults.data(forKey: budgetPlanKey),
            let decoded = try? JSONDecoder().decode(BudgetPlan.self, from: data)
        {
            budgetPlan = decoded
        }
    }

    private func saveBudgetCategories() {
        if let encoded = try? JSONEncoder().encode(budgetCategories) {
            userDefaults.set(encoded, forKey: categoriesKey)
        }
    }

    private func loadBudgetCategories() {
        if let data = userDefaults.data(forKey: categoriesKey),
            let decoded = try? JSONDecoder().decode([BudgetCategory].self, from: data)
        {
            budgetCategories = decoded
        }
        // No default categories - user creates their own in Budget Plan
    }

    private func saveUserIncome() {
        if let encoded = try? JSONEncoder().encode(userIncome) {
            userDefaults.set(encoded, forKey: incomeKey)
        }
    }

    private func loadUserIncome() {
        if let data = userDefaults.data(forKey: incomeKey),
            let decoded = try? JSONDecoder().decode(UserIncome.self, from: data)
        {
            userIncome = decoded
        }
    }
}
