import SwiftUI

struct GraphView: View {
    let snapshots: [PeriodSnapshot]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Extra Money Saved")
                    .font(.headline)
                    .padding(.horizontal)

                // Simple line chart
                SimpleLineChart(snapshots: snapshots)
                    .frame(height: 300)
                    .padding()

                // Data table
                ForEach(snapshots) { snapshot in
                    HStack {
                        Text(snapshot.displayName)
                            .font(.subheadline)

                        Spacer()

                        VStack(alignment: .trailing) {
                            Text("$\(Int(snapshot.savings))")
                                .font(.headline)
                                .foregroundColor(snapshot.savings >= 0 ? .green : .red)

                            Text("\(snapshot.transactionCount) transactions")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
            }
        }
    }
}

struct SimpleLineChart: View {
    let snapshots: [PeriodSnapshot]

    var body: some View {
        GeometryReader { geometry in
            let sortedSnapshots = snapshots.sorted { (s1, s2) in
                if s1.year != s2.year {
                    return s1.year < s2.year
                }
                return (s1.month ?? 0) < (s2.month ?? 0)
            }

            let maxSavings = sortedSnapshots.map { $0.savings }.max() ?? 1000
            let minSavings = sortedSnapshots.map { $0.savings }.min() ?? 0
            let range = max(maxSavings - minSavings, 100)  // Avoid division by zero

            ZStack {
                // Grid lines
                ForEach(0..<5) { i in
                    let y = geometry.size.height * CGFloat(i) / 4
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    }
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                }

                // Line chart
                if sortedSnapshots.count > 0 {
                    Path { path in
                        for (index, snapshot) in sortedSnapshots.enumerated() {
                            let x = geometry.size.width * CGFloat(index) / CGFloat(max(sortedSnapshots.count - 1, 1))
                            let normalizedY = (snapshot.savings - minSavings) / range
                            let y = geometry.size.height * (1 - normalizedY)

                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(Color.blue, lineWidth: 2)

                    // Data points
                    ForEach(Array(sortedSnapshots.enumerated()), id: \.element.id) { index, snapshot in
                        let x = geometry.size.width * CGFloat(index) / CGFloat(max(sortedSnapshots.count - 1, 1))
                        let normalizedY = (snapshot.savings - minSavings) / range
                        let y = geometry.size.height * (1 - normalizedY)

                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                            .position(x: x, y: y)
                    }
                }
            }
        }
    }
}
