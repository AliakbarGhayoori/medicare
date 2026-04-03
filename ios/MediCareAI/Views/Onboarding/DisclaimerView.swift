import SwiftUI

struct DisclaimerView: View {
    @Binding var acceptedDisclaimer: Bool

    private let principles = [
        "MediCare AI provides health information, not medical treatment.",
        "If you may be having an emergency, call 911 right away.",
        "AI can make mistakes. Check important information with your clinician."
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Image("onboarding-disclaimer")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 180, maxHeight: 140)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
                    .padding(.top, 8)

                Text("A Few Things to Know")
                    .font(.title3)
                    .bold()
                    .foregroundStyle(Color.mcTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .center)

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(principles, id: \.self) { point in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "info.circle.fill")
                                .font(.subheadline)
                                .foregroundStyle(Color.mcAccent)
                                .padding(.top, 2)
                            Text(point)
                                .font(.body)
                                .foregroundStyle(Color.mcTextPrimary)
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.mcBackgroundSecondary)
                )

                Toggle(isOn: $acceptedDisclaimer) {
                    Text("I understand and agree")
                        .font(.headline)
                        .foregroundStyle(Color.mcTextPrimary)
                }
                .tint(Color.mcAccent)
                .accessibilityHint("Required before continuing")
            }
            .padding(20)
        }
    }
}
