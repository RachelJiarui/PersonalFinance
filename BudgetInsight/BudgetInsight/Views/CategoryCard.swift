import SwiftUI

struct CategoryCard: View {
    let budget: Budget

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                HStack(spacing: 12) {
                    Image(systemName: budget.category.icon)
                        .font(.title3)
                        .foregroundColor(.blue)
                        .frame(width: 36, height: 36)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(budget.category.rawValue)
                            .font(.headline)

                        Text("$\(Int(budget.currentMonthSpent)) of $\(Int(budget.monthlyLimit))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(budget.monthlyPercentage))%")
                        .font(.headline)
                        .foregroundColor(statusColor)

                    Text(budget.monthlyRemaining >= 0 ? "$\(Int(budget.monthlyRemaining)) left" : "$\(Int(abs(budget.monthlyRemaining))) over")
                        .font(.caption)
                        .foregroundColor(budget.monthlyRemaining >= 0 ? .secondary : .red)
                }
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(progressGradient)
                        .frame(width: min(CGFloat(budget.monthlyPercentage / 100) * geometry.size.width, geometry.size.width), height: 8)
                }
            }
            .frame(height: 8)

            HStack(spacing: 16) {
                StatusBadge(
                    label: "Monthly",
                    value: "$\(Int(budget.currentMonthSpent))",
                    total: "$\(Int(budget.monthlyLimit))",
                    color: statusColor
                )

                StatusBadge(
                    label: "Yearly",
                    value: "$\(Int(budget.currentYearSpent))",
                    total: "$\(Int(budget.yearlyLimit))",
                    color: yearlyStatusColor
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private var statusColor: Color {
        switch budget.status {
        case .healthy: return .green
        case .warning: return .orange
        case .exceeded: return .red
        }
    }

    private var yearlyStatusColor: Color {
        if budget.currentYearSpent > budget.yearlyLimit {
            return .red
        } else if budget.yearlyPercentage >= 80 {
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

struct StatusBadge: View {
    let label: String
    let value: String
    let total: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)

                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)

                Text("/ \(total)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}
