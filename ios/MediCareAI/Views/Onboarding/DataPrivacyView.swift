import SwiftUI

struct DataPrivacyView: View {
    @Binding var acceptedDataSharing: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Hero zone
            Image("onboarding-privacy")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 140, maxHeight: 120)
                .accessibilityHidden(true)
                .padding(.top, 40)
                .frame(maxWidth: .infinity)

            Spacer(minLength: 12)

            // Content dock
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    EyebrowChip(text: "Required before use")

                    Text("Know What Gets Shared")
                        .font(.title3.bold())
                        .foregroundStyle(Color.mcTextPrimary)
                        .multilineTextAlignment(.center)

                    Text("Some data is sent to third-party services to answer your questions. Nothing is shared until you consent.")
                        .font(.callout)
                        .foregroundStyle(Color.mcTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 4)

                    VStack(spacing: 8) {
                        TrustCard(
                            icon: "bubble.left.and.text.bubble.right",
                            title: "Your questions and health profile",
                            description: "Sent to OpenRouter (AI service) to generate medical guidance."
                        )
                        TrustCard(
                            icon: "magnifyingglass",
                            title: "Search queries from your questions",
                            description: "Sent to Tavily to find evidence from Mayo Clinic, NIH, and other trusted sources."
                        )
                        TrustCard(
                            icon: "lock.shield",
                            title: "Your data stays private",
                            description: "Never sold, never used for ads, never shared beyond what's needed."
                        )
                    }

                    Text("[Privacy Policy](https://mediguide.co/privacy)")
                        .font(.caption)
                        .foregroundStyle(Color.mcTextSecondary)
                        .tint(Color.mcAccent)

                    // Consent toggle
                    Toggle(isOn: $acceptedDataSharing) {
                        Text("I understand and consent to this data sharing")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.mcTextPrimary)
                    }
                    .tint(Color.mcAccent)
                    .padding(14)
                    .background(Color.mcBackgroundSecondary.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityHint("Required before continuing")
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 12)
            }
            .background(
                UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28)
                    .fill(Color.mcBackgroundSecondary.opacity(0.5))
            )
        }
    }
}
