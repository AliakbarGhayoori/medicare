import SwiftUI

struct SignUpView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    private let isUITesting = ProcessInfo.processInfo.arguments.contains("--uitesting")

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 10) {
                    Image("auth-hero")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 100, maxHeight: 100)
                        .accessibilityHidden(true)

                    Text("MediCare AI")
                        .font(.title2.bold())
                        .foregroundStyle(Color.mcTextPrimary)

                    Text("Create your account to get started.")
                        .font(.callout)
                        .foregroundStyle(Color.mcTextSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 4)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Email")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.mcTextPrimary)
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
                        .accessibilityIdentifier("signup.email")
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Password")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.mcTextPrimary)
                    SecureField("Create a password", text: $password)
                        .textContentType(isUITesting ? .oneTimeCode : .newPassword)
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
                        .accessibilityLabel("Password")
                        .accessibilityIdentifier("signup.password")

                    HStack(spacing: 4) {
                        Image(systemName: password.count >= 8 ? "checkmark.circle.fill" : "circle")
                            .font(.caption)
                            .foregroundStyle(password.count >= 8 ? Color.mcSuccessGreen : Color.mcTextSecondary)
                        Text("Use at least 8 characters.")
                            .font(.caption)
                            .foregroundStyle(Color.mcTextSecondary)
                    }
                    .padding(.top, 2)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Confirm Password")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.mcTextPrimary)
                    SecureField("Re-enter your password", text: $confirmPassword)
                        .textContentType(isUITesting ? .oneTimeCode : .newPassword)
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
                        .accessibilityLabel("Confirm password")
                        .accessibilityIdentifier("signup.confirmPassword")
                }

                if password != confirmPassword && !confirmPassword.isEmpty {
                    Text("Those passwords do not match yet.")
                        .font(.callout)
                        .foregroundStyle(Color.mcEmergencyRed)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    Task {
                        isLoading = true
                        await authViewModel.signUp(email: email, password: password)
                        isLoading = false
                    }
                } label: {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Create account")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.mcAccent)
                .controlSize(.large)
                .disabled(!isFormValid || isLoading)
                .accessibilityHint("Creates a new account")
                .accessibilityIdentifier("signup.submit")

                if let errorMessage = authViewModel.errorMessage {
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundStyle(Color.mcEmergencyRed)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer()
            }
            .padding(16)
        }
        .background(Color.mcBackground)
        .navigationTitle("Create Account")
    }

    private var isFormValid: Bool {
        !email.isEmpty && password.count >= 8 && password == confirmPassword
    }
}
