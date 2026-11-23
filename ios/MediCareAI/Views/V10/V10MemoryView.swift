import SwiftUI

/// "My health": what MediCare AI knows about the person, in clear sections.
struct V10MemoryView: View {
    @EnvironmentObject private var v10ViewModel: V10ViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showsEditor = false

    private var digestText: String? {
        guard let text = v10ViewModel.digest?.digest?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return nil }
        return text
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("What MediCare AI knows about you. It uses this to fit every answer to you.")
                    .font(.subheadline)
                    .foregroundStyle(Color.mcInk2)
                    .fixedSize(horizontal: false, vertical: true)

                Group {
                    if let digestText {
                        filled(digestText)
                    } else if v10ViewModel.isLoading {
                        HStack(spacing: 10) {
                            HeartbeatActivity()
                            Text("Loading your profile…")
                                .font(.subheadline)
                                .foregroundStyle(Color.mcInk2)
                        }
                        .padding(.top, 24)
                    } else if let error = v10ViewModel.errorMessage, v10ViewModel.digest == nil {
                        loadFailed(error)
                    } else {
                        empty
                    }
                }
                .padding(.top, 18)

                Label {
                    Text("Only you can see this. Change or delete it any time.")
                } icon: {
                    Image(systemName: "lock.fill")
                }
                .font(.subheadline)
                .foregroundStyle(Color.mcInk2)
                .padding(.top, 18)
                .padding(.horizontal, 4)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 32)
        }
        .mcScreenBackground()
        .accessibilityIdentifier("screen.healthProfile")
        .navigationTitle("My health")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if digestText != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") {
                        showsEditor = true
                    }
                    .accessibilityLabel("Edit my health profile")
                    .accessibilityIdentifier("v10.edit")
                }
            }
        }
        .navigationDestination(isPresented: $showsEditor) {
            V10EditorView()
        }
        .overlay(alignment: .top) {
            if let notice = v10ViewModel.noticeMessage {
                ToastView(message: notice)
                    .padding(.top, 8)
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(for: .seconds(3))
                        v10ViewModel.noticeMessage = nil
                    }
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: v10ViewModel.noticeMessage)
        .task {
            await v10ViewModel.load()
        }
        .refreshable {
            await v10ViewModel.load()
        }
    }

    // MARK: - States

    @ViewBuilder
    private func filled(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let digest = v10ViewModel.digest, let note = ProfileUpdateNote.text(for: digest) {
                updateNote(note, canUndo: digest.canRevert)
            }

            let sections = HealthProfileSections.parse(text)
            if sections.isEmpty {
                Text(text)
                    .font(.body)
                    .foregroundStyle(Color.mcInk)
                    .mcCard()
            } else {
                ForEach(sections) { section in
                    ProfileSectionCard(section: section)
                }
            }
        }
    }

    private func updateNote(_ note: String, canUndo: Bool) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "sparkles")
                .font(.headline)
                .foregroundStyle(Color.mcCoralInk)
                .accessibilityHidden(true)
            Text(note)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.mcCoralInk)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            if canUndo {
                Button {
                    Task { await v10ViewModel.revertToPrevious() }
                } label: {
                    if v10ViewModel.isReverting {
                        ProgressView()
                    } else {
                        Text("Undo")
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .foregroundStyle(Color.mcCoralInk)
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(Color.mcSurface.opacity(0.7), in: Capsule())
                .disabled(v10ViewModel.isReverting)
                .accessibilityLabel("Undo the change from your chat")
                .accessibilityIdentifier("v10.undo")
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .background(Color.mcCoralTint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                IconTile(systemName: "heart.text.square.fill", color: .tileRed, size: 36)
                Text("Nothing here yet")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.mcInk)
            }
            Text("As you chat, MediCare AI notes your conditions, medicines and allergies here. You can also add them yourself.")
                .font(.body)
                .foregroundStyle(Color.mcInk2)
                .fixedSize(horizontal: false, vertical: true)
            Button("Add my details") {
                showsEditor = true
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityIdentifier("v10.setup")
        }
        .mcCard(padding: 18)
    }

    private func loadFailed(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(message)
                .font(.body)
                .foregroundStyle(Color.mcInk)
                .fixedSize(horizontal: false, vertical: true)
            Button("Try again") {
                Task { await v10ViewModel.load() }
            }
            .buttonStyle(SecondaryButtonStyle(tint: .mcBlueText))
        }
        .mcCard()
    }
}

/// One profile section as a Settings-style card: a coloured tile, the title and the items.
private struct ProfileSectionCard: View {
    let section: HealthProfileSections.Section

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                IconTile(systemName: style.symbol, color: style.color)
                Text(section.title)
                    .font(.headline)
                    .foregroundStyle(Color.mcInk)
                    .accessibilityAddTraits(.isHeader)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            ForEach(Array(section.items.enumerated()), id: \.offset) { _, item in
                VStack(alignment: .leading, spacing: 0) {
                    Divider()
                        .overlay(Color.mcLine)
                    Text(item)
                        .font(.body)
                        .foregroundStyle(Color.mcInk)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 11)
                        .padding(.trailing, 14)
                }
                .padding(.leading, 56)
            }
        }
        .padding(.bottom, 2)
        .background(Color.mcSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.mcLine.opacity(0.7), lineWidth: 0.5)
        )
        .accessibilityElement(children: .contain)
    }

    private var style: (symbol: String, color: Color) {
        switch section.kind {
        case .about: return ("person.fill", .tileSlate)
        case .conditions: return ("stethoscope", .tileRed)
        case .medicines: return ("pills.fill", .tileTeal)
        case .allergies: return ("nosign", .tileOrange)
        case .concerns: return ("waveform.path.ecg", .tileViolet)
        case .history: return ("clock.arrow.circlepath", .tileBlue)
        case .other: return ("note.text", .tileGreen)
        }
    }
}
