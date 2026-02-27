import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var showLogoutConfirmation = false

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Font Size", selection: Binding(
                    get: { settingsViewModel.settings.fontSize },
                    set: { newValue in
                        Task {
                            await settingsViewModel.update(fontSize: newValue, highContrast: nil)
                        }
                    }
                )) {
                    ForEach(UserSettings.FontSize.allCases, id: \.self) { size in
                        Text(size.label).tag(size)
                    }
                }
                .accessibilityIdentifier("settings.fontSize")

                Toggle("High Contrast", isOn: Binding(
                    get: { settingsViewModel.settings.highContrast },
                    set: { newValue in
                        Task {
                            await settingsViewModel.update(fontSize: nil, highContrast: newValue)
                        }
                    }
                ))
                .tint(Color.mcAccent)
                .accessibilityIdentifier("settings.highContrast")
            }

            Section("About & Legal") {
                NavigationLink("About, Privacy, and Disclaimer", destination: AboutView())
            }

            Section {
                Button("Log Out", role: .destructive) {
                    showLogoutConfirmation = true
                }
                .accessibilityHint("Logs you out of the app")
                .accessibilityIdentifier("settings.logout")

                NavigationLink("Delete Account", destination: DeleteAccountView())
                    .foregroundStyle(Color.mcEmergencyRed)
                    .font(.body)
                    .accessibilityHint("Permanently deletes your account and all data")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label {
                        Text("Medical Notice")
                            .font(.headline)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.mcWarningAmber)
                    }
                    Text("MediCare AI shares health information and does not replace medical care.")
                        .font(.callout)
                        .foregroundStyle(Color.mcTextSecondary)
                    Text("If this could be an emergency, call 911 immediately.")
                        .font(.callout)
                        .foregroundStyle(Color.mcTextSecondary)
                }
            }

            Section {
                HStack {
                    Spacer()
                    Text("MediCare AI v1.0")
                        .font(.footnote)
                        .foregroundStyle(Color.mcTextSecondary)
                    Spacer()
                }
            }

            if let error = settingsViewModel.errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(Color.mcEmergencyRed)
                        .font(.callout)
                }
            }
        }
        .accessibilityIdentifier("screen.settings")
        .navigationTitle("Settings")
        .task {
            await settingsViewModel.load()
        }
        .refreshable {
            await settingsViewModel.load()
        }
        .alert("Log out now?", isPresented: $showLogoutConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Log Out", role: .destructive) {
                authViewModel.signOut()
                settingsViewModel.logout()
            }
        } message: {
            Text("You can sign back in at any time.")
        }
    }
}
