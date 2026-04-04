import SwiftUI

struct DataPrivacyView: View {
    @Binding var acceptedDataSharing: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Image("onboarding-privacy")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 140, maxHeight: 120)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
                    .padding(.top, 8)

                Text("Your Privacy Matters")
                    .font(.title3)
                    .bold()
                    .foregroundStyle(Color.mcTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .center)

                Text("To answer your health questions, some data is shared with third-party services. Your consent is required before any data is sent.")
                    .font(.callout)
                    .foregroundStyle(Color.mcTextSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

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

                Text("Full details in our [Privacy Policy](https://mediguide.co/privacy).")
                    .font(.caption)
                    .foregroundStyle(Color.mcTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)

                Toggle(isOn: $acceptedDataSharing) {
                    Text("I understand and consent to this data sharing")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.mcTextPrimary)
                }
                .tint(Color.mcAccent)
                .accessibilityHint("Required before continuing")
            }
            .padding(20)
        }
    }
}
