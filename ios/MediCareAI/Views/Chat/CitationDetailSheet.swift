import SwiftUI

struct CitationDetailSheet: View {
    let citation: Citation

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 8) {
                        Text("Source \(citation.number)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.mcAccent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.mcCitationBadge)
                            )

                        Text(citation.source)
                            .font(.caption)
                            .foregroundStyle(Color.mcTextSecondary)
                    }

                    Text(citation.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.mcTextPrimary)

                    if !citation.snippet.isEmpty {
                        Text(citation.snippet)
                            .font(.callout)
                            .foregroundStyle(Color.mcTextSecondary)
                            .textSelection(.enabled)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.mcBackgroundSecondary)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.mcInputBorder.opacity(0.75), lineWidth: 1)
                            )
                    } else {
                        Text("No source excerpt is available for this citation.")
                            .font(.callout)
                            .foregroundStyle(Color.mcTextSecondary)
                    }

                    if citation.url.isEmpty {
                        Label("No source link is available", systemImage: "exclamationmark.triangle")
                            .font(.callout)
                            .foregroundStyle(Color.mcWarningAmber)
                    } else if let url = URL(string: citation.url) {
                        Link(destination: url) {
                            Label("Open Source in Safari", systemImage: "arrow.up.right.square")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.mcAccent)

                        Text(citation.url)
                            .font(.footnote)
                            .foregroundStyle(Color.mcTextSecondary)
                            .textSelection(.enabled)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.mcBackgroundSecondary.opacity(0.75))
                            )
                    }
                }
                .padding(16)
            }
            .background(Color.mcBackground)
            .navigationTitle("Citation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
