import SwiftUI

/// What MediCare AI is not, agreed to before first use.
struct DisclaimerView: View {
    @Binding var acceptedDisclaimer: Bool

    var body: some View {
        OnboardingPage(
            title: "A guide, not a doctor",
            text: "MediCare AI explains health information. It does not examine you, diagnose you or prescribe."
        ) {
            VStack(alignment: .leading, spacing: 18) {
                FeatureRow(
                    symbol: "heart.text.square.fill",
                    tint: .tileBlue,
                    title: "Information, not treatment",
                    detail: "Use it to understand your health and to prepare for your doctor."
                )
                FeatureRow(
                    symbol: "phone.fill",
                    tint: .tileRed,
                    title: "In an emergency, call \(EmergencyNumber.current)",
                    detail: "Don't wait for an answer in the app."
                )
                FeatureRow(
                    symbol: "person.2.fill",
                    tint: .tileGreen,
                    title: "Check big decisions",
                    detail: "Talk to your doctor or pharmacist before you change a medicine."
                )

                Toggle(isOn: $acceptedDisclaimer) {
                    Text("I understand and agree")
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
                .accessibilityHint("Needed before you can start")
                .accessibilityIdentifier("onboarding.consentDisclaimer")
            }
        }
    }
}
