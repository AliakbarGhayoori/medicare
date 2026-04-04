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
                .fill(Color.mcAccent.opacity(0.06))
                .frame(width: 220, height: 220)
                .offset(x: 50, y: -90)
        }
        .ignoresSafeArea()
    }

    // Single activity banner that changes state
    private var activityBanner: some View {
        HStack(spacing: 10) {
            if chatViewModel.isSearching || (chatViewModel.isStreaming && chatViewModel.streamingText.isEmpty) {
                ProgressView()
                    .tint(Color.mcAccent)
            } else {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
            }

            Text(statusText)
                .font(.caption)
                .foregroundStyle(Color.mcTextSecondary)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Color.mcBackgroundSecondary.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .animation(.easeInOut(duration: 0.25), value: chatViewModel.isSearching)
        .animation(.easeInOut(duration: 0.25), value: chatViewModel.isStreaming)
    }

    private var statusText: String {
        if chatViewModel.isSearching {
            if let query = chatViewModel.searchingQuery, !query.isEmpty {
                return "Searching: \(query)"
            }
            return "Searching trusted sources..."
        }
        if chatViewModel.isStreaming {
            return "Writing your answer..."
        }
        return "Evidence-backed, personalized guidance"
    }

    private var statusColor: Color {
        if chatViewModel.isStreaming { return .mcWarningAmber }
        return .mcSuccessGreen
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
