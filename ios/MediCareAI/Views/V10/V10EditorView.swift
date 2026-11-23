import SwiftUI

/// Edit the health profile as plain text, one thing per line, with optional headings.
struct V10EditorView: View {
    @EnvironmentObject private var v10ViewModel: V10ViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var baselineDigest = ""
    @State private var showsDiscardConfirmation = false
    @FocusState private var editorFocused: Bool

    private let maxCharacters = 5000

    private let headings: [(label: String, symbol: String)] = [
        ("Conditions", "stethoscope"),
        ("Medicines", "pills.fill"),
        ("Allergies", "nosign"),
        ("Recent concerns", "waveform.path.ecg"),
        ("About me", "person.fill"),
    ]

    private var count: Int { v10ViewModel.editableDigest.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Write one thing per line. Tap a heading to start a section.")
                    .font(.subheadline)
                    .foregroundStyle(Color.mcInk2)
                    .fixedSize(horizontal: false, vertical: true)

                FlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(headings, id: \.label) { heading in
                        Button {
                            insertHeading(heading.label)
                        } label: {
                            Label(heading.label, systemImage: heading.symbol)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.mcBlueText)
                                .padding(.horizontal, 12)
                                .frame(minHeight: 40)
                                .background(Color.mcBlueTint, in: Capsule())
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Adds this heading to your profile")
                        .accessibilityIdentifier("v10.heading.\(heading.label)")
                    }
                }

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $v10ViewModel.editableDigest)
                        .font(.body)
                        .foregroundStyle(Color.mcInk)
                        .scrollContentBackground(.hidden)
                        .focused($editorFocused)
                        .padding(10)
                        .frame(minHeight: 280)
                        .accessibilityIdentifier("v10.editor")
                        .accessibilityLabel("Your health profile")

                    if v10ViewModel.editableDigest.isEmpty {
                        Text("For example:\nMedicines:\n- Metformin 500 mg with breakfast")
                            .font(.body)
                            .foregroundStyle(Color.mcInk2)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 18)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                .background(Color.mcSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(editorFocused ? Color.mcBlueText : Color.mcLine, lineWidth: editorFocused ? 1.5 : 1)
                )

                Text("\(count) of \(maxCharacters) characters")
                    .font(.footnote)
                    .foregroundStyle(count > maxCharacters ? Color.mcRedText : Color.mcInk2)

                if let error = v10ViewModel.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(Color.mcInk)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.mcAmberTint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button {
                Task {
                    await v10ViewModel.save()
                    if v10ViewModel.errorMessage == nil {
                        dismiss()
                    }
                }
            } label: {
                if v10ViewModel.isSaving {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Save")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(v10ViewModel.isSaving || count > maxCharacters)
            .accessibilityIdentifier("v10.save")
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)
        }
        .mcScreenBackground()
        .navigationTitle("Edit my health")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    if hasUnsavedChanges {
                        showsDiscardConfirmation = true
                    } else {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            baselineDigest = v10ViewModel.editableDigest
            v10ViewModel.errorMessage = nil
        }
        .alert("Discard your changes?", isPresented: $showsDiscardConfirmation) {
            Button("Keep editing", role: .cancel) {}
            Button("Discard", role: .destructive) {
                v10ViewModel.editableDigest = baselineDigest
                dismiss()
            }
        } message: {
            Text("What you changed here will be lost.")
        }
    }

    private var hasUnsavedChanges: Bool {
        v10ViewModel.editableDigest != baselineDigest
    }

    private func insertHeading(_ label: String) {
        let heading = "\(label):\n- "
        let text = v10ViewModel.editableDigest
        if text.isEmpty {
            v10ViewModel.editableDigest = heading
        } else {
            v10ViewModel.editableDigest = text + (text.hasSuffix("\n") ? "\n" : "\n\n") + heading
        }
        editorFocused = true
    }
}
