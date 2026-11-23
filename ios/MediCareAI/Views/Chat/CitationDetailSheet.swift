import SwiftUI

/// Where a numbered fact comes from: the publisher, the page title, the passage used and a
/// link to read the page itself.
struct CitationDetailSheet: View {
    let citation: Citation

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private var publisher: String {
        SourceName.display(for: citation.source)
    }

    private var link: URL? {
        guard !citation.url.isEmpty, let url = URL(string: citation.url),
              let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http" else {
            return nil
        }
        return url
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 8) {
                        CiteBadge(number: citation.number)
                        Text(publisher)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.mcInk2)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Source \(citation.number), \(publisher)")

                    Text(citation.title)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color.mcInk)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)

                    if !citation.snippet.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("What the page says")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.mcInk2)
                            HStack(alignment: .top, spacing: 12) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.mcCoral)
                                    .frame(width: 4)
                                    .accessibilityHidden(true)
                                Text(citation.snippet)
                                    .font(.body)
                                    .foregroundStyle(Color.mcInk)
                                    .textSelection(.enabled)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.mcPaper, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }

                    if let link {
                        Button {
                            openURL(link)
                        } label: {
                            Label("Read it on \(publisher)", systemImage: "safari")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .accessibilityIdentifier("citation.open")

                        Text(link.host ?? citation.url)
                            .font(.footnote)
                            .foregroundStyle(Color.mcInk2)
                            .textSelection(.enabled)
                    } else {
                        Label("There is no link for this source.", systemImage: "link")
                            .font(.subheadline)
                            .foregroundStyle(Color.mcInk2)
                    }
                }
                .padding(20)
            }
            .background(Color.mcSurface.ignoresSafeArea())
            .navigationTitle("Source \(citation.number)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("citation.done")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
