import SwiftUI

struct GrandSchemeView: View {
    @EnvironmentObject var viewModel: HistoryViewModel
    @StateObject private var transactionService = TransactionStorageService.shared
    @StateObject private var budgetService = BudgetService.shared
    @StateObject private var allocationService = AllocationService.shared
    @State private var selectedTab: GrandSchemeTab = .expenditureOverview

    enum GrandSchemeTab {
        case allTransactions
        case expenditureOverview
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top toolbar with tab buttons
            HStack(spacing: 12) {
                TabButton(
                    title: "All Transactions",
                    isSelected: selectedTab == .allTransactions,
                    action: { selectedTab = .allTransactions }
                )

                TabButton(
                    title: "Expenditures Overview",
                    isSelected: selectedTab == .expenditureOverview,
                    action: { selectedTab = .expenditureOverview }
                )
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))

            Divider()

            // Content based on selected tab
            if selectedTab == .allTransactions {
                AllTransactionsView(
                    transactions: transactionService.transactions,
                    budgetService: budgetService,
                    allocationService: allocationService
                )
            } else {
                ExpenditureOverviewView()
                    .environmentObject(viewModel)
            }
        }
        .navigationTitle("Grand Scheme")
    }
}

// MARK: - Tab Button Component
struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor : Color(.systemGray5))
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - All Transactions View with Pagination
struct AllTransactionsView: View {
    let transactions: [Transaction]
    let budgetService: BudgetService
    let allocationService: AllocationService

    @State private var visibleCount: Int = 20
    private let pageSize = 20

    var sortedTransactions: [Transaction] {
        transactions.sorted { $0.date > $1.date }
    }

    var displayedTransactions: [Transaction] {
        Array(sortedTransactions.prefix(visibleCount))
    }

    var hasMore: Bool {
        visibleCount < sortedTransactions.count
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if sortedTransactions.isEmpty {
                    EmptyTransactionsView()
                        .padding(.top, 60)
                } else {
                    ForEach(displayedTransactions) { transaction in
                        TransactionRowView(
                            transaction: transaction,
                            category: getPrimaryCategoryForTransaction(transaction)
                        )
                        Divider()
                            .padding(.leading, 60)
                    }

                    // Load more indicator
                    if hasMore {
                        Button(action: loadMore) {
                            HStack {
                                Text("Load More")
                                    .font(.subheadline)
                                    .foregroundColor(.accentColor)
                                Image(systemName: "arrow.down.circle")
                                    .foregroundColor(.accentColor)
                            }
                            .padding(.vertical, 16)
                        }
                    }
                }
            }
        }
        .onDisappear {
            // Reset pagination when leaving the view
            visibleCount = pageSize
        }
    }

    private func loadMore() {
        visibleCount = min(visibleCount + pageSize, sortedTransactions.count)
    }

    private func getPrimaryCategoryForTransaction(_ transaction: Transaction) -> BudgetCategory? {
        // Get the first category allocation for this transaction
        let allAllocations = allocationService.allocations
        let categoryAllocations = allAllocations.filter { allocation in
            allocation.transactionId == transaction.id && allocation.destinationType == .category
        }

        if let firstAllocation = categoryAllocations.first {
            return budgetService.getCategoryById(firstAllocation.destinationId)
        }

        return nil
    }
}

// MARK: - Transaction Row Component
struct TransactionRowView: View {
    let transaction: Transaction
    let category: BudgetCategory?

    var body: some View {
        HStack(spacing: 12) {
            // Income/Expense Icon
            ZStack {
                Circle()
                    .fill(transaction.isExpense ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
                    .frame(width: 40, height: 40)

                Image(
                    systemName: transaction.isExpense
                        ? "arrow.down.circle.fill" : "arrow.up.circle.fill"
                )
                .foregroundColor(transaction.isExpense ? .red : .green)
                .font(.system(size: 20))
            }

            VStack(alignment: .leading, spacing: 4) {
                // Title
                Text(transaction.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)

                // Date and Category
                HStack(spacing: 8) {
                    Text(transaction.date, style: .date)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                    if let category = category {
                        HStack(spacing: 4) {
                            Image(systemName: category.icon)
                                .font(.system(size: 11))
                            Text(category.name)
                                .font(.system(size: 13))
                        }
                        .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Amount
            Text(
                transaction.isExpense
                    ? "-$\(transaction.amount, specifier: "%.2f")"
                    : "+$\(transaction.amount, specifier: "%.2f")"
            )
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(transaction.isExpense ? .red : .green)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
}

// MARK: - Empty Transactions View
struct EmptyTransactionsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 64))
                .foregroundColor(.gray)

            Text("No Transactions Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Start tracking your income and expenses")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

// MARK: - Expenditure Overview (Original Grand Scheme View)
struct ExpenditureOverviewView: View {
    @EnvironmentObject var viewModel: HistoryViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Controls
            HStack(spacing: 16) {
                // Period toggle
                Picker("Period", selection: $viewModel.selectedPeriod) {
                    Text("Months").tag(PeriodType.monthly)
                    Text("Years").tag(PeriodType.yearly)
                }
                .pickerStyle(SegmentedPickerStyle())

                // View mode toggle
                Picker("View", selection: $viewModel.selectedViewMode) {
                    Text("Calendar").tag(HistoryViewModel.ViewMode.calendar)
                    Text("Graph").tag(HistoryViewModel.ViewMode.graph)
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            .padding()

            // Content
            if viewModel.displayedSnapshots.isEmpty {
                EmptyHistoryView()
            } else {
                if viewModel.selectedViewMode == .calendar {
                    CalendarView(snapshots: viewModel.displayedSnapshots)
                } else {
                    GraphView(snapshots: viewModel.displayedSnapshots)
                }
            }
        }
    }
}

// MARK: - Empty History View
struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 64))
                .foregroundColor(.gray)

            Text("No History Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Start tracking transactions to see your financial history")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}
