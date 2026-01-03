import SwiftUI
import WidgetKit

/// Medium horizontal widget showing up to 4 starred categories (mimics Apple Battery widget)
struct MediumBudgetWidget: View {
    let entry: BudgetWidgetEntry

    var body: some View {
        if #available(iOS 17.0, *) {
            contentView
                .containerBackground(.fill.tertiary, for: .widget)
        } else {
            ZStack {
                Color(.systemBackground)
                contentView
            }
        }
    }

    private var contentView: some View {
        HStack(spacing: 12) {
            ForEach(entry.starredCategories.prefix(4)) { category in
                CategoryCircleWithLabel(category: category)
            }

            // Fill remaining space with empty circles if less than 4 categories
            ForEach(entry.starredCategories.count..<4, id: \.self) { _ in
                EmptyCircleWithLabel()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
}

/// Category circle with percentage label
struct CategoryCircleWithLabel: View {
    let category: CategoryWidgetData

    private var color: Color {
        switch category.color {
        case .green: return .green
        case .yellow: return .yellow
        case .red: return .red
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 7)
                    .frame(width: 70, height: 70)

                // Progress ring
                Circle()
                    .trim(from: 0, to: min(category.spendingRatio, 1.0))
                    .stroke(color, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .frame(width: 70, height: 70)
                    .rotationEffect(.degrees(-90))

                // Icon in center
                Image(systemName: category.icon)
                    .font(.system(size: 24))
                    .foregroundColor(.primary)
            }

            // Percentage under circle
            Text("\(Int(category.spendingRatio * 100))%")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
        }
    }
}

/// Empty circle with label placeholder
struct EmptyCircleWithLabel: View {
    var body: some View {
        VStack(spacing: 6) {
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 7)
                .frame(width: 70, height: 70)

            Text("")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.clear)
        }
    }
}

struct MediumBudgetWidget_Previews: PreviewProvider {
    static var previews: some View {
        MediumBudgetWidget(
            entry: BudgetWidgetEntry(
                date: Date(),
                totalSpent: 1234.56,
                totalBudget: 3000.00,
                spendingRatio: 0.41,
                color: .green,
                starredCategories: [
                    CategoryWidgetData(
                        id: "1",
                        name: "Groceries",
                        icon: "cart.fill",
                        spent: 345.67,
                        budget: 800.00,
                        spendingRatio: 0.43,
                        color: .green
                    ),
                    CategoryWidgetData(
                        id: "2",
                        name: "Transport",
                        icon: "car.fill",
                        spent: 123.45,
                        budget: 400.00,
                        spendingRatio: 0.31,
                        color: .green
                    ),
                    CategoryWidgetData(
                        id: "3",
                        name: "Entertainment",
                        icon: "tv.fill",
                        spent: 89.12,
                        budget: 300.00,
                        spendingRatio: 0.30,
                        color: .green
                    ),
                ]
            )
        )
        .previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}
