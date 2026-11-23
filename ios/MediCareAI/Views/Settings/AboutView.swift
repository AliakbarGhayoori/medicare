import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    HeartbeatLine(variant: .mark, lineWidth: 4)
                        .frame(width: 84, height: 44)
                    Text("MediCare AI")
                        .font(.mcDisplay(34, relativeTo: .title))
                        .foregroundStyle(Color.mcInk)
                        .accessibilityAddTraits(.isHeader)
                    Text("Version \(appVersion)")
                        .font(.subheadline)
                        .foregroundStyle(Color.mcInk2)
                }
                .padding(.bottom, 8)

                AboutCard(symbol: "text.bubble.fill", tint: .tileBlue, title: "What it does") {
                    Text("MediCare AI answers health questions in plain language and names the trusted sources behind every answer. It is not a doctor, and it does not replace medical care.")
                }

                AboutCard(symbol: "phone.fill", tint: .tileRed, title: "In an emergency") {
                    Text("Call \(EmergencyNumber.current) straight away. Don't wait for an answer in the app.")
                }

                AboutCard(symbol: "lock.fill", tint: .tileSlate, title: "Your privacy") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Your questions and health profile are used only to answer you. They are never sold and never used for ads.")
                        Link("Privacy policy", destination: URL(string: "https://mediguide.co/privacy")!)
                            .font(.body.weight(.semibold))
                            .frame(minHeight: 44)
                        Link("Terms of use", destination: URL(string: "https://mediguide.co/terms")!)
                            .font(.body.weight(.semibold))
                            .frame(minHeight: 44)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .mcScreenBackground()
        .tint(Color.mcBlueText)
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        return build.isEmpty ? version : "\(version) (\(build))"
    }
}

private struct AboutCard<Content: View>: View {
    let symbol: String
    let tint: Color
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                IconTile(systemName: symbol, color: tint)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.mcInk)
                    .accessibilityAddTraits(.isHeader)
            }
            content
                .font(.body)
                .foregroundStyle(Color.mcInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .mcCard()
    }
}
