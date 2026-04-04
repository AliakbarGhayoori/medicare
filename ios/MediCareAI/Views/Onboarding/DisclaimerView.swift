import SwiftUI

struct DisclaimerView: View {
    @Binding var acceptedDisclaimer: Bool

    private let principles = [
        (icon: "heart.text.square", text: "Health information, not treatment."),
        (icon: "phone.arrow.up.right", text: "Call 911 for emergencies."),
        (icon: "checkmark.shield", text: "Double-check important decisions with your clinician."),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Hero zone
            Image("onboarding-disclaimer")
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
                    EyebrowChip(text: "Important to know")

                    Text("Use MediCare AI as a Guide")
                        .font(.title3.bold())
                        .foregroundStyle(Color.mcTextPrimary)
                        .multilineTextAlignment(.center)

                    // Safety principles
                    VStack(spacing: 8) {
                        ForEach(principles, id: \.text) { principle in
                            HStack(spacing: 12) {
                                Image(systemName: principle.icon)
                                    .font(.body)
                                    .foregroundStyle(Color.mcAccent)
                                    .frame(width: 28)

                                Text(principle.text)
                                    .font(.callout)
                                    .foregroundStyle(Color.mcTextPrimary)

                                Spacer()
                            }
                            .padding(.vertical, 11)
                            .padding(.horizontal, 14)
                            .background(Color.mcBackgroundSecondary.opacity(0.4))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }

                    // Consent toggle
                    Toggle(isOn: $acceptedDisclaimer) {
                        Text("I understand and agree")
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
