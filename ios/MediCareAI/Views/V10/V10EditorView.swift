import SwiftUI

struct V10EditorView: View {
    @EnvironmentObject private var v10ViewModel: V10ViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var baselineDigest = ""
    @State private var showDiscardConfirmation = false

    private let maxCharacters = 5000

    private let starterChips: [(label: String, template: String)] = [
        ("Medication", "- Medications: "),
        ("Condition", "- Conditions: "),
        ("Allergy", "- Allergies: "),
        ("Recent concern", "- Recent concerns: "),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Guidance header
                    if v10ViewModel.editableDigest.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("What should your health profile include?")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.mcTextPrimary)

                            Text("Add anything that helps personalize your answers: medications you take, conditions you manage, allergies, or recent health concerns.")
                                .font(.callout)
                                .foregroundStyle(Color.mcTextSecondary)
                                .lineSpacing(2)

                            // Starter chips
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(starterChips, id: \.label) { chip in
                                        Button {
                                            insertChip(chip.template)
                                        } label: {
                                            Label(chip.label, systemImage: iconForChip(chip.label))
                                                .font(.caption.weight(.medium))
                                                .foregroundStyle(Color.mcAccent)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(Color.mcAccent.opacity(0.1))
                                                .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .padding(14)
                        .background(Color.mcBackgroundSecondary.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    // Text editor
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $v10ViewModel.editableDigest)
                            .font(.body)
                            .foregroundStyle(Color.mcTextPrimary)
                            .padding(8)
                            .frame(minHeight: 200)
                            .background(Color.mcInputBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .accessibilityIdentifier("v10.editor")

                        if v10ViewModel.editableDigest.isEmpty {
                            Text("Type here or tap a category above to get started...")
                                .font(.body)
                                .foregroundStyle(Color.mcTextSecondary.opacity(0.6))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 16)
                                .allowsHitTesting(false)
                        }
                    }

                    // Character count
                    Text("\(v10ViewModel.editableDigest.count)/\(maxCharacters)")
                        .font(.caption)
                        .foregroundStyle(
                            v10ViewModel.editableDigest.count > maxCharacters
                                ? Color.mcEmergencyRed
                                : Color.mcTextSecondary
                        )
                }
                .padding(16)
            }

            // Save button pinned at bottom
            VStack(spacing: 0) {
                Divider()
                Button {
                    Task { await v10ViewModel.save() }
                } label: {
                    if v10ViewModel.isSaving {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Save Profile").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.mcAccent)
                .controlSize(.large)
                .disabled(v10ViewModel.isSaving || v10ViewModel.editableDigest.count > maxCharacters)
                .accessibilityIdentifier("v10.save")
                .padding(16)
            }
        }
        .background(Color.mcBackground)
        .navigationTitle("Edit Health Profile")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    if hasUnsavedChanges {
                        showDiscardConfirmation = true
                    } else {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            baselineDigest = v10ViewModel.editableDigest
        }
        .alert("Discard unsaved changes?", isPresented: $showDiscardConfirmation) {
            Button("Keep Editing", role: .cancel) {}
            Button("Discard", role: .destructive) {
                v10ViewModel.editableDigest = baselineDigest
                dismiss()
            }
        } message: {
            Text("Your recent edits will be lost.")
        }
    }

    private var hasUnsavedChanges: Bool {
        v10ViewModel.editableDigest != baselineDigest
    }

    private func insertChip(_ template: String) {
        if v10ViewModel.editableDigest.isEmpty {
            v10ViewModel.editableDigest = template
        } else {
            v10ViewModel.editableDigest += "\n" + template
        }
    }

    private func iconForChip(_ label: String) -> String {
        switch label {
        case "Medication": return "pills"
        case "Condition": return "stethoscope"
        case "Allergy": return "exclamationmark.triangle"
        case "Recent concern": return "clock"
        default: return "plus"
        }
    }
}
