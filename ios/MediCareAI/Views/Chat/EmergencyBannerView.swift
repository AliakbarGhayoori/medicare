import SwiftUI

struct EmergencyBannerView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.2))
                        .frame(width: 34, height: 34)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                }

                Text("This could be a medical emergency")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }

            Link(destination: URL(string: "tel://911")!) {
                Label("Call 911 now", systemImage: "phone.fill")
                    .font(.headline.weight(.bold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white)
                    )
                    .foregroundStyle(Color.mcEmergencyRed)
            }

            Text("If symptoms are severe, worsening, or sudden, seek emergency care immediately.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.92))
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [
                    Color.mcEmergencyRed,
                    Color.mcEmergencyRed.opacity(0.9)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.mcEmergencyRed.opacity(0.25), radius: 10, x: 0, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Possible medical emergency. Call 911 now.")
    }
}
