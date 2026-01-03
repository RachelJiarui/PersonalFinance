import Combine
import Foundation
import WidgetKit

class BudgetService: ObservableObject {
    static let shared = BudgetService()

    // Budget plan with merged income/tax data
    @Published var budgetPlan: BudgetPlan?
    @Published var budgetCategories: [BudgetCategory] = []

    // Category spending tracking (categoryId -> amount spent this month)
    @Published var categorySpending: [String: Double] = [:]

    private let userDefaults = SharedUserDefaults.shared
    private let budgetPlanKey = "budget_plan"
    private let categoriesKey = "budget_categories"
    private var cancellables = Set<AnyCancellable>()

    private init() {
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
            // Fetch active budget plan (no longer year-specific)
            if let firestorePlan = try await BackendService.shared.fetchActiveBudgetPlan() {
                print(
                    "✅ [BudgetService] Found active BudgetPlan: \(firestorePlan.dateRangeString())")

                await MainActor.run {
                    self.budgetPlan = firestorePlan
                    self.saveBudgetPlan()
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

    // MARK: - Budget Plan Management (Income & Taxes)

    /// Update budget plan with new income and tax data
    /// Uses edit logic: same month = in-place update, different month = new plan
    func updateBudgetPlanIncome(annualSalary: Double, contribution401k: Double) async {
        let calculatedTaxes = TaxService.shared.calculateAllTaxes(
            annualSalary: annualSalary,
            contribution401k: contribution401k
        )

        let now = Date()

        if let currentPlan = budgetPlan {
            // Check if we should update in-place or create new plan
            if shouldUpdateInPlace(currentPlan: currentPlan, editDate: now) {
                // Same month as created_at - update in-place
                await updateBudgetPlanInPlace(
                    annualSalary: annualSalary,
                    contribution401k: contribution401k,
                    taxes: calculatedTaxes
                )
            } else {
                // Different month - create new plan
                await createNewBudgetPlan(
                    annualSalary: annualSalary,
                    contribution401k: contribution401k,
                    taxes: calculatedTaxes
                )
            }
        } else {
            // No existing plan - create first one
            await createNewBudgetPlan(
                annualSalary: annualSalary,
                contribution401k: contribution401k,
                taxes: calculatedTaxes
            )
        }
    }

    /// Determine if edit should update current plan in-place vs creating new plan
    func shouldUpdateInPlace(currentPlan: BudgetPlan, editDate: Date) -> Bool {
        let calendar = Calendar.current
        let editMonth = calendar.component(.month, from: editDate)
        let editYear = calendar.component(.year, from: editDate)
        let createdMonth = calendar.component(.month, from: currentPlan.createdAt)
        let createdYear = calendar.component(.year, from: currentPlan.createdAt)

        // Same month/year = in-place update
        return editMonth == createdMonth && editYear == createdYear
    }

    /// Update current budget plan in-place (same month as created_at)
    private func updateBudgetPlanInPlace(
        annualSalary: Double,
        contribution401k: Double,
        taxes: (
            federalTax: Double,
            socialSecurityTax: Double,
            medicareTax: Double,
            nyStateTax: Double,
            nycTax: Double
        )
    ) async {
        guard var plan = budgetPlan else { return }

        print("🔄 [BudgetService] Updating budget plan in-place...")

        // Get current active categories (might have changed since plan was created)
        let activeCategoryIds = budgetCategories.filter { $0.isActive && !$0.id.isEmpty }.map {
            $0.id
        }

        // Update plan fields
        let updatedPlan = BudgetPlan(
            id: plan.id,
            createdAt: plan.createdAt,
            endDate: plan.endDate,
            annualSalary: annualSalary,
            contribution401k: contribution401k,
            federalTax: taxes.federalTax,
            socialSecurityTax: taxes.socialSecurityTax,
            medicareTax: taxes.medicareTax,
            nyStateTax: taxes.nyStateTax,
            nycTax: taxes.nycTax,
            categoryIds: activeCategoryIds
        )

        do {
            // Update in Firestore
            try await BackendService.shared.updateBudgetPlan(
                planId: plan.id,
                updates: [
                    "annual_salary": annualSalary,
                    "contribution_401k": contribution401k,
                    "federal_tax": taxes.federalTax,
                    "social_security_tax": taxes.socialSecurityTax,
                    "medicare_tax": taxes.medicareTax,
                    "ny_state_tax": taxes.nyStateTax,
                    "nyc_tax": taxes.nycTax,
                    "category_ids": activeCategoryIds,
                ]
            )
            print("✅ [BudgetService] Updated budget plan in Firestore")

            // Update local state
            await MainActor.run {
                self.budgetPlan = updatedPlan
                self.saveBudgetPlan()
            }
        } catch {
            print("❌ [BudgetService] Error updating budget plan: \(error)")
        }
    }

    /// Create new budget plan (different month than created_at, or first plan)
    private func createNewBudgetPlan(
        annualSalary: Double,
        contribution401k: Double,
        taxes: (
            federalTax: Double,
            socialSecurityTax: Double,
            medicareTax: Double,
            nyStateTax: Double,
            nycTax: Double
        )
    ) async {
        let calendar = Calendar.current
        let now = Date()

        // Normalize to first day of current month
        let currentMonthStart = calendar.date(
            from: calendar.dateComponents([.year, .month], from: now))!

        print("🆕 [BudgetService] Creating new budget plan...")

        // Step 1: End-date the current plan if it exists
        if let currentPlan = budgetPlan {
            do {
                try await BackendService.shared.updateBudgetPlan(
                    planId: currentPlan.id,
                    updates: [
                        "end_date": ISO8601DateFormatter().string(from: currentMonthStart)
                    ]
                )
                print("✅ [BudgetService] End-dated previous plan")
            } catch {
                print("❌ [BudgetService] Error end-dating previous plan: \(error)")
                return
            }
        }

        // Step 2: Create new plan
        // Get ALL active categories (not filtered by plan, since we're creating the plan now)
        let activeCategoryIds = budgetCategories.filter { $0.isActive && !$0.id.isEmpty }.map {
            $0.id
        }

        let newPlan = BudgetPlan(
            id: "",
            createdAt: currentMonthStart,
            endDate: nil,
            annualSalary: annualSalary,
            contribution401k: contribution401k,
            federalTax: taxes.federalTax,
            socialSecurityTax: taxes.socialSecurityTax,
            medicareTax: taxes.medicareTax,
            nyStateTax: taxes.nyStateTax,
            nycTax: taxes.nycTax,
            categoryIds: activeCategoryIds
        )

        do {
            // Save to Firestore to get real ID
            let firestoreId = try await BackendService.shared.createBudgetPlan(newPlan)
            print("✅ [BudgetService] Created new BudgetPlan in Firestore with ID: \(firestoreId)")

            // Update local state
            await MainActor.run {
                let savedPlan = BudgetPlan(
                    id: firestoreId,
                    createdAt: newPlan.createdAt,
                    endDate: newPlan.endDate,
                    annualSalary: newPlan.annualSalary,
                    contribution401k: newPlan.contribution401k,
                    federalTax: newPlan.federalTax,
                    socialSecurityTax: newPlan.socialSecurityTax,
                    medicareTax: newPlan.medicareTax,
                    nyStateTax: newPlan.nyStateTax,
                    nycTax: newPlan.nycTax,
                    categoryIds: newPlan.categoryIds
                )
                self.budgetPlan = savedPlan
                self.saveBudgetPlan()
                print(
                    "✅ [BudgetService] Budget plan saved locally: Annual Salary: \(savedPlan.annualSalary), Monthly Take Home: \(savedPlan.monthlyTakeHome), Category IDs: \(savedPlan.categoryIds)"
                )
            }
        } catch {
            print("❌ [BudgetService] Error creating new budget plan: \(error)")
        }
    }

    // MARK: - Historical Budget Plan Lookup

    /// Get budget plan for a specific date (historical lookup)
    func getBudgetPlanForDate(_ date: Date) async throws -> BudgetPlan? {
        // First check local cache
        if let currentPlan = budgetPlan, currentPlan.covers(date: date) {
            return currentPlan
        }

        // Fetch from backend
        let dateFormatter = ISO8601DateFormatter()
        let dateString = dateFormatter.string(from: date)

        return try await BackendService.shared.fetchBudgetPlanForDate(dateString)
    }

    /// Get monthly take-home for a specific date (handles historical budget plans)
    func getMonthlyTakeHomeForDate(_ date: Date) async -> Double? {
        do {
            let plan = try await getBudgetPlanForDate(date)
            return plan?.monthlyTakeHome
        } catch {
            print("❌ [BudgetService] Error fetching plan for date: \(error)")
            return nil
        }
    }

    /// Get active categories for a specific date (handles historical budget plans)
    func getActiveCategoriesForDate(_ date: Date) async -> [BudgetCategory] {
        do {
            guard let plan = try await getBudgetPlanForDate(date) else {
                return []
            }

            // Fetch categories by IDs
            return budgetCategories.filter { plan.categoryIds.contains($0.id) }
        } catch {
            print("❌ [BudgetService] Error fetching categories for date: \(error)")
            return []
        }
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
                var updatedCategoryIds = plan.categoryIds
                updatedCategoryIds.append(firestoreId)

                // Update plan with new category
                Task {
                    do {
                        try await BackendService.shared.updateBudgetPlan(
                            planId: plan.id,
                            updates: ["category_ids": updatedCategoryIds]
                        )

                        // Update local state
                        await MainActor.run {
                            let updatedPlan = BudgetPlan(
                                id: plan.id,
                                createdAt: plan.createdAt,
                                endDate: plan.endDate,
                                annualSalary: plan.annualSalary,
                                contribution401k: plan.contribution401k,
                                federalTax: plan.federalTax,
                                socialSecurityTax: plan.socialSecurityTax,
                                medicareTax: plan.medicareTax,
                                nyStateTax: plan.nyStateTax,
                                nycTax: plan.nycTax,
                                categoryIds: updatedCategoryIds
                            )
                            self.budgetPlan = updatedPlan
                            self.saveBudgetPlan()
                        }
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

    func toggleCategoryStarred(categoryId: String) {
        if let index = budgetCategories.firstIndex(where: { $0.id == categoryId }) {
            budgetCategories[index].isStarred.toggle()
            let newStarredValue = budgetCategories[index].isStarred
            saveBudgetCategories()

            // Update in Firestore
            Task {
                do {
                    try await BackendService.shared.updateBudgetCategory(
                        categoryId: categoryId,
                        updates: ["is_starred": newStarredValue]
                    )
                    print("✅ [BudgetService] Updated category starred status in Firestore")
                } catch {
                    print("❌ [BudgetService] Error updating category starred status: \(error)")
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
            if let plan = budgetPlan {
                let updatedCategoryIds = plan.categoryIds.filter { $0 != categoryId }

                Task {
                    do {
                        // Mark category as inactive in Firestore
                        try await BackendService.shared.deleteBudgetCategory(categoryId)
                        print("✅ [BudgetService] Marked category as inactive in Firestore")

                        // Update budget plan
                        try await BackendService.shared.updateBudgetPlan(
                            planId: plan.id,
                            updates: ["category_ids": updatedCategoryIds]
                        )

                        // Update local state
                        await MainActor.run {
                            let updatedPlan = BudgetPlan(
                                id: plan.id,
                                createdAt: plan.createdAt,
                                endDate: plan.endDate,
                                annualSalary: plan.annualSalary,
                                contribution401k: plan.contribution401k,
                                federalTax: plan.federalTax,
                                socialSecurityTax: plan.socialSecurityTax,
                                medicareTax: plan.medicareTax,
                                nyStateTax: plan.nyStateTax,
                                nycTax: plan.nycTax,
                                categoryIds: updatedCategoryIds
                            )
                            self.budgetPlan = updatedPlan
                            self.saveBudgetPlan()
                        }
                    } catch {
                        print("❌ [BudgetService] Error deleting category: \(error)")
                    }
                }
            }
        }
    }

    func getActiveCategories() -> [BudgetCategory] {
        // If we have a budget plan, only return categories that are in the plan
        if let plan = budgetPlan {
            return budgetCategories.filter { category in
                category.isActive && plan.categoryIds.contains(category.id)
            }
        }

        // If no budget plan exists, return all active categories (for setup phase)
        return budgetCategories.filter { $0.isActive }
    }

    func getCategoryById(_ id: String) -> BudgetCategory? {
        return budgetCategories.first { $0.id == id }
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
            let plan = budgetPlan
        else {
            return nil
        }
        return category.dollarAmount(monthlyTakeHome: plan.monthlyTakeHome)
    }

    func getCategorySpendingRatio(categoryId: String) -> Double? {
        guard let category = getCategoryById(categoryId),
            let plan = budgetPlan
        else {
            return nil
        }
        let spent = getSpending(forCategoryId: categoryId)
        return category.spendingRatio(currentSpent: spent, monthlyTakeHome: plan.monthlyTakeHome)
    }

    // MARK: - Clear Data

    func clearAllData() {
        budgetPlan = nil
        budgetCategories = []
        categorySpending = [:]

        userDefaults.removeObject(forKey: budgetPlanKey)
        userDefaults.removeObject(forKey: categoriesKey)
    }

    // MARK: - Persistence

    private func saveBudgetPlan() {
        if let encoded = try? JSONEncoder().encode(budgetPlan) {
            userDefaults.set(encoded, forKey: budgetPlanKey)
            WidgetCenter.shared.reloadAllTimelines()
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
            WidgetCenter.shared.reloadAllTimelines()
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
    }
}
