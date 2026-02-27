import SwiftUI

struct CitationBadgeView: View {
    let citation: Citation
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Text("[\(citation.number)]")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.mcAccent)

                Text(citation.source)
                    .font(.caption)
                    .foregroundStyle(Color.mcTextSecondary)
                    .lineLimit(1)

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(Color.mcTextSecondary)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.mcCitationBadge)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.mcInputBorder.opacity(0.8), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .frame(minHeight: 34)
        .accessibilityLabel("Citation \(citation.number)")
        .accessibilityHint("Opens citation details from \(citation.source)")
    }
}
