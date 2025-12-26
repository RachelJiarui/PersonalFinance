import Foundation
import Combine

@MainActor
class BudgetViewModel: ObservableObject {
    @Published var userIncome: UserIncome?
    @Published var budgetAllocation: BudgetAllocation?
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

        budgetService.$budgetAllocation
            .sink { [weak self] allocation in
                self?.budgetAllocation = allocation
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
              salary > 0 else {
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

    func addCategory(name: String, percentage: Double, icon: String, color: String) {
        guard !name.isEmpty else { return }
        guard percentage >= 0 && percentage <= 100 else { return }

        budgetService.createCategory(name: name, percentage: percentage, icon: icon, color: color)
        validateAllocation()
    }

    func updateCategoryPercentage(categoryId: UUID, percentage: Double) {
        guard percentage >= 0 && percentage <= 100 else { return }

        budgetService.updateCategoryPercentage(categoryId: categoryId, newPercentage: percentage)
        validateAllocation()
    }

    func deleteCategory(categoryId: UUID) {
        budgetService.deleteCategory(categoryId: categoryId)
        validateAllocation()
    }

    // MARK: - Validation

    func validateAllocation() {
        guard let allocation = budgetAllocation else {
            isAllocationValid = false
            validationError = nil
            return
        }

        let total = allocation.totalPercentage

        if total > 100.01 {
            validationError = "Total exceeds 100% by \(String(format: "%.1f", total - 100))%"
            isAllocationValid = false
        } else {
            validationError = nil
            isAllocationValid = true
        }
    }

    // MARK: - Default Categories

    func createDefaultCategories() {
        let defaults: [(String, Double, String)] = [
            ("Food & Dining", 15.0, "fork.knife"),
            ("Shopping", 10.0, "bag.fill"),
            ("Transportation", 10.0, "car.fill"),
            ("Entertainment", 5.0, "tv.fill"),
            ("Utilities", 10.0, "house.fill"),
            ("Healthcare", 5.0, "cross.case.fill"),
            ("Savings", 20.0, "dollarsign.circle.fill")
        ]

        for (name, pct, icon) in defaults {
            budgetService.createCategory(name: name, percentage: pct, icon: icon, color: "blue")
        }

        validateAllocation()
    }
}
