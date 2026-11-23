import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @EnvironmentObject private var authViewModel: AuthViewModel

    @State private var name = ""
    @State private var showsLogoutConfirmation = false
    @FocusState private var nameFocused: Bool

    private let privacyURL = URL(string: "https://mediguide.co/privacy")!
    private let termsURL = URL(string: "https://mediguide.co/terms")!

    var body: some View {
        List {
            Section {
                LabeledContent {
                    TextField("First name", text: $name)
                        .multilineTextAlignment(.trailing)
                        .textContentType(.givenName)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .focused($nameFocused)
                        .onSubmit(saveName)
                        .foregroundStyle(Color.mcInk)
                        .accessibilityLabel("Your name")
                        .accessibilityIdentifier("settings.name")
                } label: {
                    SettingsLabel(title: "Your name", symbol: "person.fill", tint: .tileSlate)
                }
            } header: {
                Text("You")
            } footer: {
                Text("Used to greet you on Home. Leave it empty if you prefer no name.")
            }

            Section {
                Toggle(isOn: extraLargeText) {
                    SettingsLabel(title: "Extra large text", symbol: "textformat.size", tint: .tileBlue)
                }
                .tint(Color.mcBlue)
                .accessibilityIdentifier("settings.fontSize")

                Toggle(isOn: highContrast) {
                    SettingsLabel(title: "High contrast", symbol: "circle.lefthalf.filled", tint: .tileSlate)
                }
                .tint(Color.mcBlue)
                .accessibilityIdentifier("settings.highContrast")
            } header: {
                Text("Reading")
            } footer: {
                Text("Text follows your iPhone's text size. Extra large text makes it bigger everywhere in MediCare AI.")
            }

            Section {
                LabeledContent {
                    Text(EmergencyNumber.current)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.mcRedText)
                } label: {
                    SettingsLabel(title: "Emergency number", symbol: "phone.fill", tint: .tileRed)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("settings.emergencyNumber")
            } header: {
                Text("Safety")
            } footer: {
                Text(emergencyFooter)
            }

            Section {
                NavigationLink {
                    AboutView()
                } label: {
                    SettingsLabel(title: "About MediCare AI", symbol: "info.circle.fill", tint: .tileBlue)
                }
                .accessibilityIdentifier("settings.about")

                Link(destination: privacyURL) {
                    SettingsLabel(title: "Privacy policy", symbol: "hand.raised.fill", tint: .tileViolet, opensWebsite: true)
                }
                Link(destination: termsURL) {
                    SettingsLabel(title: "Terms of use", symbol: "doc.text.fill", tint: .tileSlate, opensWebsite: true)
                }
            } header: {
                Text("About")
            }

            Section {
                Button("Log out", role: .destructive) {
                    showsLogoutConfirmation = true
                }
                .accessibilityHint("Signs you out of MediCare AI")
                .accessibilityIdentifier("settings.logout")

                NavigationLink {
                    DeleteAccountView()
                } label: {
                    Text("Delete account")
                        .foregroundStyle(Color.mcRedText)
                }
                .accessibilityHint("Deletes your account and everything in it")
                .accessibilityIdentifier("settings.deleteAccount")
            } footer: {
                Text("MediCare AI \(appVersion)")
                    .frame(maxWidth: .infinity)
                    .padding(.top, 16)
                    .accessibilityIdentifier("settings.version")
            }

            if let error = settingsViewModel.errorMessage {
                Section {
                    FormMessage(text: error)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .mcScreenBackground()
        .accessibilityIdentifier("screen.settings")
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .task {
            name = authViewModel.firstName ?? ""
            await settingsViewModel.load()
        }
        .refreshable {
            await settingsViewModel.load()
        }
        .onChange(of: nameFocused) { _, focused in
            if !focused {
                saveName()
            }
        }
        .onChange(of: authViewModel.firstName) { _, newValue in
            if !nameFocused {
                name = newValue ?? ""
            }
        }
        .alert("Log out?", isPresented: $showsLogoutConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Log out", role: .destructive) {
                settingsViewModel.logout()
                authViewModel.signOut()
            }
        } message: {
            Text("You can sign in again at any time.")
        }
    }

    private var extraLargeText: Binding<Bool> {
        Binding(
            get: { settingsViewModel.settings.fontSize == .extraLarge },
            set: { isOn in
                Task { await settingsViewModel.update(fontSize: isOn ? .extraLarge : .large, highContrast: nil) }
            }
        )
    }

    private var highContrast: Binding<Bool> {
        Binding(
            get: { settingsViewModel.settings.highContrast },
            set: { isOn in
                Task { await settingsViewModel.update(fontSize: nil, highContrast: isOn) }
            }
        )
    }

    private var emergencyFooter: String {
        let base = "MediCare AI is not an emergency service. In an emergency, call this number."
        guard let country = EmergencyNumber.countryName(forRegion: EmergencyNumber.currentRegion) else {
            return base
        }
        return "The emergency number in \(country). " + base
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        return build.isEmpty ? version : "\(version) (\(build))"
    }

    private func saveName() {
        guard Greeting.cleanedFirstName(name) != authViewModel.firstName else {
            name = authViewModel.firstName ?? ""
            return
        }
        Task {
            await authViewModel.setFirstName(name)
            name = authViewModel.firstName ?? ""
        }
    }
}

/// A Settings row title with a coloured icon tile.
struct SettingsLabel: View {
    let title: String
    let symbol: String
    let tint: Color
    var opensWebsite = false

    var body: some View {
        HStack(spacing: 12) {
            IconTile(systemName: symbol, color: tint, size: 29)
            Text(title)
                .font(.body)
                .foregroundStyle(Color.mcInk)
            if opensWebsite {
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.mcInk2)
                    .accessibilityLabel("Opens in Safari")
            }
        }
    }
}
