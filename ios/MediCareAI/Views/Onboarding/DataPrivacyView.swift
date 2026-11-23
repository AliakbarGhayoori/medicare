import SwiftUI

/// What is sent to which service. Nothing is sent before the person agrees.
struct DataPrivacyView: View {
    @Binding var acceptedDataSharing: Bool

    var body: some View {
        OnboardingPage(
            title: "What gets shared",
            text: "To answer you, some of your information is sent to two services. Nothing is sent until you agree."
        ) {
            VStack(alignment: .leading, spacing: 18) {
                FeatureRow(
                    symbol: "bubble.left.and.bubble.right.fill",
                    tint: .tileViolet,
                    title: "Your question and health profile",
                    detail: "Sent to OpenRouter, the AI service that writes the answer."
                )
                FeatureRow(
                    symbol: "magnifyingglass",
                    tint: .tileBlue,
                    title: "Search words from your question",
                    detail: "Sent to Tavily to find trusted sources such as the NHS and Mayo Clinic."
                )
                FeatureRow(
                    symbol: "hand.raised.fill",
                    tint: .tileSlate,
                    title: "Nothing else",
                    detail: "Your data is never sold and never used for ads."
                )

                Link("Read the privacy policy", destination: URL(string: "https://mediguide.co/privacy")!)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.mcBlueText)
                    .frame(minHeight: 44)

                Toggle(isOn: $acceptedDataSharing) {
                    Text("I understand and agree to this sharing")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.mcInk)
                }
                .tint(Color.mcBlue)
                .padding(16)
                .background(Color.mcSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.mcLine, lineWidth: 1)
                )
                .accessibilityHint("Needed before you can continue")
                .accessibilityIdentifier("onboarding.consentSharing")
            }
        }
    }
}
