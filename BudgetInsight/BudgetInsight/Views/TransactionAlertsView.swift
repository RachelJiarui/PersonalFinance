import SwiftUI

struct TransactionAlertsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = TransactionAlertsViewModel()

    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading alerts...")
                } else if viewModel.alerts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("No Transaction Alerts")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("New Discover card transactions will appear here")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        Section(header: Text("Unresolved Alerts")) {
                            ForEach(viewModel.unresolvedAlerts) { alert in
                                TransactionAlertRow(alert: alert)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            Task {
                                                await viewModel.deleteAlert(alert)
                                            }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }

                        if !viewModel.resolvedAlerts.isEmpty {
                            Section(header: Text("Resolved Alerts")) {
                                ForEach(viewModel.resolvedAlerts) { alert in
                                    TransactionAlertRow(alert: alert)
                                }
                            }
                        }
                    }
                    .refreshable {
                        await viewModel.loadAlerts()
                    }
                }
            }
            .navigationTitle("Transaction Alerts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await viewModel.loadAlerts()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .task {
            await viewModel.loadAlerts()
        }
    }
}

struct TransactionAlertRow: View {
    let alert: TransactionAlert

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(alert.merchant)
                        .font(.headline)

                    Text(alert.transactionDate, style: .date)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if let cardLast4 = alert.cardLast4 {
                        Text("Card •••• \(cardLast4)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("$\(alert.amount, specifier: "%.2f")")
                        .font(.headline)
                        .foregroundColor(.primary)

                    if alert.isResolved {
                        Label("Resolved", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }

            if !alert.isResolved {
                Text("Tap to create transaction")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
    }
}

@MainActor
class TransactionAlertsViewModel: ObservableObject {
    @Published var alerts: [TransactionAlert] = []
    @Published var isLoading = false

    private let backendService = BackendService.shared

    var unresolvedAlerts: [TransactionAlert] {
        alerts.filter { !$0.isResolved }
    }

    var resolvedAlerts: [TransactionAlert] {
        alerts.filter { $0.isResolved }
    }

    func loadAlerts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            self.alerts = try await backendService.fetchTransactionAlerts()
        } catch {
            print("Error loading transaction alerts: \(error)")
        }
    }

    func deleteAlert(_ alert: TransactionAlert) async {
        do {
            try await backendService.deleteTransactionAlert(alertId: alert.id)

            // Remove from local array
            alerts.removeAll { $0.id == alert.id }

        } catch {
            print("Error deleting alert: \(error)")
        }
    }
}
