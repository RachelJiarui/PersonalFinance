import SwiftUI

struct BackendRegistrationView: View {
    @StateObject private var backendService = BackendService.shared
    @State private var email: String = ""
    @State private var isRegistering: Bool = false
    @State private var errorMessage: String?
    @State private var showSuccess: Bool = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            Image(systemName: "server.rack")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            // Title
            Text("Connect to Backend")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Register your account to enable cloud sync and push notifications")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            // Email Input
            VStack(alignment: .leading, spacing: 8) {
                Text("Email Address")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                TextField("your.email@example.com", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .disabled(isRegistering)
            }
            .padding(.horizontal)

            // Error Message
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }

            // Register Button
            Button(action: register) {
                HStack {
                    if isRegistering {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Register")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(email.isEmpty || isRegistering || !isValidEmail(email))
            .padding(.horizontal)

            // Skip Button
            Button(action: skipRegistration) {
                Text("Skip for Now")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)

            Spacer()

            // Info Text
            Text("Backend syncs your budget and transactions across devices")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.bottom)
        }
        .alert("Registration Successful", isPresented: $showSuccess) {
            Button("Continue") {
                // Handled by BackendService.isRegistered
            }
        } message: {
            Text("Your account has been created and connected to the backend server.")
        }
    }

    private func register() {
        isRegistering = true
        errorMessage = nil

        Task {
            do {
                let userId = try await backendService.registerUser(email: email)

                await MainActor.run {
                    isRegistering = false
                    showSuccess = true
                    print("✅ Registered with backend, user ID: \(userId)")
                }
            } catch {
                await MainActor.run {
                    isRegistering = false
                    errorMessage = error.localizedDescription
                    print("❌ Registration failed: \(error)")
                }
            }
        }
    }

    private func skipRegistration() {
        // Set a flag to skip registration for now
        UserDefaults.standard.set(true, forKey: "backend_registration_skipped")
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
}

#Preview {
    BackendRegistrationView()
}
