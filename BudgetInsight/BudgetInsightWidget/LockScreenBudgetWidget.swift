import SwiftUI
import WidgetKit

/// Lock screen widget showing budget summary
@available(iOS 16.0, *)
struct LockScreenBudgetWidget: View {
    let entry: BudgetWidgetEntry
    @Environment(\.widgetFamily) var widgetFamily

    var body: some View {
        switch widgetFamily {
        case .accessoryCircular:
            CircularLockScreenWidget(entry: entry)
        case .accessoryRectangular:
            RectangularLockScreenWidget(entry: entry)
        case .accessoryInline:
            InlineLockScreenWidget(entry: entry)
        default:
            EmptyView()
        }
    }
}

/// Circular lock screen widget - shows spending percentage with gauge
@available(iOS 16.0, *)
struct CircularLockScreenWidget: View {
    let entry: BudgetWidgetEntry

    private var color: Color {
        switch entry.color {
        case .green: return .green
        case .yellow: return .yellow
        case .red: return .red
        }
    }

    var body: some View {
        if #available(iOS 17.0, *) {
            content
                .containerBackground(for: .widget) {
                    Color.clear
                }
        } else {
            content
        }
    }

    private var content: some View {
        ZStack {
            // Gauge showing spending ratio
            Gauge(value: min(entry.spendingRatio, 1.0)) {
                // Empty label
            }
            .gaugeStyle(.accessoryCircular)
            .tint(color)

            // Percentage in center
            VStack(spacing: 0) {
                Text("\(Int(entry.spendingRatio * 100))")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text("%")
                    .font(.system(size: 10, weight: .medium))
            }
        }
    }
}

/// Rectangular lock screen widget - shows 4 categories with rings (like medium widget)
@available(iOS 16.0, *)
struct RectangularLockScreenWidget: View {
    let entry: BudgetWidgetEntry

    var body: some View {
        if #available(iOS 17.0, *) {
            content
                .containerBackground(for: .widget) {
                    Color.clear
                }
        } else {
            content
        }
    }

    private var content: some View {
        HStack(spacing: 10) {
            // Show up to 4 starred categories with rings
            ForEach(entry.starredCategories.prefix(4)) { category in
                LockScreenCategoryCircle(category: category)
            }

            // Fill with empty circles if less than 4
            ForEach(entry.starredCategories.count..<4, id: \.self) { _ in
                LockScreenEmptyCircle()
            }
        }
    }
}

/// Category circle for lock screen (smaller version)
@available(iOS 16.0, *)
struct LockScreenCategoryCircle: View {
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
                // Background circle (more opaque to be more visible)
                Circle()
                    .stroke(Color.gray.opacity(0.6), lineWidth: 5)
                    .frame(width: 32, height: 32)

                // Progress ring (thicker)
                Circle()
                    .trim(from: 0, to: min(category.spendingRatio, 1.0))
                    .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 32, height: 32)
                    .rotationEffect(.degrees(-90))

                // Icon in center
                Image(systemName: category.icon)
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
            }

            // Percentage under circle (bigger)
            Text("\(Int(category.spendingRatio * 100))%")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
        }
    }
}

/// Empty circle for lock screen
@available(iOS 16.0, *)
struct LockScreenEmptyCircle: View {
    var body: some View {
        VStack(spacing: 2) {
            Circle()
                .stroke(Color.gray.opacity(0.6), lineWidth: 5)
                .frame(width: 32, height: 32)

            Text("")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.clear)
        }
    }
}

/// Inline lock screen widget - shows spending text in header
@available(iOS 16.0, *)
struct InlineLockScreenWidget: View {
    let entry: BudgetWidgetEntry

    var body: some View {
        if let firstCategory = entry.starredCategories.first {
            Text("\(firstCategory.name): $\(Int(firstCategory.spent))/\(Int(firstCategory.budget))")
        } else {
            Text("Budget: $\(Int(entry.totalSpent)) spent")
        }
    }
}
