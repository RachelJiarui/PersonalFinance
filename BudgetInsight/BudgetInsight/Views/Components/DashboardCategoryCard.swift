import SwiftUI

struct DashboardCategoryCard: View {
    let category: BudgetCategory
    let monthlyTakeHome: Double

    private var budget: Double {
        category.dollarAmount(monthlyTakeHome: monthlyTakeHome)
    }

    private var spendingRatio: Double {
        category.spendingRatio(monthlyTakeHome: monthlyTakeHome)
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
        if spendingRatio >= 1.0 {
            return .red  // Over budget
        } else if spendingRatio <= timeRatio {
            return .green  // On track (spending matches or below time progress)
        } else if spendingRatio <= 1.5 * timeRatio {
            return .yellow  // 50% ahead but not over budget
        } else {
            return .red  // Way ahead of schedule
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            // Category icon and name
            HStack {
                Image(systemName: category.icon)
                    .font(.title3)
                    .foregroundColor(.blue)

                Text(category.name)
                    .font(.headline)
                    .lineLimit(1)

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
                    Text("\(Int(spendingRatio * 100))%")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("spent")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Budget details
            VStack(spacing: 4) {
                Text("$\(Int(category.currentMonthSpent)) / $\(Int(budget))")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("$\(Int(max(0, budget - category.currentMonthSpent))) remaining")
                    .font(.caption)
                    .foregroundColor(ringColor)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}
