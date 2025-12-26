import SwiftUI

struct NeedsEntryView: View {
    @StateObject private var storageService = TransactionStorageService.shared
    @State private var showManualEntry = false
    @State private var selectedAlert: TransactionAlert?

    var unlinkedAlerts: [TransactionAlert] {
        storageService.getUnlinkedAlerts().sorted { $0.receivedAt > $1.receivedAt }
    }

    var body: some View {
        NavigationView {
            Group {
                if unlinkedAlerts.isEmpty {
                    // Empty state
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.green)

                        Text("All Caught Up!")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("No transaction alerts need entry")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else {
                    // List of unlinked alerts
                    List {
                        Section {
                            Text("\(unlinkedAlerts.count) transaction\(unlinkedAlerts.count == 1 ? "" : "s") need manual entry")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Section {
                            ForEach(unlinkedAlerts) { alert in
                                AlertRow(alert: alert)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedAlert = alert
                                        showManualEntry = true
                                    }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Needs Entry")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showManualEntry) {
                if let alert = selectedAlert {
                    ManualEntryView(prefilledAlert: alert)
                }
            }
        }
    }
}

struct AlertRow: View {
    let alert: TransactionAlert

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: "envelope.fill")
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40)

            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(alert.merchant)
                    .font(.headline)

                Text(formatDate(alert.date))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Amount
            Text("$\(String(format: "%.2f", alert.amount))")
                .font(.headline)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 4)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Preview

struct NeedsEntryView_Previews: PreviewProvider {
    static var previews: some View {
        NeedsEntryView()
    }
}
