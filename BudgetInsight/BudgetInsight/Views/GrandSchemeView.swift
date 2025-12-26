import SwiftUI

struct GrandSchemeView: View {
    @EnvironmentObject var viewModel: HistoryViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Controls
            HStack(spacing: 16) {
                // Period toggle
                Picker("Period", selection: $viewModel.selectedPeriod) {
                    Text("Months").tag(PeriodType.monthly)
                    Text("Years").tag(PeriodType.yearly)
                }
                .pickerStyle(SegmentedPickerStyle())

                // View mode toggle
                Picker("View", selection: $viewModel.selectedViewMode) {
                    Text("Calendar").tag(HistoryViewModel.ViewMode.calendar)
                    Text("Graph").tag(HistoryViewModel.ViewMode.graph)
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            .padding()

            // Content
            if viewModel.displayedSnapshots.isEmpty {
                EmptyHistoryView()
            } else {
                if viewModel.selectedViewMode == .calendar {
                    CalendarView(snapshots: viewModel.displayedSnapshots)
                } else {
                    GraphView(snapshots: viewModel.displayedSnapshots)
                }
            }
        }
        .navigationTitle("Grand Scheme")
    }
}

struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 64))
                .foregroundColor(.gray)

            Text("No History Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Start tracking transactions to see your financial history")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}
