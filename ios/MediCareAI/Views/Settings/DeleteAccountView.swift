import SwiftUI

struct DeleteAccountView: View {
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @EnvironmentObject private var authViewModel: AuthViewModel

    @State private var confirmationText = ""
    @State private var isDeleting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Delete Account")
                .font(.title2)
                .bold()
                .foregroundStyle(Color.mcTextPrimary)

            Text("Deleting your account permanently removes your data and cannot be undone.")
                .font(.body)
                .foregroundStyle(Color.mcTextSecondary)

            Text("Type DELETE to confirm")
                .font(.headline)
                .foregroundStyle(Color.mcTextPrimary)

            TextField("DELETE", text: $confirmationText)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
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
                .accessibilityIdentifier("accountDelete.confirmation")

            Button(role: .destructive) {
                Task {
                    isDeleting = true
                    await settingsViewModel.deleteAccount()
                    if settingsViewModel.errorMessage == nil {
                        authViewModel.signOut()
                    }
                    isDeleting = false
                }
            } label: {
                if isDeleting {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Permanently Delete Account")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.mcEmergencyRed)
            .disabled(confirmationText != "DELETE" || isDeleting)
            .accessibilityIdentifier("accountDelete.submit")

            if let errorMessage = settingsViewModel.errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(Color.mcEmergencyRed)
            }

            Spacer()
        }
        .padding(16)
        .background(Color.mcBackground)
        .navigationTitle("Delete Account")
    }
}
