import SwiftUI

struct EmailSetupView: View {
    @StateObject private var emailService = EmailService.shared
    @State private var isConnecting = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            // Icon
            Image(systemName: "envelope.badge.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            // Title
            Text("Connect Your Email")
                .font(.title)
                .fontWeight(.bold)

            // Description
            VStack(spacing: 12) {
                Text("BudgetInsight monitors your Discover transaction alert emails to help you track spending.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)

                Text("We'll import transaction alerts from:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack {
                    Image(systemName: "envelope.fill")
                        .foregroundColor(.blue)
                    Text("discover@services.discover.com")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            .padding(.horizontal)

            // Instructions
            VStack(alignment: .leading, spacing: 12) {
                InstructionRow(number: 1, text: "Connect your Gmail account")
                InstructionRow(number: 2, text: "We'll monitor for Discover transaction alerts")
                InstructionRow(number: 3, text: "Match alerts with your manual entries")
            }
            .padding()
            .background(Color.blue.opacity(0.05))
            .cornerRadius(12)
            .padding(.horizontal)

            Spacer()

            // Connect Button
            Button(action: connectToGmail) {
                HStack {
                    if isConnecting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "link")
                    }
                    Text(isConnecting ? "Connecting..." : "Connect Gmail")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(isConnecting)
            .padding(.horizontal)

            // Privacy note
            Text("Your email credentials are stored securely. We only read transaction alerts.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()
        }
        .padding()
        .alert("Connection Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    private func connectToGmail() {
        isConnecting = true

        Task {
            do {
                try await emailService.authenticate()
                // Success - EmailService will update isAuthenticated
                await MainActor.run {
                    isConnecting = false
                }
            } catch EmailServiceError.notImplemented {
                await MainActor.run {
                    isConnecting = false
                    errorMessage = "Gmail OAuth is not yet fully implemented. This will open a browser for authentication in the final version."
                    showError = true
                }
            } catch {
                await MainActor.run {
                    isConnecting = false
                    errorMessage = "Failed to connect to Gmail: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
}

struct InstructionRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Number circle
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 28, height: 28)

                Text("\(number)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)

            Spacer()
        }
    }
}

// MARK: - Preview

struct EmailSetupView_Previews: PreviewProvider {
    static var previews: some View {
        EmailSetupView()
    }
}
