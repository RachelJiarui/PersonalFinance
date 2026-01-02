import SwiftUI

struct HistoricalBudgetDetailView: View {
    let snapshot: PeriodSnapshot
    @State private var budgetPlan: BudgetPlan?
    @State private var categories: [BudgetCategory] = []
    @State private var categorySpending: [String: Double] = [:]
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if isLoading {
                    ProgressView("Loading historical data...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let plan = budgetPlan {
                    // Budget Plan Summary (READ-ONLY)
                    budgetPlanSummarySection(plan: plan)

                    // Category Breakdown
                    categoryBreakdownSection(plan: plan)

                    // Overall Summary
                    overallSummarySection()
                } else {
                    Text("Budget plan data not available")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle(snapshot.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadHistoricalData()
        }
    }

    private func budgetPlanSummarySection(plan: BudgetPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Budget Plan (Read-Only)")
                    .font(.headline)

                Spacer()

                Image(systemName: "lock.fill")
                    .foregroundColor(.orange)
                    .font(.caption)
            }

            VStack(spacing: 8) {
                InfoRow(label: "Active Period", value: plan.dateRangeString())
                InfoRow(label: "Annual Salary", value: "$\(String(format: "%.2f", plan.annualSalary))")
                InfoRow(label: "401(k) Contribution", value: "$\(String(format: "%.2f", plan.contribution401k))")
                InfoRow(label: "Monthly Take-Home", value: "$\(String(format: "%.2f", plan.monthlyTakeHome))")
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }

    private func categoryBreakdownSection(plan: BudgetPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Category Breakdown")
                .font(.headline)

            if categories.isEmpty {
                Text("No categories found")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(categories, id: \.id) { category in
                    CategoryComparisonCard(
                        category: category,
                        budgeted: category.dollarAmount(monthlyTakeHome: plan.monthlyTakeHome),
                        actual: categorySpending[category.id] ?? 0.0
                    )
                }
            }
        }
    }

    private func overallSummarySection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overall Summary")
                .font(.headline)

            VStack(spacing: 8) {
                InfoRow(label: "Budgeted", value: "$\(String(format: "%.2f", snapshot.monthlyTakeHome))")
                InfoRow(label: "Spent", value: "$\(String(format: "%.2f", snapshot.totalSpending))")
                InfoRow(
                    label: "Savings",
                    value: "$\(String(format: "%.2f", snapshot.savings))",
                    valueColor: snapshot.savings >= 0 ? .green : .red
                )
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }

    private func loadHistoricalData() async {
        isLoading = true

        do {
            // Fetch the historical budget plan
            budgetPlan = try await BackendService.shared.fetchBudgetPlan(planId: snapshot.budgetPlanId)

            guard let plan = budgetPlan else {
                isLoading = false
                return
            }

            // Fetch categories that were in this plan
            let allCategories = try await BackendService.shared.fetchBudgetCategories()
            categories = allCategories.filter { plan.categoryIds.contains($0.id) }

            // Calculate actual spending per category for this month
            await calculateCategorySpending()

        } catch {
            print("❌ Error loading historical data: \(error)")
        }

        isLoading = false
    }

    private func calculateCategorySpending() async {
        guard let month = snapshot.month else { return }

        let calendar = Calendar.current
        let transactions = TransactionStorageService.shared.transactions.filter { transaction in
            let txMonth = calendar.component(.month, from: transaction.date)
            let txYear = calendar.component(.year, from: transaction.date)
            return txMonth == month && txYear == snapshot.year
        }

        let allocations = AllocationService.shared.allocations

        for category in categories {
            let categoryAllocations = allocations.filter {
                $0.destinationType == .category && $0.destinationId == category.id
            }

            var spending = 0.0
            for allocation in categoryAllocations {
                if let transaction = transactions.first(where: { $0.id == allocation.transactionId }) {
                    if transaction.isExpense {
                        spending += allocation.amount
                    } else {
                        spending -= allocation.amount
                    }
                }
            }

            categorySpending[category.id] = spending
        }
    }
}

struct CategoryComparisonCard: View {
    let category: BudgetCategory
    let budgeted: Double
    let actual: Double

    private var difference: Double {
        budgeted - actual
    }

    private var percentageUsed: Double {
        guard budgeted > 0 else { return 0 }
        return (actual / budgeted) * 100
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: category.icon)
                    .foregroundColor(.blue)
                Text(category.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(String(format: "%.0f", percentageUsed))% used")
                    .font(.caption)
                    .foregroundColor(percentageUsed > 100 ? .red : .secondary)
            }

            HStack {
                VStack(alignment: .leading) {
                    Text("Budgeted")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("$\(String(format: "%.2f", budgeted))")
                        .font(.subheadline)
                }

                Spacer()

                VStack(alignment: .center) {
                    Text("Actual")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("$\(String(format: "%.2f", actual))")
                        .font(.subheadline)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text(difference >= 0 ? "Remaining" : "Over")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("$\(String(format: "%.2f", abs(difference)))")
                        .font(.subheadline)
                        .foregroundColor(difference >= 0 ? .green : .red)
                }
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                        .cornerRadius(3)

                    Rectangle()
                        .fill(percentageUsed > 100 ? Color.red : Color.blue)
                        .frame(width: min(geometry.size.width, geometry.size.width * (percentageUsed / 100)), height: 6)
                        .cornerRadius(3)
                }
            }
            .frame(height: 6)
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(12)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(valueColor)
        }
    }
}

struct HistoricalBudgetDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            HistoricalBudgetDetailView(
                snapshot: PeriodSnapshot(
                    year: 2025,
                    month: 3,
                    monthlyTakeHome: 5000,
                    totalSpending: 4200,
                    savings: 800,
                    budgetPlanId: "test-plan-id",
                    createdAt: Date(),
                    transactionCount: 42
                )
            )
        }
    }
}
