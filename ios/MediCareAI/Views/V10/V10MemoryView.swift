import SwiftUI

struct V10MemoryView: View {
    @EnvironmentObject private var v10ViewModel: V10ViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if v10ViewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                if let digest = v10ViewModel.digest?.digest, !digest.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            // Digest content card
                            VStack(alignment: .leading, spacing: 12) {
                                let lines = digest.components(separatedBy: .newlines)
                                ForEach(0..<lines.count, id: \.self) { index in
                                    let line = lines[index]
                                    if line.starts(with: "#") {
                                        Text(line.replacingOccurrences(of: "#", with: "").trimmingCharacters(in: .whitespaces))
                                            .font(.title3)
                                            .bold()
                                            .foregroundStyle(Color.mcTextPrimary)
                                            .padding(.top, 4)
                                    } else if line.starts(with: "-") || line.starts(with: "*") {
                                        HStack(alignment: .top) {
                                            Text("\u{2022}")
                                                .font(.body)
                                                .foregroundStyle(Color.mcTextPrimary)
                                            Text(line.dropFirst().trimmingCharacters(in: .whitespaces))
                                                .font(.body)
                                                .foregroundStyle(Color.mcTextPrimary)
                                        }
                                    } else if !line.isEmpty {
                                        Text(line)
                                            .font(.body)
                                            .foregroundStyle(Color.mcTextPrimary)
                                    }
                                }
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.mcBackgroundSecondary)
                            )

                            // Metadata footer card
                            if v10ViewModel.digest?.updatedAt != nil || v10ViewModel.digest?.lastUpdateSource != nil {
                                VStack(alignment: .leading, spacing: 6) {
                                    if let updatedAt = v10ViewModel.digest?.updatedAt {
                                        HStack(spacing: 6) {
                                            Image(systemName: "clock")
                                                .font(.footnote)
                                                .foregroundStyle(Color.mcTextSecondary)
                                            Text("Updated: \(DateFormatting.longDateTime.string(from: updatedAt))")
                                                .font(.footnote)
                                                .foregroundStyle(Color.mcTextSecondary)
                                        }
                                    }

                                    if let source = v10ViewModel.digest?.lastUpdateSource {
                                        HStack(spacing: 6) {
                                            Image(systemName: source == "auto" ? "cpu" : "pencil")
                                                .font(.footnote)
                                                .foregroundStyle(Color.mcTextSecondary)
                                            Text(source == "auto" ? "Updated by: Assistant" : "Updated by: You")
                                                .font(.footnote)
                                                .foregroundStyle(Color.mcTextSecondary)
                                        }
                                    }
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.mcBackgroundSecondary)
                                )
                            }

                            if v10ViewModel.digest?.canRevert == true {
                                Button {
                                    Task { await v10ViewModel.revertToPrevious() }
                                } label: {
                                    if v10ViewModel.isReverting {
                                        ProgressView()
                                            .frame(maxWidth: .infinity)
                                    } else {
                                        Text("Restore Previous Version")
                                            .frame(maxWidth: .infinity)
                                    }
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                    }
                } else {
                    // Empty state
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "heart.text.square")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.mcAccent)

                        Text("Your Health Profile Is Empty")
                            .font(.title3)
                            .bold()
                            .foregroundStyle(Color.mcTextPrimary)

                        Text("Add your conditions, medications, and allergies so answers can be tailored to you.")
                            .font(.body)
                            .foregroundStyle(Color.mcTextSecondary)
                            .multilineTextAlignment(.center)

                        NavigationLink {
                            V10EditorView()
                        } label: {
                            Text("Create Health Profile")
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

                if let notice = v10ViewModel.noticeMessage {
                    Text(notice)
                        .font(.callout)
                        .foregroundStyle(Color.mcSuccessGreen)
                        .padding(.horizontal, 16)
                }

                if let errorMessage = v10ViewModel.errorMessage {
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundStyle(Color.mcEmergencyRed)
                        .padding(.horizontal, 16)
                }
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
}
