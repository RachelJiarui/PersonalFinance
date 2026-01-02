import Combine
import Foundation

@MainActor
class HistoryViewModel: ObservableObject {
    @Published var monthlySnapshots: [PeriodSnapshot] = []
    @Published var yearlySnapshots: [PeriodSnapshot] = []
    @Published var selectedPeriod: PeriodType = .monthly
    @Published var selectedViewMode: ViewMode = .calendar

    // Navigation state for historical budget detail view
    @Published var selectedSnapshot: PeriodSnapshot?
    @Published var showHistoricalDetail = false

    enum ViewMode {
        case calendar
        case graph
    }

    private let snapshotService = SnapshotService.shared
    private let budgetService = BudgetService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        setupSubscriptions()
    }

    private func setupSubscriptions() {
        snapshotService.$monthlySnapshots
            .assign(to: &$monthlySnapshots)

        snapshotService.$yearlySnapshots
            .assign(to: &$yearlySnapshots)
    }

    var displayedSnapshots: [PeriodSnapshot] {
        switch selectedPeriod {
        case .monthly:
            return monthlySnapshots.sorted { ($0.year, $0.month ?? 0) > ($1.year, $1.month ?? 0) }
        case .yearly:
            return yearlySnapshots.sorted { $0.year > $1.year }
        }
    }

    func togglePeriod() {
        selectedPeriod = selectedPeriod == .monthly ? .yearly : .monthly
    }

    func toggleViewMode() {
        selectedViewMode = selectedViewMode == .calendar ? .graph : .calendar
    }

    func selectSnapshot(_ snapshot: PeriodSnapshot) {
        selectedSnapshot = snapshot
        showHistoricalDetail = true
    }
}
