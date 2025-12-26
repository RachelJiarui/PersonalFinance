import SwiftUI

struct CircularProgressRing: View {
    let progress: Double  // 0.0 to 1.0+
    let color: Color
    let lineWidth: CGFloat

    init(progress: Double, color: Color, lineWidth: CGFloat = 12) {
        self.progress = progress
        self.color = color
        self.lineWidth = lineWidth
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: lineWidth)

            // Progress ring
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progress)
        }
    }
}
