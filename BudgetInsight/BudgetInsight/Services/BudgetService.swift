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

        // Fetch data from Firestore on initialization
        Task {
            await fetchDataFromFirestore()
        }
    }

    // MARK: - Firestore Data Fetching

    func fetchDataFromFirestore() async {
        print("🔄 [BudgetService] Fetching data from Firestore...")

        do {
            // Fetch active budget plan for current year
            if let firestorePlan = try await BackendService.shared.fetchActiveBudgetPlan() {
                print("✅ [BudgetService] Found existing BudgetPlan for year \(firestorePlan.year)")

                await MainActor.run {
                    self.budgetPlan = firestorePlan
                    self.saveBudgetPlan()
                }

                // Fetch associated UserIncome
                if !firestorePlan.userIncomeId.isEmpty {
                    if let income = try await BackendService.shared.fetchUserIncome(
                        incomeId: firestorePlan.userIncomeId)
                    {
                        print("✅ [BudgetService] Fetched UserIncome for year \(income.year)")
                        await MainActor.run {
                            self.userIncome = income
                            self.saveUserIncome()
                        }
                    }
                }
            } else {
                print("ℹ️ [BudgetService] No active BudgetPlan found in Firestore")
            }

            // Fetch budget categories
            let categories = try await BackendService.shared.fetchBudgetCategories()
            print("✅ [BudgetService] Fetched \(categories.count) categories from Firestore")
            await MainActor.run {
                self.budgetCategories = categories
                self.saveBudgetCategories()
            }
        } catch {
            print("❌ [BudgetService] Error fetching data from Firestore: \(error)")
        }
    }

    // MARK: - User Income Management

    func updateUserIncome(annualSalary: Double, contribution401k: Double) {
        let calculatedIncome = TaxService.shared.calculateAllTaxes(
            annualSalary: annualSalary,
            contribution401k: contribution401k
        )

        let currentYear = Calendar.current.component(.year, from: Date())

        // Create income with existing ID if updating, or empty ID if new
        let incomeId = (userIncome?.year == currentYear) ? (userIncome?.id ?? "") : ""

        let incomeWithYear = UserIncome(
            id: incomeId,
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

        // Save or update to Firestore
        Task {
            do {
                if !incomeId.isEmpty {
                    // Update existing income
                    try await BackendService.shared.updateUserIncome(
                        incomeId: incomeId,
                        updates: [
                            "year": incomeWithYear.year,
                            "annual_salary": incomeWithYear.annualSalary,
                            "contribution_401k": incomeWithYear.contribution401k,
                            "federal_tax": incomeWithYear.federalTax,
                            "social_security_tax": incomeWithYear.socialSecurityTax,
                            "medicare_tax": incomeWithYear.medicareTax,
                            "ny_state_tax": incomeWithYear.nyStateTax,
                            "nyc_tax": incomeWithYear.nycTax,
                        ]
                    )
                    print("✅ [BudgetService] Updated UserIncome in Firestore")

                    await MainActor.run {
                        self.updateBudgetPlanIncome(income: incomeWithYear)
                    }
                } else {
                    // Create new income
                    let firestoreId = try await BackendService.shared.createUserIncome(
                        incomeWithYear)
                    print(
                        "✅ [BudgetService] Created UserIncome in Firestore with ID: \(firestoreId)")

                    await MainActor.run {
                        var updatedIncome = incomeWithYear
                        updatedIncome.id = firestoreId
                        self.userIncome = updatedIncome
                        self.saveUserIncome()

                        // Update or create budget plan with the Firestore income ID
                        self.updateBudgetPlanIncome(income: updatedIncome)
                    }
                }
            } catch {
                print("❌ [BudgetService] Error saving UserIncome to Firestore: \(error)")
            }
        }

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

                // Update BudgetPlan in Firestore
                Task {
                    do {
                        try await self.saveBudgetPlanToFirestore(plan)
                    } catch {
                        print(
                            "❌ [BudgetService] Error updating BudgetPlan after adding category: \(error)"
                        )
                    }
                }
            }
        }
    }

    func updateCategoryPercentage(categoryId: String, newPercentage: Double) {
        if let index = budgetCategories.firstIndex(where: { $0.id == categoryId && $0.isActive }) {
            budgetCategories[index].percentage = newPercentage
            saveBudgetCategories()

            // Update category in Firestore
            Task {
                do {
                    try await BackendService.shared.updateBudgetCategory(
                        categoryId: categoryId,
                        updates: ["percentage": newPercentage]
                    )
                    print("✅ [BudgetService] Updated category percentage in Firestore")
                } catch {
                    print("❌ [BudgetService] Error updating category in Firestore: \(error)")
                }
            }
        }
    }

    func updateCategory(
        categoryId: String, name: String? = nil, percentage: Double? = nil, icon: String? = nil
    ) {
        if let index = budgetCategories.firstIndex(where: { $0.id == categoryId && $0.isActive }) {
            var updates: [String: Any] = [:]

            if let name = name {
                budgetCategories[index].name = name
                updates["name"] = name
            }
            if let percentage = percentage {
                budgetCategories[index].percentage = percentage
                updates["percentage"] = percentage
            }
            if let icon = icon {
                budgetCategories[index].icon = icon
                updates["icon"] = icon
            }
            saveBudgetCategories()

            // Update category in Firestore if there are any updates
            if !updates.isEmpty {
                Task {
                    do {
                        try await BackendService.shared.updateBudgetCategory(
                            categoryId: categoryId,
                            updates: updates
                        )
                        print("✅ [BudgetService] Updated category in Firestore")
                    } catch {
                        print("❌ [BudgetService] Error updating category in Firestore: \(error)")
                    }
                }
            }
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

                // Update both in Firestore
                Task {
                    do {
                        // Mark category as inactive in Firestore
                        try await BackendService.shared.deleteBudgetCategory(categoryId)
                        print("✅ [BudgetService] Marked category as inactive in Firestore")

                        // Update BudgetPlan in Firestore
                        try await self.saveBudgetPlanToFirestore(plan)
                    } catch {
                        print("❌ [BudgetService] Error deleting category: \(error)")
                    }
                }
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

            // Save update to Firestore
            Task {
                do {
                    try await self.saveBudgetPlanToFirestore(updatedPlan)
                } catch {
                    print("❌ [BudgetService] Error updating BudgetPlan in Firestore: \(error)")
                }
            }
        } else {
            // Create new plan for current year
            let activeCategoryIds = getActiveCategories().filter { !$0.id.isEmpty }.map { $0.id }
            let newPlan = BudgetPlan(
                id: "",  // Firestore will generate this
                year: income.year,
                annualSalaryGross: income.annualSalary,
                userIncomeId: income.id,
                categoryIds: activeCategoryIds
            )
            budgetPlan = newPlan
            saveBudgetPlan()

            // Save to Firestore to get real ID
            Task {
                do {
                    let firestoreId = try await BackendService.shared.createBudgetPlan(newPlan)
                    print(
                        "✅ [BudgetService] Created BudgetPlan in Firestore with ID: \(firestoreId)")

                    await MainActor.run {
                        var updatedPlan = newPlan
                        updatedPlan.id = firestoreId
                        self.budgetPlan = updatedPlan
                        self.saveBudgetPlan()
                    }
                } catch {
                    print("❌ [BudgetService] Error creating BudgetPlan in Firestore: \(error)")
                }
            }
        }
    }

    private func saveBudgetPlanToFirestore(_ plan: BudgetPlan) async throws {
        guard !plan.id.isEmpty else {
            print("⚠️ [BudgetService] Cannot update BudgetPlan with empty ID")
            return
        }

        // Update the existing plan in Firestore
        try await BackendService.shared.updateBudgetPlan(
            planId: plan.id,
            updates: [
                "year": plan.year,
                "annual_salary_gross": plan.annualSalaryGross,
                "user_income_id": plan.userIncomeId,
                "category_ids": plan.categoryIds,
            ]
        )
        print("✅ [BudgetService] Updated BudgetPlan in Firestore")
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
