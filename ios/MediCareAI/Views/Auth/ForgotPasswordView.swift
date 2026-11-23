import SwiftUI

struct ForgotPasswordView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel

    @State private var email = ""
    @State private var didSend = false
    @State private var isSending = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                AuthHeader(
                    title: "Reset your password",
                    subtitle: "Type the email you signed up with. We will send you a link to choose a new password.",
                    showsMark: false
                )
                .padding(.top, 8)

                FormField(label: "Email") {
                    TextField(AuthCopy.emailExample, text: $email)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                        .textContentType(UITesting.isActive ? nil : .username)
                        .accessibilityLabel("Email")
                        .accessibilityIdentifier("forgot.email")
                }

                if didSend {
                    FormMessage(text: "Check your inbox for the link. It can take a few minutes.", kind: .success)
                }

                if let error = authViewModel.errorMessage {
                    FormMessage(text: error)
                }

                Button {
                    Task {
                        isSending = true
                        didSend = false
                        await authViewModel.resetPassword(email: email.trimmingCharacters(in: .whitespaces))
                        didSend = authViewModel.errorMessage == nil
                        isSending = false
                    }
                } label: {
                    if isSending {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(didSend ? "Send the link again" : "Email me a link")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(email.trimmingCharacters(in: .whitespaces).isEmpty || isSending)
                .accessibilityHint("Sends a password reset email")
                .accessibilityIdentifier("forgot.submit")
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .mcScreenBackground()
        .accessibilityIdentifier("screen.forgotPassword")
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            authViewModel.errorMessage = nil
        }
    }
}
