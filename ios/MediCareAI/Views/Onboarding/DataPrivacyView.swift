import SwiftUI

struct DataPrivacyView: View {
    @Binding var acceptedDataSharing: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    Image("onboarding-privacy")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 140, maxHeight: 120)
                        .accessibilityHidden(true)
                        .padding(.top, 40)

                    VStack(spacing: 12) {
                        Text("REQUIRED BEFORE USE")
                            .font(.caption2.weight(.bold))
                            .tracking(0.8)
                            .foregroundStyle(Color.mcAccent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.mcAccent.opacity(0.1))
                            .clipShape(Capsule())

                        Text("Know What Gets Shared")
                            .font(.title3.bold())
                            .foregroundStyle(Color.mcTextPrimary)
                            .multilineTextAlignment(.center)

                        Text("To answer your questions, some data is sent to third-party services. Nothing is shared until you consent.")
                            .font(.callout)
                            .foregroundStyle(Color.mcTextSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)

                    VStack(spacing: 10) {
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
                            description: "Never sold, never used for ads, never shared beyond what's needed to answer you."
                        )
                    }
                    .padding(.horizontal, 20)

                    Text("[Privacy Policy](https://mediguide.co/privacy)")
                        .font(.caption)
                        .foregroundStyle(Color.mcTextSecondary)
                        .tint(Color.mcAccent)

                    // Consent card
                    Toggle(isOn: $acceptedDataSharing) {
                        Text("I understand and consent to this data sharing")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.mcTextPrimary)
                    }
                    .tint(Color.mcAccent)
                    .padding(16)
                    .background(Color.mcBackgroundSecondary.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal, 20)
                    .accessibilityHint("Required before continuing")
                }
                .padding(.bottom, 16)
            }
        }
    }
}
