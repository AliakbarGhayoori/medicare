import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        Image(systemName: "stethoscope")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.mcAccent)
                            .padding(.top, 32)

                        Text("MediCare AI")
                            .font(.largeTitle)
                            .bold()
                            .foregroundStyle(Color.mcTextPrimary)

                        Text("Clear, reliable health information in plain language.")
                            .font(.body)
                            .foregroundStyle(Color.mcTextSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 8)

                    VStack(spacing: 16) {
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
                                .accessibilityIdentifier("login.email")
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Password")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(Color.mcTextPrimary)
                            SecureField("Enter your password", text: $password)
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
                                .accessibilityIdentifier("login.password")
                        }
                    }

                    Button {
                        Task {
                            isLoading = true
                            await authViewModel.signIn(email: email, password: password)
                            isLoading = false
                        }
                    } label: {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Log In")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.mcAccent)
                    .controlSize(.large)
                    .disabled(email.isEmpty || password.isEmpty || isLoading)
                    .accessibilityHint("Signs you in to your account")
                    .accessibilityIdentifier("login.submit")

                    VStack(spacing: 12) {
                        NavigationLink("Forgot password?", destination: ForgotPasswordView())
                            .font(.callout)
                            .foregroundStyle(Color.mcAccent)
                            .accessibilityIdentifier("login.forgotPassword")

                        NavigationLink("Create an account", destination: SignUpView())
                            .font(.callout)
                            .foregroundStyle(Color.mcAccent)
                            .accessibilityIdentifier("login.createAccount")
                    }

                    if let errorMessage = authViewModel.errorMessage {
                        Text(errorMessage)
                            .font(.callout)
                            .foregroundStyle(Color.mcEmergencyRed)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(16)
            }
            .background(Color.mcBackground)
            .navigationTitle("Login")
        }
    }
}
