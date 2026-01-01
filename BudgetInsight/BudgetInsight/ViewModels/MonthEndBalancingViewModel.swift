import Foundation
import SwiftUI

class MonthEndBalancingViewModel: ObservableObject {
    @Published var currentStep: Int = 0
    @Published var currentMonthStats: MonthWrappedStats?
    @Published var categoryBalances: [CategoryBalance] = []
    @Published var isProcessing: Bool = false
    @Published var errorMessage: String? = nil
    @Published var showReviewData: Bool = false

    private let balancingService = MonthEndBalancingService.shared

    let totalSteps = 4  // MonthWrapped, AllocateSavings, CoverDeficits, Summary

    // MARK: - Initialization

    func loadStatsForMonth(year: Int, month: Int) {
        guard let stats = balancingService.calculateMonthStats(year: year, month: month) else {
            errorMessage = "Unable to calculate statistics for this month"
            return
        }

        currentMonthStats = stats
        categoryBalances = stats.categoryBalances
        currentStep = 0
        errorMessage = nil
    }

    /// Refresh stats for the current month (e.g., after editing transactions)
    func refreshCurrentMonthStats() {
        guard let stats = currentMonthStats else { return }

        // Recalculate stats with updated transactions
        guard
            let newStats = balancingService.calculateMonthStats(
                year: stats.year, month: stats.month)
        else {
            errorMessage = "Unable to refresh statistics"
            return
        }

        // Preserve existing allocations by category ID
        let existingAllocations = categoryBalances.reduce(into: [String: BalancingDestination]()) {
            result, balance in
            if let destination = balance.allocatedTo {
                result[balance.category.id] = destination
            }
        }

        // Update stats and category balances
        currentMonthStats = newStats
        categoryBalances = newStats.categoryBalances

        // Re-apply existing allocations
        for index in categoryBalances.indices {
            if let destination = existingAllocations[categoryBalances[index].category.id] {
                categoryBalances[index].allocatedTo = destination
            }
        }
    }

    // MARK: - Navigation

    func canProceedToNextStep() -> Bool {
        switch currentStep {
        case 0:
            // Step 1: MonthWrapped - always can proceed
            return true

        case 1:
            // Step 2: AllocateSavings - must allocate all surpluses
            guard let stats = currentMonthStats else { return false }
            let surplusCategories = stats.categoriesWithSavings

            for surplusCategory in surplusCategories {
                // Find matching category balance
                if let matchingBalance = categoryBalances.first(where: {
                    $0.category.id == surplusCategory.category.id
                }) {
                    if matchingBalance.allocatedTo == nil {
                        return false  // Not all surpluses allocated
                    }
                } else {
                    return false
                }
            }
            return true

        case 2:
            // Step 3: CoverDeficits - must cover all deficits
            guard let stats = currentMonthStats else { return false }
            let deficitCategories = stats.categoriesWithDeficits

            for deficitCategory in deficitCategories {
                // Find matching category balance
                if let matchingBalance = categoryBalances.first(where: {
                    $0.category.id == deficitCategory.category.id
                }) {
                    if matchingBalance.allocatedTo == nil {
                        return false  // Not all deficits covered
                    }
                } else {
                    return false
                }
            }
            return true

        case 3:
            // Step 4: Summary - can always complete
            return true

        default:
            return false
        }
    }

    func nextStep() {
        if currentStep < totalSteps - 1 {
            currentStep += 1
        }
    }

    func previousStep() {
        if currentStep > 0 {
            currentStep -= 1
        }
    }

    // MARK: - Allocation Management

    func setAllocation(for categoryId: String, destination: BalancingDestination) {
        if let index = categoryBalances.firstIndex(where: { $0.category.id == categoryId }) {
            categoryBalances[index].allocatedTo = destination
        }
    }

    func getAllocation(for categoryId: String) -> BalancingDestination? {
        return categoryBalances.first(where: { $0.category.id == categoryId })?.allocatedTo
    }

    // MARK: - Completion

    func completeBalancing() async {
        guard let stats = currentMonthStats else {
            errorMessage = "No statistics available"
            return
        }

        isProcessing = true
        errorMessage = nil

        // Validate allocations
        let validation = balancingService.validateAllocations(stats, allocations: categoryBalances)
        if !validation.isValid {
            await MainActor.run {
                errorMessage = validation.errors.joined(separator: "\n")
                isProcessing = false
            }
            return
        }

        do {
            // Create all balancing transactions
            let transactionIds = try await balancingService.createBalancingTransactions(
                for: stats,
                with: categoryBalances
            )

            // Mark month as balanced
            await MainActor.run {
                balancingService.markMonthBalanced(
                    year: stats.year,
                    month: stats.month,
                    transactionIds: transactionIds
                )
                isProcessing = false
            }

            print(
                "✅ [ViewModel] Successfully completed balancing for \(stats.monthName) \(stats.year)"
            )

        } catch {
            await MainActor.run {
                errorMessage =
                    "Failed to create balancing transactions: \(error.localizedDescription)"
                isProcessing = false
            }
        }
    }

    // MARK: - Helper Methods

    func progressText() -> String {
        guard let stats = currentMonthStats else { return "" }

        switch currentStep {
        case 0:
            return "Step 1 of 4: Review Summary"
        case 1:
            let surplusCount = stats.categoriesWithSavings.count
            let allocatedCount = categoryBalances.filter { balance in
                stats.categoriesWithSavings.contains(where: {
                    $0.category.id == balance.category.id
                }) && balance.allocatedTo != nil
            }.count
            return "Step 2 of 4: Allocate Savings (\(allocatedCount)/\(surplusCount))"
        case 2:
            let deficitCount = stats.categoriesWithDeficits.count
            let coveredCount = categoryBalances.filter { balance in
                stats.categoriesWithDeficits.contains(where: {
                    $0.category.id == balance.category.id
                }) && balance.allocatedTo != nil
            }.count
            return "Step 3 of 4: Cover Deficits (\(coveredCount)/\(deficitCount))"
        case 3:
            return "Step 4 of 4: Review & Complete"
        default:
            return ""
        }
    }
}
