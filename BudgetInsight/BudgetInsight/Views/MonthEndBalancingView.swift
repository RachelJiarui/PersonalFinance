import SwiftUI

struct CategoryBalance {
    let category: BudgetCategory
    let budget: Double
    let spent: Double
    var allocated: Double = 0.0

    var surplus: Double {
        return max(0, budget - spent)
    }

    var deficit: Double {
        return max(0, spent - budget)
    }

    var hasBalance: Bool {
        return surplus > 0 || deficit > 0
    }

    var isFullyAllocated: Bool {
        if surplus > 0 {
            return abs(allocated - surplus) < 0.01
        } else if deficit > 0 {
            return abs(allocated - deficit) < 0.01
        }
        return true
    }
}

struct MonthEndBalancingView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var budgetService = BudgetService.shared
    @StateObject private var fundService = FundService.shared
    @StateObject private var debtService = DebtService.shared

    @State private var categoryBalances: [CategoryBalance] = []
    @State private var currentStep: Int = 0
    @State private var isSaving: Bool = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress Indicator
                ProgressView(value: Double(currentStep), total: Double(totalSteps))
                    .padding()

                TabView(selection: $currentStep) {
                    // Step 1: Introduction
                    IntroView()
                        .tag(0)

                    // Step 2: Allocate Savings
                    AllocateSavingsView(categoryBalances: $categoryBalances)
                        .tag(1)

                    // Step 3: Cover Deficits
                    CoverDeficitsView(categoryBalances: $categoryBalances)
                        .tag(2)

                    // Step 4: Summary
                    SummaryView(categoryBalances: $categoryBalances)
                        .tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))

                // Navigation Buttons
                HStack(spacing: 16) {
                    if currentStep > 0 {
                        Button(action: {
                            withAnimation {
                                currentStep -= 1
                            }
                        }) {
                            Text("Back")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray.opacity(0.2))
                                .foregroundColor(.primary)
                                .cornerRadius(10)
                        }
                    }

                    Button(action: nextStep) {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                            Text(currentStep == totalSteps - 1 ? "Complete" : "Next")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canProceed ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(!canProceed || isSaving)
                }
                .padding()
            }
            .navigationTitle("Balance the Books")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
            }
            .onAppear {
                loadCategoryBalances()
            }
        }
    }

    private var totalSteps: Int {
        return 4
    }

    private var canProceed: Bool {
        switch currentStep {
        case 0:
            return true
        case 1:
            // Can proceed if all surpluses are allocated
            let surplusCategories = categoryBalances.filter { $0.surplus > 0 }
            return surplusCategories.allSatisfy { $0.isFullyAllocated }
        case 2:
            // Can proceed if all deficits are covered
            let deficitCategories = categoryBalances.filter { $0.deficit > 0 }
            return deficitCategories.allSatisfy { $0.isFullyAllocated }
        case 3:
            return true
        default:
            return false
        }
    }

    private func nextStep() {
        if currentStep < totalSteps - 1 {
            withAnimation {
                currentStep += 1
            }
        } else {
            // Complete balancing
            completeBalancing()
        }
    }

    private func loadCategoryBalances() {
        guard let monthlyTakeHome = budgetService.userIncome?.monthlyTakeHome else {
            return
        }

        let activeCategories = budgetService.getActiveCategories()
        categoryBalances = activeCategories.compactMap { category in
            let budget = category.dollarAmount(monthlyTakeHome: monthlyTakeHome)
            let spent = budgetService.getSpending(forCategoryId: category.id)

            return CategoryBalance(
                category: category,
                budget: budget,
                spent: spent
            )
        }.filter { $0.hasBalance }
    }

    private func completeBalancing() {
        isSaving = true

        // Save balancing state to UserDefaults
        let calendar = Calendar.current
        let now = Date()
        let month = calendar.component(.month, from: now)
        let year = calendar.component(.year, from: now)
        let key = "balanced_\(year)_\(month)"
        UserDefaults.standard.set(true, forKey: key)

        // In a real implementation, we would create balance transactions here
        // For now, just mark as complete

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isSaving = false
            dismiss()
        }
    }
}

// MARK: - Intro View

struct IntroView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            Text("Time to Balance the Books!")
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 16) {
                BalancingStep(
                    icon: "arrow.down.circle.fill",
                    color: .green,
                    title: "Allocate Savings",
                    description:
                        "Assign any leftover budget to Funds or use it to pay off Debts"
                )

                BalancingStep(
                    icon: "arrow.up.circle.fill",
                    color: .orange,
                    title: "Cover Deficits",
                    description:
                        "If you overspent in any category, choose where to cover the difference"
                )

                BalancingStep(
                    icon: "checkmark.circle.fill",
                    color: .blue,
                    title: "Review & Complete",
                    description: "Confirm your allocations and finish balancing"
                )
            }
            .padding()

            Text("This process ensures every dollar is accounted for and helps you stay on track.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()
        }
        .padding()
    }
}

struct BalancingStep: View {
    let icon: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Allocate Savings View

struct AllocateSavingsView: View {
    @Binding var categoryBalances: [CategoryBalance]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Allocate Savings")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.horizontal)

                Text(
                    "You saved money in these categories. Choose to add them to Funds or pay off Debts."
                )
                .font(.body)
                .foregroundColor(.secondary)
                .padding(.horizontal)

                let surplusCategories = categoryBalances.filter { $0.surplus > 0 }

                if surplusCategories.isEmpty {
                    EmptyBalancingState(
                        icon: "checkmark.circle",
                        message: "No savings this month"
                    )
                } else {
                    ForEach(surplusCategories.indices, id: \.self) { index in
                        if let originalIndex = categoryBalances.firstIndex(where: {
                            $0.category.id == surplusCategories[index].category.id
                        }) {
                            SavingsAllocationCard(
                                balance: $categoryBalances[originalIndex]
                            )
                        }
                    }
                }
            }
            .padding(.vertical)
        }
    }
}

struct SavingsAllocationCard: View {
    @Binding var balance: CategoryBalance
    @StateObject private var fundService = FundService.shared
    @StateObject private var debtService = DebtService.shared

    @State private var selectedDestinationType: AllocationType = .fund
    @State private var selectedDestinationId: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: balance.category.icon)
                    .foregroundColor(.green)
                Text(balance.category.name)
                    .font(.headline)
                Spacer()
                Text("$\(String(format: "%.2f", balance.surplus))")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }

            Picker("Allocate to", selection: $selectedDestinationType) {
                Text("Fund").tag(AllocationType.fund)
                Text("Debt").tag(AllocationType.debt)
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: selectedDestinationType) { _ in
                selectedDestinationId = ""
                balance.allocated = 0.0
            }

            if selectedDestinationType == .fund {
                ForEach(fundService.getActiveFunds()) { fund in
                    Button(action: {
                        selectedDestinationId = fund.id
                        balance.allocated = balance.surplus
                    }) {
                        HStack {
                            Image(systemName: fund.icon)
                                .foregroundColor(.green)
                            Text(fund.name)
                            Spacer()
                            if selectedDestinationId == fund.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .foregroundColor(.primary)
                }
            } else {
                ForEach(debtService.getActiveDebts()) { debt in
                    Button(action: {
                        selectedDestinationId = debt.id
                        balance.allocated = balance.surplus
                    }) {
                        HStack {
                            Image(systemName: debt.icon)
                                .foregroundColor(.orange)
                            Text(debt.name)
                            Spacer()
                            if selectedDestinationId == debt.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .foregroundColor(.primary)
                }
            }

            if balance.isFullyAllocated {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Fully Allocated")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

// MARK: - Cover Deficits View

struct CoverDeficitsView: View {
    @Binding var categoryBalances: [CategoryBalance]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Cover Deficits")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.horizontal)

                Text(
                    "You overspent in these categories. Cover the difference from Funds or create/add to Debt."
                )
                .font(.body)
                .foregroundColor(.secondary)
                .padding(.horizontal)

                let deficitCategories = categoryBalances.filter { $0.deficit > 0 }

                if deficitCategories.isEmpty {
                    EmptyBalancingState(
                        icon: "checkmark.circle",
                        message: "No overspending this month"
                    )
                } else {
                    ForEach(deficitCategories.indices, id: \.self) { index in
                        if let originalIndex = categoryBalances.firstIndex(where: {
                            $0.category.id == deficitCategories[index].category.id
                        }) {
                            DeficitAllocationCard(
                                balance: $categoryBalances[originalIndex]
                            )
                        }
                    }
                }
            }
            .padding(.vertical)
        }
    }
}

struct DeficitAllocationCard: View {
    @Binding var balance: CategoryBalance
    @StateObject private var fundService = FundService.shared
    @StateObject private var debtService = DebtService.shared

    @State private var selectedDestinationType: AllocationType = .fund
    @State private var selectedDestinationId: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: balance.category.icon)
                    .foregroundColor(.orange)
                Text(balance.category.name)
                    .font(.headline)
                Spacer()
                Text("$\(String(format: "%.2f", balance.deficit))")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
            }

            Picker("Cover from", selection: $selectedDestinationType) {
                Text("Fund").tag(AllocationType.fund)
                Text("Debt").tag(AllocationType.debt)
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: selectedDestinationType) { _ in
                selectedDestinationId = ""
                balance.allocated = 0.0
            }

            if selectedDestinationType == .fund {
                Text("Withdraw from Fund:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                ForEach(fundService.getActiveFunds()) { fund in
                    Button(action: {
                        selectedDestinationId = fund.id
                        balance.allocated = balance.deficit
                    }) {
                        HStack {
                            Image(systemName: fund.icon)
                                .foregroundColor(.green)
                            VStack(alignment: .leading) {
                                Text(fund.name)
                                Text("Balance: $\(String(format: "%.2f", fund.balance))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if selectedDestinationId == fund.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .foregroundColor(.primary)
                }
            } else {
                Text("Add to Debt:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                ForEach(debtService.getActiveDebts()) { debt in
                    Button(action: {
                        selectedDestinationId = debt.id
                        balance.allocated = balance.deficit
                    }) {
                        HStack {
                            Image(systemName: debt.icon)
                                .foregroundColor(.orange)
                            Text(debt.name)
                            Spacer()
                            if selectedDestinationId == debt.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .foregroundColor(.primary)
                }
            }

            if balance.isFullyAllocated {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Fully Covered")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

// MARK: - Summary View

struct SummaryView: View {
    @Binding var categoryBalances: [CategoryBalance]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Summary")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.horizontal)

                Text("Review your allocations before completing the balancing process.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                let surplusCategories = categoryBalances.filter { $0.surplus > 0 }
                let deficitCategories = categoryBalances.filter { $0.deficit > 0 }

                if !surplusCategories.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Savings Allocated")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(surplusCategories, id: \.category.id) { balance in
                            HStack {
                                Image(systemName: balance.category.icon)
                                    .foregroundColor(.green)
                                Text(balance.category.name)
                                Spacer()
                                Text("$\(String(format: "%.2f", balance.surplus))")
                                    .foregroundColor(.green)
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                            .padding(.horizontal)
                        }
                    }
                }

                if !deficitCategories.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Deficits Covered")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(deficitCategories, id: \.category.id) { balance in
                            HStack {
                                Image(systemName: balance.category.icon)
                                    .foregroundColor(.orange)
                                Text(balance.category.name)
                                Spacer()
                                Text("$\(String(format: "%.2f", balance.deficit))")
                                    .foregroundColor(.orange)
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                            .padding(.horizontal)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("All balances accounted for")
                            .font(.headline)
                            .foregroundColor(.green)
                    }
                    .padding()
                }
                .frame(maxWidth: .infinity)

                Spacer()
            }
            .padding(.vertical)
        }
    }
}

struct EmptyBalancingState: View {
    let icon: String
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.green)

            Text(message)
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Preview

struct MonthEndBalancingView_Previews: PreviewProvider {
    static var previews: some View {
        MonthEndBalancingView()
    }
}
