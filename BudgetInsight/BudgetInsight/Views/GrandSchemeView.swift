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
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Tab buttons
                HStack(spacing: 12) {
                    TabButton(
                        title: "All Transactions",
                        isSelected: selectedTab == .allTransactions,
                        action: { selectedTab = .allTransactions }
                    )

                    TabButton(
                        title: "Historical Data",
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
        }
        .navigationTitle("Grand Scheme")
        .navigationBarTitleDisplayMode(.inline)
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
                        NavigationLink(
                            destination: TransactionDetailView(
                                transaction: transaction,
                                budgetService: budgetService,
                                allocationService: allocationService
                            )
                        ) {
                            TransactionRowView(
                                transaction: transaction,
                                budgetService: budgetService,
                                allocationService: allocationService
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
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

// MARK: - Transaction Detail View
struct TransactionDetailView: View {
    let transaction: Transaction
    let budgetService: BudgetService
    let allocationService: AllocationService

    @StateObject private var fundService = FundService.shared
    @StateObject private var debtService = DebtService.shared
    @StateObject private var transactionService = TransactionStorageService.shared
    @StateObject private var backendService = BackendService.shared
    @StateObject private var alertService = TransactionAlertService.shared
    @State private var showEditSheet: Bool = false
    @State private var showDeleteConfirmation: Bool = false
    @State private var isDeleting: Bool = false
    @Environment(\.dismiss) var dismiss

    var allocations: [TransactionAllocation] {
        allocationService.allocations.filter { $0.transactionId == transaction.id }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Transaction Summary Card
                VStack(spacing: 16) {
                    // Amount
                    Text(
                        transaction.isExpense
                            ? "-$\(transaction.amount, specifier: "%.2f")"
                            : "+$\(transaction.amount, specifier: "%.2f")"
                    )
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(transaction.isExpense ? .red : .green)

                    // Title
                    Text(transaction.title)
                        .font(.title2)
                        .fontWeight(.semibold)

                    // Date
                    Text(transaction.date, style: .date)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    // Type badge
                    Text(transaction.isExpense ? "Expense" : "Income")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(transaction.isExpense ? Color.red : Color.green)
                        )
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray6))
                )
                .padding(.horizontal)

                // Allocations Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Allocation Breakdown")
                        .font(.headline)
                        .padding(.horizontal)

                    if allocations.isEmpty {
                        Text("No allocations for this transaction")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ForEach(allocations) { allocation in
                            AllocationDetailRow(
                                allocation: allocation,
                                budgetService: budgetService,
                                fundService: fundService,
                                debtService: debtService
                            )
                        }
                    }
                }
                .padding(.bottom)

                // Delete Button
                Button(
                    role: .destructive,
                    action: {
                        showDeleteConfirmation = true
                    }
                ) {
                    HStack {
                        Spacer()
                        Image(systemName: "trash")
                        Text("Delete Transaction")
                        Spacer()
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .padding(.vertical)
        }
        .navigationTitle("Transaction Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showEditSheet = true
                }) {
                    Text("Edit")
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            EditTransactionView(
                originalTransaction: transaction,
                originalAllocations: allocations
            )
        }
        .alert("Delete Transaction", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteTransaction()
            }
        } message: {
            Text(
                "Are you sure you want to delete '\(transaction.title)' for $\(String(format: "%.2f", transaction.amount))? This cannot be undone."
            )
        }
    }

    private func deleteTransaction() {
        isDeleting = true

        Task {
            do {
                // Delete from Firestore first
                try await backendService.deleteTransaction(transaction.id)

                // Unlink from transaction alert if linked
                if let alertId = transaction.transactionAlertId {
                    try await alertService.unlinkTransactionFromAlert(alertId: alertId)
                    print("✅ [TransactionDetail] Unlinked transaction from alert: \(alertId)")
                }

                await MainActor.run {
                    // Delete allocations
                    for allocation in allocations {
                        allocationService.deleteAllocation(allocationId: allocation.id)
                    }

                    // Delete transaction from local storage
                    transactionService.deleteTransaction(id: transaction.id)

                    print(
                        "✅ [TransactionDetail] Deleted transaction from Firestore and local: \(transaction.title)"
                    )

                    isDeleting = false
                    // Dismiss the detail view
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    print("❌ [TransactionDetail] Failed to delete from Firestore: \(error)")
                    // Still delete locally even if Firestore fails
                    for allocation in allocations {
                        allocationService.deleteAllocation(allocationId: allocation.id)
                    }
                    transactionService.deleteTransaction(id: transaction.id)

                    // Try to unlink alert even on error
                    if let alertId = transaction.transactionAlertId {
                        Task {
                            try? await alertService.unlinkTransactionFromAlert(alertId: alertId)
                        }
                    }

                    isDeleting = false
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Allocation Detail Row
struct AllocationDetailRow: View {
    let allocation: TransactionAllocation
    let budgetService: BudgetService
    let fundService: FundService
    let debtService: DebtService

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: destinationIcon)
                .font(.title2)
                .foregroundColor(destinationColor)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(destinationName)
                    .font(.system(size: 16, weight: .medium))

                Text(allocation.destinationType.rawValue.capitalized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("$\(allocation.amount, specifier: "%.2f")")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .padding(.horizontal)
    }

    private var destinationName: String {
        switch allocation.destinationType {
        case .category:
            return budgetService.getCategoryById(allocation.destinationId)?.name
                ?? "Unknown Category"
        case .fund:
            // Access all funds directly (includes inactive)
            return fundService.funds.first(where: { $0.id == allocation.destinationId })?.name
                ?? "Unknown Fund"
        case .debt:
            // Access all debts directly (includes inactive)
            return debtService.debts.first(where: { $0.id == allocation.destinationId })?.name
                ?? "Unknown Debt"
        }
    }

    private var destinationIcon: String {
        switch allocation.destinationType {
        case .category:
            return budgetService.getCategoryById(allocation.destinationId)?.icon
                ?? "questionmark.circle"
        case .fund:
            // Access all funds directly (includes inactive)
            return fundService.funds.first(where: { $0.id == allocation.destinationId })?.icon
                ?? "dollarsign.circle"
        case .debt:
            // Access all debts directly (includes inactive)
            return debtService.debts.first(where: { $0.id == allocation.destinationId })?.icon
                ?? "creditcard"
        }
    }

    private var destinationColor: Color {
        switch allocation.destinationType {
        case .category:
            return .blue
        case .fund:
            return .green
        case .debt:
            return .orange
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
