import SwiftUI

struct V10MemoryView: View {
    @EnvironmentObject private var v10ViewModel: V10ViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if v10ViewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let digest = v10ViewModel.digest?.digest, !digest.isEmpty {
                filledState(digest: digest)
            } else {
                emptyState
            }
        }
        .overlay(alignment: .bottom) {
            if let notice = v10ViewModel.noticeMessage {
                ToastView(message: notice)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if let error = v10ViewModel.errorMessage {
                ToastView(message: error, icon: "exclamationmark.circle.fill", iconColor: .mcEmergencyRed)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .accessibilityIdentifier("screen.healthProfile")
        .background(Color.mcBackground)
        .navigationTitle("Health Profile")
        .toolbar {
            if v10ViewModel.digest?.digest != nil, !(v10ViewModel.digest?.digest?.isEmpty ?? true) {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        V10EditorView()
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .accessibilityIdentifier("v10.edit")
                    .accessibilityLabel("Edit health profile")
                }
            }
        }
        .task {
            await v10ViewModel.load()
        }
        .refreshable {
            await v10ViewModel.load()
        }
    }

    // MARK: - Filled State

    private func filledState(digest: String) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                let sections = parseDigestSections(digest)

                ForEach(sections, id: \.title) { section in
                    profileSection(title: section.title, icon: section.icon, items: section.items)
                }

                // Metadata
                if v10ViewModel.digest?.updatedAt != nil || v10ViewModel.digest?.lastUpdateSource != nil {
                    HStack(spacing: 16) {
                        if let updatedAt = v10ViewModel.digest?.updatedAt {
                            Label(DateFormatting.longDateTime.string(from: updatedAt), systemImage: "clock")
                                .font(.caption)
                                .foregroundStyle(Color.mcTextLight)
                        }
                        if let source = v10ViewModel.digest?.lastUpdateSource {
                            Label(source == "auto" ? "Updated by AI" : "Updated by you", systemImage: source == "auto" ? "cpu" : "pencil")
                                .font(.caption)
                                .foregroundStyle(Color.mcTextLight)
                        }
                    }
                    .padding(.top, 4)
                }

                if v10ViewModel.digest?.canRevert == true {
                    Button {
                        Task { await v10ViewModel.revertToPrevious() }
                    } label: {
                        if v10ViewModel.isReverting {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text("Restore Previous Version").frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
    }

    private func profileSection(title: String, icon: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.mcAccent)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(.body)
                        .foregroundStyle(Color.mcTextPrimary)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.mcBackgroundSecondary.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image("v10-empty")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 200, maxHeight: 200)
                .accessibilityHidden(true)

            Text("Your Health Profile")
                .font(.title3)
                .bold()
                .foregroundStyle(Color.mcTextPrimary)

            Text("Start a conversation and your conditions, medications, and concerns will be remembered here automatically.")
                .font(.callout)
                .foregroundStyle(Color.mcTextSecondary)
                .multilineTextAlignment(.center)

            NavigationLink {
                V10EditorView()
            } label: {
                Text("Add Manually")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.mcAccent)
            .controlSize(.large)
            .accessibilityIdentifier("v10.setup")

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Digest Parser

    private struct ProfileSection {
        let title: String
        let icon: String
        let items: [String]
    }

    private func parseDigestSections(_ digest: String) -> [ProfileSection] {
        var sections: [ProfileSection] = []
        var currentTitle = ""
        var currentItems: [String] = []

        let lines = digest.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            if trimmed.hasPrefix("#") {
                // Save previous section
                if !currentTitle.isEmpty && !currentItems.isEmpty {
                    sections.append(ProfileSection(
                        title: currentTitle,
                        icon: iconForSection(currentTitle),
                        items: currentItems
                    ))
                }
                currentTitle = trimmed.replacingOccurrences(of: "#", with: "").trimmingCharacters(in: .whitespaces)
                currentItems = []
            } else if trimmed.hasPrefix("-") || trimmed.hasPrefix("*") {
                currentItems.append(String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces))
            } else {
                currentItems.append(trimmed)
            }
        }

        // Save last section
        if !currentTitle.isEmpty && !currentItems.isEmpty {
            sections.append(ProfileSection(
                title: currentTitle,
                icon: iconForSection(currentTitle),
                items: currentItems
            ))
        }

        // If no sections found (unstructured text), wrap everything in one
        if sections.isEmpty && !digest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let items = lines
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .map { line in
                    if line.hasPrefix("-") || line.hasPrefix("*") {
                        return String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
                    }
                    return line
                }
            sections.append(ProfileSection(title: "Health Summary", icon: "heart.text.square", items: items))
        }

        return sections
    }

    private func iconForSection(_ title: String) -> String {
        let lower = title.lowercased()
        if lower.contains("medication") || lower.contains("drug") { return "pills" }
        if lower.contains("condition") || lower.contains("diagnos") { return "stethoscope" }
        if lower.contains("allerg") { return "exclamationmark.triangle" }
        if lower.contains("concern") || lower.contains("recent") { return "clock" }
        if lower.contains("history") { return "book" }
        if lower.contains("age") || lower.contains("demo") { return "person" }
        return "heart.text.square"
    }
}
