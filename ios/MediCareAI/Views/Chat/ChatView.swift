import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var chatViewModel: ChatViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let conversation: Conversation?
    var initialMessage: String?

    @State private var draft = ""
    @State private var isNearBottom = true

    var body: some View {
        ZStack(alignment: .top) {
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
                                activityBanner
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

                            Color.clear.frame(height: 1)
                                .id("bottom")
                                .onAppear { isNearBottom = true }
                                .onDisappear { isNearBottom = false }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 12)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: chatViewModel.messages.count) {
                        if isNearBottom, let last = chatViewModel.messages.last {
                            scroll(proxy: proxy, to: last.id)
                        }
                    }
                    .onChange(of: chatViewModel.streamingText) {
                        if isNearBottom {
                            scroll(proxy: proxy, to: "streaming")
                        }
                    }
                }

                if let errorMessage = chatViewModel.errorMessage {
                    errorCard(errorMessage)
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        .padding(.bottom, 2)
                }

                ChatInputBar(text: $draft, isDisabled: chatViewModel.isStreaming) {
                    Task { await send() }
                }
                .accessibilityLabel("Chat input and send")
            }

            // Toast overlay for profile updates
            if let notice = chatViewModel.profileUpdatedNotice {
                ToastView(message: notice)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(100)
                    .onAppear {
                        Task {
                            try? await Task.sleep(for: .seconds(3))
                            withAnimation(.easeInOut(duration: 0.3)) {
                                chatViewModel.dismissProfileUpdatedNotice()
                            }
                        }
                    }
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

    // Unified activity banner — changes state instead of being two separate cards
    private var activityBanner: some View {
        HStack(spacing: 10) {
            if chatViewModel.isSearching {
                ProgressView()
                    .tint(Color.mcAccent)
            } else {
                Circle()
                    .fill(statusColor.opacity(0.95))
                    .frame(width: 9, height: 9)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.mcTextPrimary)
                Text(statusSubtitle)
                    .font(.caption2)
                    .foregroundStyle(Color.mcTextSecondary)
            }

            Spacer()
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
        .animation(.easeInOut(duration: 0.2), value: chatViewModel.isSearching)
        .animation(.easeInOut(duration: 0.2), value: chatViewModel.isStreaming)
    }

    private var searchingCard: some View {
        HStack(spacing: 10) {
            ProgressView()
                .tint(Color.mcAccent)

            VStack(alignment: .leading, spacing: 2) {
                Text("Searching trusted sources")
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
            return "Writing your answer"
        }
        return "Evidence-backed guidance"
    }

    private var statusSubtitle: String {
        if chatViewModel.isSearching {
            if let query = chatViewModel.searchingQuery, !query.isEmpty {
                return "Looking up: \(query)"
            }
            return "Cross-checking reliable sources..."
        }
        if chatViewModel.isStreaming {
            return "Building a clear response with citations."
        }
        return "Every response is personalized and safety-reviewed."
    }

    private var statusColor: Color {
        if chatViewModel.isSearching { return .mcAccent }
        if chatViewModel.isStreaming { return .mcWarningAmber }
        return .mcSuccessGreen
    }

    private var searchingText: String {
        if let query = chatViewModel.searchingQuery, !query.isEmpty {
            return "Looking up: \(query)"
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
