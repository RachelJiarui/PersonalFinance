import SwiftUI

struct CategoryTransactionsView: View {
    let category: BudgetCategory

    @StateObject private var transactionService = TransactionStorageService.shared
    @StateObject private var budgetService = BudgetService.shared
    @StateObject private var allocationService = AllocationService.shared

    @State private var visibleCount: Int = 20
    private let pageSize = 20

    // Get all transactions that have allocations to this category
    var categoryTransactions: [Transaction] {
        let categoryAllocations = allocationService.allocations.filter {
            $0.destinationType == .category && $0.destinationId == category.id
        }

        let transactionIds = Set(categoryAllocations.map { $0.transactionId })

        return transactionService.transactions.filter {
            transactionIds.contains($0.id)
        }
    }

    var sortedTransactions: [Transaction] {
        categoryTransactions.sorted { $0.date > $1.date }
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
                    EmptyCategoryTransactionsView(categoryName: category.name)
                        .padding(.top, 60)
                } else {
                    // Summary header
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: category.icon)
                                .font(.title2)
                                .foregroundColor(.blue)

                            Text(category.name)
                                .font(.title2)
                                .fontWeight(.semibold)

                            Spacer()
                        }

                        HStack {
                            Text(
                                "\(sortedTransactions.count) transaction\(sortedTransactions.count == 1 ? "" : "s")"
                            )
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                            Spacer()
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))

                    Divider()

                    // Transactions list
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
        .navigationTitle("Category Transactions")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            // Reset pagination when leaving the view
            visibleCount = pageSize
        }
    }

    private func loadMore() {
        visibleCount = min(visibleCount + pageSize, sortedTransactions.count)
    }
}

// MARK: - Empty State View
struct EmptyCategoryTransactionsView: View {
    let categoryName: String

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 64))
                .foregroundColor(.gray)

            Text("No Transactions Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("No transactions have been allocated to \(categoryName)")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}
