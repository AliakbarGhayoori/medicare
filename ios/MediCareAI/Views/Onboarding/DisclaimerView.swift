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
            // Support plate image
            ImagePlate(name: "onboarding-disclaimer", maxSize: 140)
                .padding(.top, 32)

            Spacer(minLength: 8)

            // Content dock
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    EyebrowChip(text: "Important to know")

                    Text("Use MediCare AI as a Guide")
                        .font(.title3.bold())
                        .foregroundStyle(Color.mcTextPrimary)
                        .multilineTextAlignment(.center)

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
                            .background(Color.mcBackgroundSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }

                    Toggle(isOn: $acceptedDisclaimer) {
                        Text("I understand and agree")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.mcTextPrimary)
                    }
                    .tint(Color.mcAccent)
                    .padding(14)
                    .background(Color.mcBackgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityHint("Required before continuing")
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)
            }
        }
    }
}
