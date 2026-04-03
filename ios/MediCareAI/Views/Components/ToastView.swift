import SwiftUI

struct ToastView: View {
    let message: String
    var icon: String = "checkmark.circle.fill"
    var iconColor: Color = .mcSuccessGreen

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .font(.callout.weight(.semibold))
            Text(message)
                .font(.callout)
                .foregroundStyle(Color.mcTextPrimary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            Capsule(style: .continuous)
                .fill(Color.mcBackgroundSecondary)
                .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.mcInputBorder.opacity(0.5), lineWidth: 1)
        )
    }
}
