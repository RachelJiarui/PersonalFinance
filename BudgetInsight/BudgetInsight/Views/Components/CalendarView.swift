import SwiftUI

struct CalendarView: View {
    let snapshots: [PeriodSnapshot]

    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 150))
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(snapshots) { snapshot in
                    CalendarCell(snapshot: snapshot)
                }
            }
            .padding()
        }
    }
}

struct CalendarCell: View {
    let snapshot: PeriodSnapshot

    private var cellColor: Color {
        let status = snapshot.colorStatus(takeHome: snapshot.monthlyTakeHome)
        switch status {
        case .green: return .green
        case .yellow: return .yellow
        case .red: return .red
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            Text(snapshot.displayName)
                .font(.headline)
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Text("$\(Int(snapshot.savings))")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text(snapshot.savings >= 0 ? "saved" : "over")
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(height: 100)
        .frame(maxWidth: .infinity)
        .background(cellColor)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}
