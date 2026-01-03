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
        VStack(alignment: .leading, spacing: 16) {
            // Categories row with circular progress indicators
            HStack(spacing: 16) {
                ForEach(entry.starredCategories.prefix(4)) { category in
                    CategoryCircle(category: category)
                }

                // Fill remaining space with empty circles if less than 4 categories
                ForEach(entry.starredCategories.count..<4, id: \.self) { _ in
                    EmptyCircle()
                }
            }
            .padding(.horizontal, 20)

            // Percentage display (showing first category's percentage, or overall if none)
            HStack {
                if let firstCategory = entry.starredCategories.first {
                    Text("\(Int(firstCategory.spendingRatio * 100))%")
                        .font(.system(size: 36, weight: .regular, design: .rounded))
                        .foregroundColor(.primary)
                } else {
                    Text("\(Int(entry.spendingRatio * 100))%")
                        .font(.system(size: 36, weight: .regular, design: .rounded))
                        .foregroundColor(.primary)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .padding(.vertical, 16)
    }
}

/// Single category circular progress indicator
struct CategoryCircle: View {
    let category: CategoryWidgetData

    private var color: Color {
        switch category.color {
        case .green: return .green
        case .yellow: return .yellow
        case .red: return .red
        }
    }

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 6)
                .frame(width: 60, height: 60)

            // Progress ring
            Circle()
                .trim(from: 0, to: min(category.spendingRatio, 1.0))
                .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .frame(width: 60, height: 60)
                .rotationEffect(.degrees(-90))

            // Icon in center
            Image(systemName: category.icon)
                .font(.system(size: 20))
                .foregroundColor(.primary)
        }
    }
}

/// Empty circle placeholder
struct EmptyCircle: View {
    var body: some View {
        Circle()
            .stroke(Color.gray.opacity(0.3), lineWidth: 6)
            .frame(width: 60, height: 60)
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
