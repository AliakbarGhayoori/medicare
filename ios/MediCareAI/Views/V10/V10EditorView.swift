import SwiftUI

struct V10EditorView: View {
    @EnvironmentObject private var v10ViewModel: V10ViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var baselineDigest = ""
    @State private var showDiscardConfirmation = false

    private let maxCharacters = 5000

    var body: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $v10ViewModel.editableDigest)
                    .font(.body)
                    .foregroundStyle(Color.mcTextPrimary)
                    .padding(8)
                    .background(Color.mcInputBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.mcInputBorder, lineWidth: 1)
                    }
                    .accessibilityIdentifier("v10.editor")

                if v10ViewModel.editableDigest.isEmpty {
                    Text("Share your conditions, medications, allergies, and anything else your care team should know.")
                        .font(.body)
                        .foregroundStyle(Color.mcTextSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
            }

            HStack {
                Text("\(v10ViewModel.editableDigest.count)/\(maxCharacters)")
                    .font(.caption)
                    .foregroundStyle(
                        v10ViewModel.editableDigest.count > maxCharacters
                            ? Color.mcEmergencyRed
                            : Color.mcTextSecondary
                    )
                Spacer()
            }

            Button {
                Task {
                    await v10ViewModel.save()
                }
            } label: {
                if v10ViewModel.isSaving {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Save Profile")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.mcAccent)
            .controlSize(.large)
            .disabled(v10ViewModel.isSaving || v10ViewModel.editableDigest.count > maxCharacters)
            .accessibilityIdentifier("v10.save")

            if let notice = v10ViewModel.noticeMessage {
                Text(notice)
                    .font(.callout)
                    .foregroundStyle(Color.mcSuccessGreen)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let error = v10ViewModel.errorMessage {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(Color.mcEmergencyRed)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
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
}
