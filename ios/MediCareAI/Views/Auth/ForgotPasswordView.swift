import SwiftUI

struct ForgotPasswordView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel

    @State private var email = ""
    @State private var didSend = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Enter the email linked to your account and we will send a reset link.")
                .font(.callout)
                .foregroundStyle(Color.mcTextSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            TextField("you@example.com", text: $email)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.emailAddress)
                .font(.body)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.mcInputBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.mcInputBorder, lineWidth: 1)
                )
                .accessibilityLabel("Email")
                .accessibilityIdentifier("forgot.email")

            Button("Email Me a Reset Link") {
                Task {
                    await authViewModel.resetPassword(email: email)
                    if authViewModel.errorMessage == nil {
                        didSend = true
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.mcAccent)
            .controlSize(.large)
            .disabled(email.isEmpty)
            .accessibilityHint("Sends a password reset email")
            .accessibilityIdentifier("forgot.submit")

            if didSend {
                Text("Reset link sent. Check your inbox.")
                    .font(.callout)
                    .foregroundStyle(Color.mcSuccessGreen)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let errorMessage = authViewModel.errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(Color.mcEmergencyRed)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()
        }
        .padding(16)
        .background(Color.mcBackground)
        .navigationTitle("Reset Password")
    }
}
