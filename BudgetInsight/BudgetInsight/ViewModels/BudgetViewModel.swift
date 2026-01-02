import Combine
import Foundation

@MainActor
class BudgetViewModel: ObservableObject {
    @Published var budgetPlan: BudgetPlan?
    @Published var budgetCategories: [BudgetCategory] = []
    @Published var validationError: String?
    @Published var isAllocationValid: Bool = true

    // Form fields
    @Published var annualSalaryInput: String = ""
    @Published var contribution401kInput: String = ""

    private let budgetService = BudgetService.shared
    private let taxService = TaxService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        setupSubscriptions()
        loadData()
    }

    private func setupSubscriptions() {
        budgetService.$budgetPlan
            .sink { [weak self] plan in
                self?.budgetPlan = plan
                // Update input fields when budget plan changes
                if let plan = plan {
                    self?.annualSalaryInput = String(format: "%.0f", plan.annualSalary)
                    self?.contribution401kInput = String(format: "%.0f", plan.contribution401k)
                }
                self?.validateAllocation()
            }
            .store(in: &cancellables)

        budgetService.$budgetCategories
            .sink { [weak self] categories in
                self?.budgetCategories = categories
                self?.validateAllocation()
            }
            .store(in: &cancellables)
    }

    private func loadData() {
        if let plan = budgetService.budgetPlan {
            annualSalaryInput = String(format: "%.0f", plan.annualSalary)
            contribution401kInput = String(format: "%.0f", plan.contribution401k)
        }
    }

    // MARK: - Income Management

    func updateIncome() async {
        print(
            "📝 [BudgetViewModel] updateIncome() called with salary: \(annualSalaryInput), 401k: \(contribution401kInput)"
        )

        guard let salary = Double(annualSalaryInput),
            let contrib = Double(contribution401kInput),
            salary > 0
        else {
            validationError = "Please enter a valid salary"
            print("❌ [BudgetViewModel] Validation failed: invalid salary")
            return
        }

        guard contrib >= 0 else {
            validationError = "401k contribution cannot be negative"
            print("❌ [BudgetViewModel] Validation failed: negative 401k")
            return
        }

        guard contrib <= salary else {
            validationError = "401k contribution cannot exceed salary"
            print("❌ [BudgetViewModel] Validation failed: 401k exceeds salary")
            return
        }

        print(
            "✅ [BudgetViewModel] Validation passed, calling budgetService.updateBudgetPlanIncome()")
        await budgetService.updateBudgetPlanIncome(annualSalary: salary, contribution401k: contrib)
        print("✅ [BudgetViewModel] updateBudgetPlanIncome() completed")
        validationError = nil
    }

    // MARK: - Category Management

    func addCategory(name: String, percentage: Double, icon: String) {
        guard !name.isEmpty else { return }
        guard percentage >= 0 && percentage <= 100 else { return }

        let tempCategory = budgetService.createCategory(
            name: name, percentage: percentage, icon: icon)
        print(
            "📝 [BudgetViewModel] Created temp category '\(name)' with empty ID, saving to Firestore..."
        )

        // Save to Firestore to get real ID
        Task {
            do {
                let firestoreId = try await BackendService.shared.createBudgetCategory(tempCategory)
                print("✅ [BudgetViewModel] Got Firestore ID for '\(name)': \(firestoreId)")
                await MainActor.run {
                    budgetService.updateCategoryWithId(
                        tempCategory: tempCategory, firestoreId: firestoreId)
                    print("✅ [BudgetViewModel] Updated category '\(name)' with Firestore ID")
                    validateAllocation()
                }
            } catch {
                print("❌ [BudgetViewModel] Error saving category to Firestore: \(error)")
                // Fallback: Use local UUID if backend fails (for development)
                let fallbackId = UUID().uuidString
                print("⚠️ [BudgetViewModel] Using fallback local UUID: \(fallbackId)")
                await MainActor.run {
                    budgetService.updateCategoryWithId(
                        tempCategory: tempCategory, firestoreId: fallbackId)
                    validateAllocation()
                }
            }
        }
    }

    func updateCategoryPercentage(categoryId: String, percentage: Double) {
        guard percentage >= 0 && percentage <= 100 else { return }

        budgetService.updateCategoryPercentage(categoryId: categoryId, newPercentage: percentage)
        validateAllocation()
    }

    func updateCategory(
        categoryId: String, name: String? = nil, percentage: Double? = nil, icon: String? = nil
    ) {
        budgetService.updateCategory(
            categoryId: categoryId, name: name, percentage: percentage, icon: icon)
        validateAllocation()
    }

    func deleteCategory(categoryId: String) {
        budgetService.deleteCategory(categoryId: categoryId)
        validateAllocation()
    }

    func getActiveCategories() -> [BudgetCategory] {
        return budgetService.getActiveCategories()
    }

    // MARK: - Validation

    func validateAllocation() {
        let (isValid, total) = budgetService.validateAllocation()

        if !isValid && total > 100 {
            validationError = "Total exceeds 100% by \(String(format: "%.1f", total - 100))%"
            isAllocationValid = false
        } else if total < 100 {
            validationError =
                "Total is \(String(format: "%.1f", total))% - consider allocating the remaining \(String(format: "%.1f", 100 - total))%"
            isAllocationValid = true  // It's valid, just a warning
        } else {
            validationError = nil
            isAllocationValid = true
        }
    }

    // MARK: - Helper Properties

    var totalPercentageAllocated: Double {
        return budgetService.getActiveCategories().reduce(0.0) { $0 + $1.percentage }
    }

    var remainingPercentage: Double {
        return max(0, 100.0 - totalPercentageAllocated)
    }

    var monthlyTakeHome: Double {
        return budgetPlan?.monthlyTakeHome ?? 0.0
    }

    var annualTakeHome: Double {
        return budgetPlan?.annualTakeHome ?? 0.0
    }
}
