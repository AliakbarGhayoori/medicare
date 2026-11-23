import SwiftUI

/// A short message that floats at the top of a screen, then goes away.
struct ToastView: View {
    let message: String
    var systemImage: String = "checkmark.circle.fill"
    var tint: Color = .mcGreen

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.mcInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.mcSurface, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.mcLine, lineWidth: 0.5))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        .accessibilityElement(children: .combine)
        .onAppear {
            AccessibilityNotification.Announcement(message).post()
        }
    }
}
