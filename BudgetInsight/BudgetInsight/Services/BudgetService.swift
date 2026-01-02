import Combine
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
    private var cancellables = Set<AnyCancellable>()

    private init() {
        loadUserIncome()
        loadBudgetCategories()
        loadBudgetPlan()

        // Subscribe to allocation changes to automatically recalculate spending
        setupAllocationSubscription()

        // Fetch data from Firestore on initialization
        Task {
            await fetchDataFromFirestore()
        }
    }

    // MARK: - Reactive Subscriptions

    private func setupAllocationSubscription() {
        // Automatically recalculate category spending whenever allocations change
        AllocationService.shared.$allocations
            .sink { [weak self] _ in
                guard let self = self else { return }
                let transactions = TransactionStorageService.shared.transactions
                print("🔔 [BudgetService] Allocations changed, recalculating category spending...")
                Task { @MainActor in
                    self.updateCategorySpending(with: transactions)
                }
            }
            .store(in: &cancellables)

        // Also recalculate when transactions are loaded/updated
        TransactionStorageService.shared.$transactions
            .sink { [weak self] transactions in
                guard let self = self else { return }
                print("🔔 [BudgetService] Transactions changed, recalculating category spending...")
                Task { @MainActor in
                    self.updateCategorySpending(with: transactions)
                }
            }
            .store(in: &cancellables)

        // CRITICAL: Also recalculate when budget categories are loaded
        // This ensures spending displays correctly when categories load from Firestore
        $budgetCategories
            .sink { [weak self] categories in
                guard let self = self else { return }
                let transactions = TransactionStorageService.shared.transactions
                print(
                    "🔔 [BudgetService] Budget categories changed (\(categories.count) categories), recalculating category spending..."
                )
                Task { @MainActor in
                    self.updateCategorySpending(with: transactions)
                }
            }
            .store(in: &cancellables)
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
            let firestoreCategories = try await BackendService.shared.fetchBudgetCategories()
            print(
                "✅ [BudgetService] Fetched \(firestoreCategories.count) categories from Firestore")
            await MainActor.run {
                // Firestore is the source of truth - replace local data entirely
                self.budgetCategories = firestoreCategories
                self.saveBudgetCategories()

                print(
                    "📊 [BudgetService] Replaced local categories with Firestore data (\(firestoreCategories.count) categories)"
                )
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
            let categoryName = budgetCategories[index].name
            budgetCategories[index].isActive = false
            saveBudgetCategories()

            // Remove from budget plan's active categories by creating a new version
            if let plan = budgetPlan {
                let updatedCategoryIds = plan.categoryIds.filter { $0 != categoryId }

                // Update both in Firestore
                Task {
                    do {
                        // Mark category as inactive in Firestore
                        try await BackendService.shared.deleteBudgetCategory(categoryId)
                        print("✅ [BudgetService] Marked category as inactive in Firestore")

                        // Create new budget plan version with updated categories
                        await createBudgetPlanVersion(
                            reason: "Removed category: \(categoryName)",
                            categoryChanges: updatedCategoryIds
                        )
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
        let currentYear = Calendar.current.component(.year, from: Date())

        if let plan = budgetPlan, plan.year == currentYear {
            // Mid-year change - create new version
            Task {
                await createBudgetPlanVersion(
                    reason: "Income updated",
                    annualSalary: income.annualSalary,
                    userIncomeId: income.id
                )
            }
        } else {
            // New year - create first version for the year
            let activeCategoryIds = getActiveCategories().filter { !$0.id.isEmpty }.map { $0.id }
            let newPlan = BudgetPlan(
                id: "",  // Firestore will generate this
                year: income.year,
                annualSalaryGross: income.annualSalary,
                userIncomeId: income.id,
                categoryIds: activeCategoryIds,
                isActive: true,
                effectiveDate: Date(),
                endDate: nil,
                versionNumber: 1,
                changeReason: "Initial plan for \(income.year)",
                supersededByPlanId: nil
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

    func createBudgetPlanVersion(
        reason: String,
        annualSalary: Double? = nil,
        userIncomeId: String? = nil,
        categoryChanges: [String]? = nil
    ) async {
        guard let currentPlan = budgetPlan else { return }

        let now = Date()
        let currentYear = Calendar.current.component(.year, from: now)

        // Only create version if changing within same year
        guard currentPlan.year == currentYear else {
            print("⚠️ [BudgetService] Cannot version plan from different year")
            return
        }

        // Determine new values
        let newAnnualSalary = annualSalary ?? currentPlan.annualSalaryGross
        let newUserIncomeId = userIncomeId ?? currentPlan.userIncomeId
        let newCategoryIds = categoryChanges ?? currentPlan.categoryIds

        // Create new BudgetPlan version
        let newPlan = BudgetPlan(
            id: "",
            year: currentYear,
            annualSalaryGross: newAnnualSalary,
            userIncomeId: newUserIncomeId,
            categoryIds: newCategoryIds,
            isActive: true,
            effectiveDate: now,
            endDate: nil,
            versionNumber: currentPlan.versionNumber + 1,
            changeReason: reason,
            supersededByPlanId: nil
        )

        do {
            // Save new plan to Firestore
            let newPlanId = try await BackendService.shared.createBudgetPlan(newPlan)
            print("✅ [BudgetService] Created budget plan version \(newPlan.versionNumber)")

            // Mark old plan as superseded
            try await BackendService.shared.supersedeBudgetPlan(
                oldPlanId: currentPlan.id,
                newPlanId: newPlanId,
                endDate: now
            )
            print("✅ [BudgetService] Marked old plan as superseded")

            // Update local state
            await MainActor.run {
                var savedPlan = newPlan
                savedPlan.id = newPlanId
                self.budgetPlan = savedPlan
                self.saveBudgetPlan()
            }
        } catch {
            print("❌ [BudgetService] Error creating budget plan version: \(error)")
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

        print("📋 [BudgetService] Currently loaded categories: \(budgetCategories.count)")
        for category in budgetCategories {
            print("   - \(category.name) (ID: \(category.id), Active: \(category.isActive))")
        }

        let calendar = Calendar.current
        let now = Date()
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)

        print("📅 [BudgetService] Current date: \(now)")
        print("📅 [BudgetService] Filtering for month: \(currentMonth), year: \(currentYear)")

        // Reset all spending
        categorySpending.removeAll()

        // Get all allocations
        let allAllocations = AllocationService.shared.allocations
        print("🔗 [BudgetService] Found \(allAllocations.count) total allocations")

        // Calculate current month spending per category (including both expenses and income)
        let currentMonthTransactions = transactions.filter { transaction in
            let month = calendar.component(.month, from: transaction.date)
            let year = calendar.component(.year, from: transaction.date)
            return month == currentMonth && year == currentYear
        }

        print(
            "📅 [BudgetService] Found \(currentMonthTransactions.count) transactions in current month"
        )

        for transaction in currentMonthTransactions {
            // Find allocations for this transaction that go to categories
            let categoryAllocations = allAllocations.filter {
                $0.transactionId == transaction.id && $0.destinationType == .category
            }

            print(
                "   Transaction '\(transaction.title)': \(categoryAllocations.count) category allocations"
            )

            for allocation in categoryAllocations {
                let categoryName =
                    getCategoryById(allocation.destinationId)?.name
                    ?? "Unknown(\(allocation.destinationId))"

                // For expenses: add to spending
                // For income: subtract from spending (reimbursement)
                if transaction.isExpense {
                    let before = categorySpending[allocation.destinationId, default: 0]
                    categorySpending[allocation.destinationId, default: 0] += allocation.amount
                    let after = categorySpending[allocation.destinationId, default: 0]
                    print(
                        "      ➕ Adding $\(allocation.amount) to '\(categoryName)': $\(before) → $\(after)"
                    )
                } else {
                    let before = categorySpending[allocation.destinationId, default: 0]
                    categorySpending[allocation.destinationId, default: 0] -= allocation.amount
                    let after = categorySpending[allocation.destinationId, default: 0]
                    print(
                        "      ➖ Subtracting $\(allocation.amount) from '\(categoryName)': $\(before) → $\(after)"
                    )
                }
            }
        }

        print("📊 [BudgetService] Category spending updated:")
        for (categoryId, amount) in categorySpending {
            if let category = getCategoryById(categoryId) {
                print("   \(category.name): $\(String(format: "%.2f", amount))")
            }
        }
        if categorySpending.isEmpty {
            print("   ⚠️ No category spending calculated!")
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

    func saveBudgetCategories() {
        if let encoded = try? JSONEncoder().encode(budgetCategories) {
            userDefaults.set(encoded, forKey: categoriesKey)
        }
    }

    private func loadBudgetCategories() {
        if let data = userDefaults.data(forKey: categoriesKey),
            let decoded = try? JSONDecoder().decode([BudgetCategory].self, from: data)
        {
            budgetCategories = decoded
            print(
                "💾 [BudgetService] Loaded \(budgetCategories.count) budget categories from local storage"
            )
            for category in budgetCategories {
                print("   - \(category.name) (ID: \(category.id), Active: \(category.isActive))")
            }
        } else {
            print("⚠️ [BudgetService] No budget categories found in local storage")
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

    // MARK: - Month-End Balancing Helper Methods

    /// Get monthly take-home for a specific date (handles historical budget plans)
    func getMonthlyTakeHomeForDate(_ date: Date) -> Double? {
        // For now, use current income since we don't have historical plan fetching
        // Future enhancement: fetch the budget plan that was active on this date from Firestore
        guard let income = userIncome else { return nil }
        return income.monthlyTakeHome
    }

    /// Get active categories for a specific date (handles historical budget plans)
    func getActiveCategoriesForDate(_ date: Date) -> [BudgetCategory] {
        // For now, return current active categories
        // Future enhancement: fetch categories from the budget plan active on this date
        return getActiveCategories()
    }
}
