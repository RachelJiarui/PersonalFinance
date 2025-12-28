import SwiftUI

// DEPRECATED: This component is no longer used in favor of DashboardCategoryCard
// Kept for backward compatibility but can be removed in the future

struct CategoryCard: View {
    let category: BudgetCategory
    let currentSpent: Double
    let monthlyBudget: Double

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                HStack(spacing: 12) {
                    Image(systemName: category.icon)
                        .font(.title3)
                        .foregroundColor(.blue)
                        .frame(width: 36, height: 36)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.name)
                            .font(.headline)

                        Text("$\(Int(currentSpent)) of $\(Int(monthlyBudget))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    let percentage = monthlyBudget > 0 ? (currentSpent / monthlyBudget) * 100 : 0
                    Text("\(Int(percentage))%")
                        .font(.headline)
                        .foregroundColor(statusColor)

                    let remaining = monthlyBudget - currentSpent
                    Text(
                        remaining >= 0 ? "$\(Int(remaining)) left" : "$\(Int(abs(remaining))) over"
                    )
                    .font(.caption)
                    .foregroundColor(remaining >= 0 ? .secondary : .red)
                }
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)

                    let percentage = monthlyBudget > 0 ? (currentSpent / monthlyBudget) * 100 : 0
                    RoundedRectangle(cornerRadius: 4)
                        .fill(progressGradient)
                        .frame(
                            width: min(
                                CGFloat(percentage / 100) * geometry.size.width, geometry.size.width
                            ), height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private var statusColor: Color {
        let percentage = monthlyBudget > 0 ? (currentSpent / monthlyBudget) * 100 : 0
        if percentage > 100 {
            return .red
        } else if percentage >= 80 {
            return .orange
        } else {
            return .green
        }
    }

    private var progressGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [statusColor.opacity(0.7), statusColor]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
