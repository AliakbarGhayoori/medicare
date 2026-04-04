import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // App info
                VStack(spacing: 10) {
                    Image("auth-hero")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 80, maxHeight: 80)
                        .accessibilityHidden(true)

                    Text("MediCare AI")
                        .font(.title2)
                        .bold()
                        .foregroundStyle(Color.mcTextPrimary)

                    Text("Version \(appVersion) (\(buildNumber))")
                        .font(.footnote)
                        .foregroundStyle(Color.mcTextSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 4)

                // Medical notice
                VStack(alignment: .leading, spacing: 10) {
                    Label("Medical Notice", systemImage: "info.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.mcAccent)

                    Text("MediCare AI provides health information and education. It is not a substitute for professional medical advice, diagnosis, or treatment.")
                        .font(.callout)
                        .foregroundStyle(Color.mcTextPrimary)

                    Text("If you think you may be having a medical emergency, call 911 right away.")
                        .font(.callout)
                        .foregroundStyle(Color.mcTextPrimary)
                }
                .padding(16)
                .background(Color.mcBackgroundSecondary.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                // Privacy & Legal
                VStack(alignment: .leading, spacing: 12) {
                    Text("Privacy & Legal")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.mcTextSecondary)

                    Text("Your health data is used to personalize your experience. We do not sell your data or share it for advertising.")
                        .font(.callout)
                        .foregroundStyle(Color.mcTextSecondary)

                    Link(destination: URL(string: "https://mediguide.co/privacy")!) {
                        Label("Privacy Policy", systemImage: "hand.raised.fill")
                            .font(.callout.weight(.medium))
                    }
                    .tint(Color.mcAccent)

                    Link(destination: URL(string: "https://mediguide.co/terms")!) {
                        Label("Terms of Service", systemImage: "doc.text.fill")
                            .font(.callout.weight(.medium))
                    }
                    .tint(Color.mcAccent)
                }
                .padding(16)
                .background(Color.mcBackgroundSecondary.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(16)
        }
        .background(Color.mcBackground)
        .navigationTitle("About & Legal")
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}
