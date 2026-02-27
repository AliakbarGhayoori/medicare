import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var chatViewModel: ChatViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let conversation: Conversation?
    var initialMessage: String?

    @State private var draft = ""

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if chatViewModel.messages.isEmpty && !chatViewModel.isStreaming {
                                EmptyChatView { suggestion in
                                    draft = suggestion
                                    Task { await send() }
                                }
                            } else {
                                sessionStatusCard
                            }

                            ForEach(Array(chatViewModel.messages.enumerated()), id: \.element.id) { index, message in
                                VStack(alignment: .leading, spacing: 8) {
                                    if message.requiresEmergencyCare {
                                        EmergencyBannerView()
                                    }
                                    MessageBubbleView(message: message) { citation in
                                        chatViewModel.didTapCitation(citation)
                                    }
                                }
                                .padding(.top, messagePadding(at: index))
                                .id(message.id)
                                .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
                            }

                            if chatViewModel.isSearching {
                                searchingCard
                            }

                            if chatViewModel.isStreaming && !chatViewModel.streamingText.isEmpty {
                                StreamingTextView(text: chatViewModel.streamingText)
                                    .padding(.top, 10)
                                    .id("streaming")
                            }

                            if chatViewModel.isStreaming && chatViewModel.streamingText.isEmpty && !chatViewModel.isSearching {
                                TypingIndicatorView()
                                    .padding(.top, 10)
                                    .id("typing")
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 12)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: chatViewModel.messages.count) {
                        if let last = chatViewModel.messages.last {
                            scroll(proxy: proxy, to: last.id)
                        }
                    }
                    .onChange(of: chatViewModel.streamingText) {
                        scroll(proxy: proxy, to: "streaming")
                    }
                }

                if let errorMessage = chatViewModel.errorMessage {
                    errorCard(errorMessage)
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        .padding(.bottom, 2)
                }

                if let notice = chatViewModel.profileUpdatedNotice {
                    profileNoticeCard(notice)
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        .padding(.bottom, 2)
                }

                Text("MediCare AI shares health information and does not replace medical care.")
                    .font(.caption2)
                    .foregroundStyle(Color.mcTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)

                ChatInputBar(text: $draft, isDisabled: chatViewModel.isStreaming) {
                    Task { await send() }
                }
                .accessibilityLabel("Chat input and send")
            }
        }
        .navigationTitle(conversation?.title ?? "New Chat")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $chatViewModel.selectedCitation) { citation in
            CitationDetailSheet(citation: citation)
        }
        .task {
            if let conversation {
                await chatViewModel.loadConversation(conversationId: conversation.id)
            } else {
                chatViewModel.startNewConversation()
            }
            if let initialMessage, !initialMessage.isEmpty {
                draft = initialMessage
                Task { await send() }
            }
        }
    }

    @ViewBuilder
    private func errorCard(_ errorMessage: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Could not complete your request", systemImage: "exclamationmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.mcEmergencyRed)

            Text(errorMessage)
                .font(.callout)
                .foregroundStyle(Color.mcTextSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if chatViewModel.lastFailedQuestion != nil {
                Button("Try That Question Again") {
                    Task { await chatViewModel.retryLastFailedQuestion() }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.mcAccent)
                .font(.callout.weight(.semibold))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.mcBackgroundSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.mcEmergencyRed.opacity(0.25), lineWidth: 1)
        )
    }

    private func profileNoticeCard(_ notice: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.mcSuccessGreen)
            Text(notice)
                .font(.callout)
                .foregroundStyle(Color.mcTextSecondary)
            Spacer()
            Button("Dismiss") {
                chatViewModel.dismissProfileUpdatedNotice()
            }
            .font(.callout)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.mcBackgroundSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.mcInputBorder.opacity(0.7), lineWidth: 1)
        )
    }

    private var backgroundLayer: some View {
        LinearGradient(
            colors: [
                Color.mcBackground,
                Color.mcBackgroundSecondary.opacity(0.5)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(Color.mcAccent.opacity(0.08))
                .frame(width: 220, height: 220)
                .offset(x: 50, y: -90)
        }
        .ignoresSafeArea()
    }

    private var sessionStatusCard: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(statusColor.opacity(0.95))
                .frame(width: 9, height: 9)

            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.mcTextPrimary)
                Text(statusSubtitle)
                    .font(.caption2)
                    .foregroundStyle(Color.mcTextSecondary)
            }

            Spacer()

            Text("LIVE")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.mcAccent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.mcAccent.opacity(0.14))
                )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.mcBackgroundSecondary.opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.mcInputBorder.opacity(0.75), lineWidth: 1)
        )
    }

    private var searchingCard: some View {
        HStack(spacing: 10) {
            ProgressView()
                .tint(Color.mcAccent)

            VStack(alignment: .leading, spacing: 2) {
                Text("Reviewing trusted medical sources")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.mcTextPrimary)
                Text(searchingText)
                    .font(.caption2)
                    .foregroundStyle(Color.mcTextSecondary)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.mcBackgroundSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.mcInputBorder.opacity(0.75), lineWidth: 1)
        )
    }

    private var statusTitle: String {
        if chatViewModel.isSearching {
            return "Checking evidence"
        }
        if chatViewModel.isStreaming {
            return "Drafting your answer"
        }
        return "Evidence-backed guidance"
    }

    private var statusSubtitle: String {
        if chatViewModel.isSearching {
            return "Cross-checking reliable sources for your question."
        }
        if chatViewModel.isStreaming {
            return "Building a clear response with safety checks."
        }
        return "Every response is tailored and safety-reviewed."
    }

    private var statusColor: Color {
        if chatViewModel.isSearching { return .mcAccent }
        if chatViewModel.isStreaming { return .mcWarningAmber }
        return .mcSuccessGreen
    }

    private var searchingText: String {
        if let tool = chatViewModel.searchingTool, !tool.isEmpty {
            return "Tool in use: \(tool)"
        }
        return "Checking trusted medical sources..."
    }

    private func send() async {
        let message = draft
        draft = ""
        await chatViewModel.sendMessage(message)
    }

    private func scroll(proxy: ScrollViewProxy, to id: some Hashable) {
        if reduceMotion {
            proxy.scrollTo(id, anchor: .bottom)
        } else {
            withAnimation {
                proxy.scrollTo(id, anchor: .bottom)
            }
        }
    }

    private func messagePadding(at index: Int) -> CGFloat {
        guard index > 0 else { return 0 }
        let current = chatViewModel.messages[index]
        let previous = chatViewModel.messages[index - 1]
        return current.role == previous.role ? 6 : 12
    }
}
