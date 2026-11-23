import SwiftUI

struct DeleteAccountView: View {
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @EnvironmentObject private var authViewModel: AuthViewModel

    @State private var confirmationText = ""
    @State private var isDeleting = false

    private var isConfirmed: Bool {
        confirmationText.trimmingCharacters(in: .whitespaces).uppercased() == "DELETE"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("This deletes your account, your chats and your health profile. It can't be undone.")
                    .font(.body)
                    .foregroundStyle(Color.mcInk)
                    .fixedSize(horizontal: false, vertical: true)

                FormField(label: "Type DELETE to confirm") {
                    TextField("DELETE", text: $confirmationText)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .accessibilityLabel("Type DELETE to confirm")
                        .accessibilityIdentifier("accountDelete.confirmation")
                }

                if let error = settingsViewModel.errorMessage {
                    FormMessage(text: error)
                }

                Button {
                    Task {
                        isDeleting = true
                        if await settingsViewModel.deleteAccount() {
                            authViewModel.forgetFirstName()
                            authViewModel.signOut()
                        }
                        isDeleting = false
                    }
                } label: {
                    if isDeleting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Delete my account")
                    }
                }
                .buttonStyle(PrimaryButtonStyle(fill: .mcRed))
                .disabled(!isConfirmed || isDeleting)
                .accessibilityIdentifier("accountDelete.submit")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .scrollDismissesKeyboard(.interactively)
        .mcScreenBackground()
        .accessibilityIdentifier("screen.deleteAccount")
        .navigationTitle("Delete account")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            settingsViewModel.errorMessage = nil
        }
    }
}
