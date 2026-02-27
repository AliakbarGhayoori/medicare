import SwiftUI

struct DisclaimerView: View {
    @Binding var acceptedDisclaimer: Bool

    private let disclaimerPoints = [
        "MediCare AI is not a doctor, nurse, or licensed healthcare provider.",
        "This app is for general education and health information.",
        "It cannot diagnose conditions, prescribe medication, or order treatment.",
        "Talk with a qualified healthcare professional before making medical decisions.",
        "If you may be having an emergency, call 911 right away.",
        "AI can make mistakes, so double-check important information with your clinician."
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.mcWarningAmber)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                Text("Important Medical Notice")
                    .font(.title3)
                    .bold()
                    .foregroundStyle(Color.mcTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .center)

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(disclaimerPoints, id: \.self) { point in
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
                    Text("I understand and agree to this notice")
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
