import SwiftUI

struct DataPrivacyView: View {
    @Binding var acceptedDataSharing: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Image("onboarding-privacy")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 180, maxHeight: 140)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
                    .padding(.top, 8)

                Text("Your Privacy Matters")
                    .font(.title3)
                    .bold()
                    .foregroundStyle(Color.mcTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .center)

                Text("To answer your health questions, we share some data with these services:")
                    .font(.callout)
                    .foregroundStyle(Color.mcTextSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                VStack(spacing: 10) {
                    TrustCard(
                        icon: "bubble.left.and.text.bubble.right",
                        title: "Your questions",
                        description: "Sent to an AI service to generate medical guidance."
                    )
                    TrustCard(
                        icon: "magnifyingglass",
                        title: "Evidence search",
                        description: "Queries trusted sources like Mayo Clinic and NIH."
                    )
                    TrustCard(
                        icon: "lock.shield",
                        title: "Your health profile",
                        description: "Stays private. Never sold or shared for advertising."
                    )
                }

                Toggle(isOn: $acceptedDataSharing) {
                    Text("I understand and consent to this data sharing")
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
