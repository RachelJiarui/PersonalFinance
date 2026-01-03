import SwiftUI
import WidgetKit

/// Small square widget showing total monthly spending
struct SmallBudgetWidget: View {
    let entry: BudgetWidgetEntry

    private var percentText: String {
        "\(Int(entry.spendingRatio * 100))%"
    }

    private var spentText: String {
        "$\(Int(entry.totalSpent))"
    }

    private var color: Color {
        switch entry.color {
        case .green: return .green
        case .yellow: return .yellow
        case .red: return .red
        }
    }

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
        VStack(spacing: 8) {
            // Percent in top right
            HStack {
                Spacer()
                Text(percentText)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(color)
                    .padding(.trailing, 12)
                    .padding(.top, 12)
            }

            Spacer()

            // Main spending amount
            Text(spentText)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            // Subtitle
            Text("spent this month")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()
        }
    }
}

struct SmallBudgetWidget_Previews: PreviewProvider {
    static var previews: some View {
        SmallBudgetWidget(
            entry: BudgetWidgetEntry(
                date: Date(),
                totalSpent: 1234.56,
                totalBudget: 3000.00,
                spendingRatio: 0.41,
                color: .green,
                starredCategories: []
            )
        )
        .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
