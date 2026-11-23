import SwiftUI

/// One conversation. Questions are bubbles on the right; each answer shows its sources,
/// a one-line short answer, the explanation and "Do this" / "Watch for".
struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    @StateObject private var readAloud = ReadAloud()
    @StateObject private var speech = SpeechInput()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let conversation: Conversation?
    let starter: ChatStarter?

    @State private var draft = ""
    @State private var hasStarted = false
    @FocusState private var composerFocused: Bool

    private let streamingID = "chat.streaming"
    private let errorID = "chat.error"

    /// - Parameter viewModel: evaluated once, when the screen first appears.
    init(
        viewModel: @autoclosure @escaping () -> ChatViewModel,
        conversation: Conversation? = nil,
        starter: ChatStarter? = nil
    ) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.conversation = conversation
        self.starter = starter
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if isWelcomeVisible {
                        ChatWelcome(topic: topic) { example in
                            draft = example
                            composerFocused = true
                        }
                    }

                    if isOpeningConversation {
                        HStack(spacing: 10) {
                            HeartbeatActivity()
                            Text("Opening your chat…")
                                .font(.subheadline)
                                .foregroundStyle(Color.mcInk2)
                        }
                    }

                    ForEach(viewModel.messages) { message in
                        Group {
                            switch message.role {
                            case .user:
                                UserBubble(text: message.content)
                            case .assistant:
                                AnswerView(message: message) { viewModel.didTapCitation($0) }
                            }
                        }
                        .id(message.id)
                    }

                    if viewModel.isStreaming {
                        streamingAnswer
                            .id(streamingID)
                    }

                    if let partial = viewModel.interruptedAnswer {
                        AnswerBody(layout: AnswerLayout.parse(partial), onCite: { _ in })
                    }

                    if let error = viewModel.errorMessage {
                        ChatErrorCard(
                            title: errorTitle,
                            message: error,
                            canRetry: viewModel.lastFailedQuestion != nil && !viewModel.isStreaming
                        ) {
                            Task { await viewModel.retryLastFailedQuestion() }
                        }
                        .id(errorID)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .accessibilityIdentifier("screen.chat")
            .onChange(of: viewModel.messages.count) { oldCount, _ in
                // Bring a new question (or a just-opened chat's last question) to the top,
                // so its answer reads from the start. Arriving answers never move the page.
                guard let last = viewModel.messages.last, last.role == .user || oldCount == 0 else { return }
                if let question = viewModel.messages.last(where: { $0.role == .user }) {
                    scroll(proxy, to: question.id, anchor: .top)
                }
            }
            .onChange(of: viewModel.errorMessage) { _, newValue in
                if newValue != nil {
                    scroll(proxy, to: errorID, anchor: .bottom)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            composerBar
        }
        .background(Color.mcSurface.ignoresSafeArea())
        .navigationTitle(conversation?.title ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                listenButton
            }
        }
        .overlay(alignment: .top) {
            profileNotice
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: viewModel.profileUpdatedNotice)
        .sheet(item: $viewModel.selectedCitation) { citation in
            CitationDetailSheet(citation: citation)
        }
        .task {
            await start()
        }
        .onChange(of: speech.transcript) { _, text in
            if !text.isEmpty {
                draft = text
            }
        }
        .onDisappear {
            readAloud.stop()
            speech.stop()
        }
    }

    // MARK: - Parts

    private var streamingAnswer: some View {
        VStack(alignment: .leading, spacing: 14) {
            ChatStatusLine(isWriting: !viewModel.streamingText.isEmpty, query: viewModel.searchingQuery)
            if !viewModel.streamingText.isEmpty {
                AnswerBody(layout: AnswerLayout.parse(viewModel.streamingText, isPartial: true), onCite: { _ in })
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var composerBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            if speech.isListening {
                Text("Listening… Tap stop when you're done.")
                    .font(.footnote)
                    .foregroundStyle(Color.mcInk2)
            } else if let problem = speech.problem {
                Text(problem)
                    .font(.footnote)
                    .foregroundStyle(Color.mcInk2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Composer(
                text: $draft,
                placeholder: viewModel.messages.isEmpty ? topic.placeholder : "Ask a follow-up",
                isBusy: viewModel.isStreaming,
                isListening: speech.isListening,
                focus: $composerFocused,
                onSend: send,
                onMic: { Task { await speech.toggle() } }
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    @ViewBuilder
    private var listenButton: some View {
        if let answer = latestAnswer {
            Button {
                readAloud.toggle(answer.content)
            } label: {
                Label(
                    readAloud.isSpeaking ? "Stop" : "Listen",
                    systemImage: readAloud.isSpeaking ? "stop.fill" : "speaker.wave.2.fill"
                )
                .labelStyle(.titleAndIcon)
            }
            .disabled(viewModel.isStreaming)
            .accessibilityLabel(readAloud.isSpeaking ? "Stop reading aloud" : "Listen to the answer")
            .accessibilityIdentifier("chat.listen")
        }
    }

    @ViewBuilder
    private var profileNotice: some View {
        if let notice = viewModel.profileUpdatedNotice {
            ToastView(message: notice, systemImage: "heart.text.square.fill", tint: .mcCoralInk)
                .padding(.top, 8)
                .padding(.horizontal, 16)
                .transition(.move(edge: .top).combined(with: .opacity))
                .task {
                    try? await Task.sleep(for: .seconds(4))
                    viewModel.dismissProfileUpdatedNotice()
                }
        }
    }

    // MARK: - State

    private var topic: ChatTopic {
        if case .topic(let topic) = starter { return topic }
        return .general
    }

    private var latestAnswer: Message? {
        viewModel.messages.last { $0.role == .assistant }
    }

    private var isWelcomeVisible: Bool {
        conversation == nil && viewModel.messages.isEmpty && !viewModel.isStreaming
            && viewModel.interruptedAnswer == nil && viewModel.errorMessage == nil
    }

    /// The topic welcome with example questions shows only for an empty new chat.
    nonisolated static func showsWelcome(conversation: Conversation?, starter: ChatStarter?, isEmpty: Bool) -> Bool {
        conversation == nil && isEmpty
    }

    private var isOpeningConversation: Bool {
        conversation != nil && viewModel.messages.isEmpty && viewModel.errorMessage == nil
            && !viewModel.isStreaming
    }

    private var errorTitle: String {
        if viewModel.interruptedAnswer != nil { return "This answer was cut off" }
        if viewModel.lastFailedQuestion != nil { return "I couldn't answer that" }
        return "Something went wrong"
    }

    // MARK: - Actions

    private func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        if let conversation {
            viewModel.setConversation(conversation)
            await viewModel.loadConversation(conversationId: conversation.id)
        } else if case .question(let question) = starter {
            Task { await viewModel.sendMessage(question) }
        }
    }

    private func send() {
        let question = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !viewModel.isStreaming else { return }
        speech.stop()
        readAloud.stop()
        draft = ""
        composerFocused = false
        Task { await viewModel.sendMessage(question) }
    }

    private func scroll(_ proxy: ScrollViewProxy, to id: some Hashable, anchor: UnitPoint) {
        if reduceMotion {
            proxy.scrollTo(id, anchor: anchor)
        } else {
            withAnimation(.easeOut(duration: 0.3)) {
                proxy.scrollTo(id, anchor: anchor)
            }
        }
    }
}
