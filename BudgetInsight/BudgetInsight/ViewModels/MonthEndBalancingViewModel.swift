import Foundation
import SwiftUI

class MonthEndBalancingViewModel: ObservableObject {
    @Published var currentStep: Int = 0
    @Published var currentMonthStats: MonthWrappedStats?
    @Published var isProcessing: Bool = false
    @Published var errorMessage: String? = nil

    private let balancingService = MonthEndBalancingService.shared

    let totalSteps = 3  // MonthWrapped, ReviewData, Summary

    // MARK: - Initialization

    func loadStatsForMonth(year: Int, month: Int) {
        guard let stats = balancingService.calculateMonthStats(year: year, month: month) else {
            errorMessage = "Unable to calculate statistics for this month"
            return
        }

        currentMonthStats = stats
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

        // Update stats
        currentMonthStats = newStats
    }

    // MARK: - Navigation

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

    // MARK: - Completion

    func completeBalancing() async {
        guard let stats = currentMonthStats else {
            await MainActor.run {
                errorMessage = "No statistics available"
            }
            return
        }

        await MainActor.run {
            isProcessing = true
            errorMessage = nil
        }

        do {
            // Auto-allocate net savings/deficit to default buckets
            let transactionIds = try await balancingService.autoAllocateToDefaultBuckets(
                for: stats
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
        switch currentStep {
        case 0:
            return "Step 1 of 3: Review Summary"
        case 1:
            return "Step 2 of 3: Review & Edit Data"
        case 2:
            return "Step 3 of 3: Confirm & Complete"
        default:
            return ""
        }
    }
}
