import SwiftUI

struct DashboardCategoryCard: View {
    let category: BudgetCategory
    let currentSpent: Double
    let monthlyTakeHome: Double

    private var budget: Double {
        category.dollarAmount(monthlyTakeHome: monthlyTakeHome)
    }

    private var spendingRatio: Double {
        category.spendingRatio(currentSpent: currentSpent, monthlyTakeHome: monthlyTakeHome)
    }

    // Calculate time ratio (how far through the month we are)
    private var timeRatio: Double {
        let calendar = Calendar.current
        let now = Date()
        let dayOfMonth = Double(calendar.component(.day, from: now))
        let daysInMonth = Double(calendar.range(of: .day, in: .month, for: now)?.count ?? 30)
        return dayOfMonth / daysInMonth
    }

    // Calculate ring color based on spending vs time progress
    private var ringColor: Color {
        // Round to match displayed percentage (e.g., 0.998 -> 1.0 for "100%")
        let roundedRatio = round(spendingRatio * 100) / 100

        if roundedRatio >= 1.0 {
            return .red  // Over budget
        } else if roundedRatio <= timeRatio {
            return .green  // On track (spending matches or below time progress)
        } else if roundedRatio <= 1.5 * timeRatio {
            return .yellow  // 50% ahead but not over budget
        } else {
            return .red  // Way ahead of schedule
        }
    }

    var body: some View {
        NavigationLink(
            destination: CategoryTransactionsView(category: category)
        ) {
            VStack(spacing: 12) {
                // Category icon and name
                HStack(alignment: .top) {
                    if category.isStarred {
                        Image(systemName: "pin.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }

                    Image(systemName: category.icon)
                        .font(.title3)
                        .foregroundColor(.blue)

                    Text(category.name)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundColor(.primary)

                    Spacer()
                }

                // Circular progress ring
                ZStack {
                    CircularProgressRing(
                        progress: spendingRatio,
                        color: ringColor,
                        lineWidth: 10
                    )
                    .frame(width: 100, height: 100)

                    VStack(spacing: 2) {
                        Text("\(Int(round(spendingRatio * 100)))%")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)

                        Text("spent")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Budget details
                VStack(spacing: 4) {
                    Text("$\(Int(currentSpent)) / $\(Int(budget))")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Text("$\(Int(max(0, budget - currentSpent))) remaining")
                        .font(.caption)
                        .foregroundColor(ringColor)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
