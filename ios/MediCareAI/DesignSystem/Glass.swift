import SwiftUI

extension View {
    /// Liquid Glass on iOS 26; a material capsule with a hairline on earlier versions.
    @ViewBuilder
    func mcGlassCapsule() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: Capsule())
        } else {
            self.background(.regularMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.mcLine, lineWidth: 0.5))
        }
    }

    /// Liquid Glass circle on iOS 26; a material circle on earlier versions.
    @ViewBuilder
    func mcGlassCircle() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: Circle())
        } else {
            self.background(.regularMaterial, in: Circle())
                .overlay(Circle().strokeBorder(Color.mcLine, lineWidth: 0.5))
        }
    }
}

/// A toolbar-style capsule button: icon and short label in blue on glass.
struct GlassCapsuleButton: View {
    let title: String
    var systemImage: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.subheadline.weight(.semibold))
                }
                Text(title)
                    .font(.body.weight(.semibold))
            }
            .foregroundStyle(Color.mcBlueText)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .mcGlassCapsule()
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
