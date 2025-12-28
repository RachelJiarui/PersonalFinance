import Combine
import Foundation

@MainActor
class BudgetViewModel: ObservableObject {
    @Published var userIncome: UserIncome?
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
        budgetService.$userIncome
            .assign(to: &$userIncome)

        budgetService.$budgetPlan
            .sink { [weak self] plan in
                self?.budgetPlan = plan
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
        if let income = budgetService.userIncome {
            annualSalaryInput = String(format: "%.0f", income.annualSalary)
            contribution401kInput = String(format: "%.0f", income.contribution401k)
        }
    }

    // MARK: - Income Management

    func updateIncome() {
        guard let salary = Double(annualSalaryInput),
            let contrib = Double(contribution401kInput),
            salary > 0
        else {
            validationError = "Please enter a valid salary"
            return
        }

        guard contrib >= 0 else {
            validationError = "401k contribution cannot be negative"
            return
        }

        guard contrib <= salary else {
            validationError = "401k contribution cannot exceed salary"
            return
        }

        budgetService.updateUserIncome(annualSalary: salary, contribution401k: contrib)
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

    // MARK: - Data Management

    func clearAllData() {
        budgetService.clearAllData()
        annualSalaryInput = ""
        contribution401kInput = ""
        validationError = nil
    }

    // MARK: - Validation

    func validateAllocation() {
        let (isValid, total) = budgetService.validateAllocation()

        if !isValid && total > 100.01 {
            validationError = "Total exceeds 100% by \(String(format: "%.1f", total - 100))%"
            isAllocationValid = false
        } else if total < 99.99 {
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
        return userIncome?.monthlyTakeHome ?? 0.0
    }

    var annualTakeHome: Double {
        return userIncome?.annualTakeHome ?? 0.0
    }
}
