import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @FocusState private var focus: Field?

    private enum Field { case email, password }

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty && !isLoading
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    AuthHeader(
                        title: "MediCare AI",
                        subtitle: "Clear answers to your health questions, with the trusted sources named."
                    )
                    .padding(.top, 36)
                    .padding(.bottom, 8)

                    FormField(label: "Email") {
                        TextField(AuthCopy.emailExample, text: $email)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.emailAddress)
                            .textContentType(UITesting.isActive ? nil : .username)
                            .focused($focus, equals: .email)
                            .submitLabel(.next)
                            .onSubmit { focus = .password }
                            .accessibilityLabel("Email")
                            .accessibilityIdentifier("login.email")
                    }

                    FormField(label: "Password") {
                        SecureField("Your password", text: $password)
                            .textContentType(UITesting.isActive ? .oneTimeCode : .password)
                            .focused($focus, equals: .password)
                            .submitLabel(.go)
                            .onSubmit(signIn)
                            .accessibilityLabel("Password")
                            .accessibilityIdentifier("login.password")
                    }

                    if let error = authViewModel.errorMessage {
                        FormMessage(text: error)
                    }

                    Button(action: signIn) {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Sign in")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!canSubmit)
                    .accessibilityHint("Signs you in to your account")
                    .accessibilityIdentifier("login.submit")

                    NavigationLink {
                        ForgotPasswordView()
                    } label: {
                        Text("Forgot your password?")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.mcBlueText)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .accessibilityIdentifier("login.forgotPassword")

                    VStack(spacing: 10) {
                        Text("New to MediCare AI?")
                            .font(.subheadline)
                            .foregroundStyle(Color.mcInk2)
                        NavigationLink {
                            SignUpView()
                        } label: {
                            Text("Create an account")
                        }
                        .buttonStyle(SecondaryButtonStyle(tint: .mcBlueText))
                        .accessibilityIdentifier("login.createAccount")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
            .mcScreenBackground()
            .accessibilityIdentifier("screen.login")
            .navigationTitle("Sign in")
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                authViewModel.errorMessage = nil
            }
        }
    }

    private func signIn() {
        guard canSubmit else { return }
        focus = nil
        Task {
            isLoading = true
            await authViewModel.signIn(email: email.trimmingCharacters(in: .whitespaces), password: password)
            isLoading = false
        }
    }
}
