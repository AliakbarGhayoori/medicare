import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // App info section
                VStack(spacing: 8) {
                    Image(systemName: "stethoscope")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.mcAccent)

                    Text("MediCare AI")
                        .font(.title2)
                        .bold()
                        .foregroundStyle(Color.mcTextPrimary)

                    Text("Version \(appVersion) (\(buildNumber))")
                        .font(.footnote)
                        .foregroundStyle(Color.mcTextSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 8)

                // Medical Disclaimer section
                VStack(alignment: .leading, spacing: 12) {
                    Label {
                        Text("Important Medical Notice")
                            .font(.headline)
                            .foregroundStyle(Color.mcTextPrimary)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.mcWarningAmber)
                    }

                    Group {
                        Text("MediCare AI gives health information and education. It is not a doctor, nurse, or licensed healthcare provider.")
                        Text("Always speak with a qualified healthcare professional before changing medications or treatment plans.")
                        Text("If you think you may be having a medical emergency, call 911 (or your local emergency number) right away.")
                        Text("AI can make mistakes. Double-check important health information with your clinician.")
                    }
                    .font(.body)
                    .foregroundStyle(Color.mcTextPrimary)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.mcBackgroundSecondary)
                )

                // Privacy section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Privacy")
                        .font(.headline)
                        .foregroundStyle(Color.mcTextPrimary)

                    Text("Your health data is used to personalize your experience. We do not sell your data or share it with third parties for advertising.")
                        .font(.body)
                        .foregroundStyle(Color.mcTextSecondary)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.mcBackgroundSecondary)
                )
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
