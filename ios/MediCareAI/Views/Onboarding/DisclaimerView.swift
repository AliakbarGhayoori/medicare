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
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    Image("onboarding-disclaimer")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 140, maxHeight: 120)
                        .accessibilityHidden(true)
                        .padding(.top, 40)

                    VStack(spacing: 12) {
                        Text("IMPORTANT TO KNOW")
                            .font(.caption2.weight(.bold))
                            .tracking(0.8)
                            .foregroundStyle(Color.mcAccent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.mcAccent.opacity(0.1))
                            .clipShape(Capsule())

                        Text("Use MediCare AI as a Guide")
                            .font(.title3.bold())
                            .foregroundStyle(Color.mcTextPrimary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)

                    // Safety principles
                    VStack(spacing: 10) {
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
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .background(Color.mcBackgroundSecondary.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                    .padding(.horizontal, 20)

                    // Agreement card
                    Toggle(isOn: $acceptedDisclaimer) {
                        Text("I understand and agree")
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
