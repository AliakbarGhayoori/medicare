import SwiftUI

struct SignUpView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel

    @State private var firstName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false

    private var passwordLongEnough: Bool { password.count >= 8 }
    private var passwordsMatch: Bool { password == confirmPassword }

    private var isFormValid: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty && passwordLongEnough && passwordsMatch
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                AuthHeader(
                    title: "Create your account",
                    subtitle: "It takes a minute. Your chats and health profile stay private to you.",
                    showsMark: false
                )
                .padding(.top, 8)

                FormField(label: "What should we call you?", note: "Optional. We use it to greet you.") {
                    TextField("First name", text: $firstName)
                        .textContentType(.givenName)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .accessibilityLabel("What should we call you? Optional")
                        .accessibilityIdentifier("signup.firstName")
                }

                FormField(label: "Email") {
                    TextField(AuthCopy.emailExample, text: $email)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                        .textContentType(UITesting.isActive ? nil : .username)
                        .accessibilityLabel("Email")
                        .accessibilityIdentifier("signup.email")
                }

                VStack(alignment: .leading, spacing: 6) {
                    FormField(label: "Password") {
                        SecureField("Choose a password", text: $password)
                            .textContentType(UITesting.isActive ? .oneTimeCode : .newPassword)
                            .accessibilityLabel("Password")
                            .accessibilityIdentifier("signup.password")
                    }
                    Label {
                        Text("At least 8 characters")
                    } icon: {
                        Image(systemName: passwordLongEnough ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(passwordLongEnough ? Color.mcGreen : Color.mcInk2)
                    }
                    .font(.footnote)
                    .foregroundStyle(Color.mcInk2)
                    .accessibilityLabel(passwordLongEnough ? "Password is long enough" : "Use at least 8 characters")
                }

                FormField(label: "Type the password again") {
                    SecureField("Same password", text: $confirmPassword)
                        .textContentType(UITesting.isActive ? .oneTimeCode : .newPassword)
                        .accessibilityLabel("Confirm password")
                        .accessibilityIdentifier("signup.confirmPassword")
                }

                if !confirmPassword.isEmpty && !passwordsMatch {
                    FormMessage(text: "The two passwords are not the same yet.")
                }

                if let error = authViewModel.errorMessage {
                    FormMessage(text: error)
                }

                Button {
                    Task {
                        isLoading = true
                        await authViewModel.signUp(
                            email: email.trimmingCharacters(in: .whitespaces),
                            password: password,
                            firstName: firstName
                        )
                        isLoading = false
                    }
                } label: {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Create account")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!isFormValid || isLoading)
                .accessibilityHint("Creates your account")
                .accessibilityIdentifier("signup.submit")

                Text("By creating an account you agree to the [terms of use](https://mediguide.co/terms) and the [privacy policy](https://mediguide.co/privacy).")
                    .font(.footnote)
                    .foregroundStyle(Color.mcInk2)
                    .tint(Color.mcBlueText)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .mcScreenBackground()
        .accessibilityIdentifier("screen.signup")
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            authViewModel.errorMessage = nil
        }
    }
}
