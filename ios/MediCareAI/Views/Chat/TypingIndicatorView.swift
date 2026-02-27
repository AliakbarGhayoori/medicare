import SwiftUI

struct TypingIndicatorView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: "stethoscope")
                    .font(.caption.bold())
                Text("MediCare AI")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.mcTextSecondary)
            }

            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.mcTextSecondary)
                        .frame(width: 8, height: 8)
                        .opacity(dotOpacity(for: index))
                        .scaleEffect(dotScale(for: index))
                }
            }
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
        .accessibilityLabel("Assistant is writing a response")
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                phase = 1
            }
        }
    }

    private func dotOpacity(for index: Int) -> Double {
        guard !reduceMotion else { return 0.6 }
        let offset = Double(index) * 0.33
        let adjusted = (phase + offset).truncatingRemainder(dividingBy: 1.0)
        return 0.3 + 0.7 * adjusted
    }

    private func dotScale(for index: Int) -> CGFloat {
        guard !reduceMotion else { return 1.0 }
        let offset = Double(index) * 0.33
        let adjusted = (phase + offset).truncatingRemainder(dividingBy: 1.0)
        return 0.7 + 0.3 * adjusted
    }
}
