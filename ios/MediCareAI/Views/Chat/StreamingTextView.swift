import SwiftUI

struct StreamingTextView: View {
    let text: String
    @State private var showCursor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: "waveform.path.ecg")
                    .font(.caption.bold())
                Text("MediCare AI")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(Color.mcTextSecondary)

            (
                Text(text)
                    .font(.callout)
                    .foregroundStyle(Color.mcTextPrimary)
                +
                Text(showCursor ? "▍" : "")
                    .font(.callout.bold())
                    .foregroundStyle(Color.mcAccent)
            )
            .frame(maxWidth: UIScreen.main.bounds.width * 0.82, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.mcAssistantBubble)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.mcDivider.opacity(0.6), lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                showCursor = true
            }
        }
    }
}
