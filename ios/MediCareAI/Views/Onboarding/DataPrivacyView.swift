import SwiftUI

struct DataPrivacyView: View {
    @Binding var acceptedDataSharing: Bool

    private let dataPoints = [
        (icon: "bubble.left.and.text.bubble.right", text: "Your health questions are sent to an AI service (OpenRouter) to generate medical guidance."),
        (icon: "magnifyingglass", text: "Your questions are used as search queries to find medical evidence from trusted sources (via Tavily)."),
        (icon: "heart.text.square", text: "Your health profile (conditions, medications, concerns) is included to personalize responses."),
        (icon: "lock.shield", text: "Your data is never sold, used for advertising, or shared beyond what is needed to answer your questions."),
        (icon: "doc.text", text: "Full details are in our Privacy Policy at mediguide.co/privacy."),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.mcAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                Text("How Your Data Is Used")
                    .font(.title3)
                    .bold()
                    .foregroundStyle(Color.mcTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .center)

                Text("To answer your health questions, MediCare AI sends some of your data to third-party services:")
                    .font(.callout)
                    .foregroundStyle(Color.mcTextSecondary)

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(dataPoints, id: \.text) { point in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: point.icon)
                                .font(.subheadline)
                                .foregroundStyle(Color.mcAccent)
                                .frame(width: 22)
                                .padding(.top, 2)
                            Text(point.text)
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
