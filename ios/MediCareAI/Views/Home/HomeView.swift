import SwiftUI

/// The first screen: a greeting, one big field to ask in, topics to start from and the
/// latest chats. The local emergency number is always in the corner.
struct HomeView: View {
    @EnvironmentObject private var context: AppContext
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var conversationListViewModel: ConversationListViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @StateObject private var speech = SpeechInput()
    @State private var question = ""
    @State private var route: ChatRoute?
    @State private var showsAllChats = false
    @FocusState private var askFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                TimelineView(.everyMinute) { timeline in
                    VStack(alignment: .leading, spacing: 14) {
                        header(date: timeline.date)
                        greeting(date: timeline.date)
                    }
                }

                askField
                    .padding(.top, 20)

                Text("Every answer names its sources.")
                    .font(.subheadline)
                    .foregroundStyle(Color.mcInk2)
                    .padding(.top, 8)
                    .padding(.leading, 18)

                if let problem = speech.problem {
                    Text(problem)
                        .font(.footnote)
                        .foregroundStyle(Color.mcInk2)
                        .padding(.top, 6)
                        .padding(.leading, 18)
                        .fixedSize(horizontal: false, vertical: true)
                }

                SectionHeading(text: "Start with a topic")
                    .padding(.top, 28)
                    .padding(.bottom, 10)
                topics

                recentChats
                    .padding(.top, 28)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .mcScreenBackground()
        .accessibilityIdentifier("screen.home")
        .navigationTitle("Home")
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $route) { route in
            ChatView(
                viewModel: context.makeChatViewModel(),
                conversation: route.conversation,
                starter: route.starter
            )
        }
        .navigationDestination(isPresented: $showsAllChats) {
            ConversationListView()
        }
        .task {
            await conversationListViewModel.loadInitial()
        }
        .refreshable {
            await conversationListViewModel.loadInitial()
        }
        .onChange(of: speech.transcript) { _, text in
            if !text.isEmpty {
                question = text
            }
        }
        .onDisappear {
            speech.stop()
        }
    }

    // MARK: - Top

    private func header(date: Date) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(date, format: .dateTime.weekday(.wide).day().month(.wide))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.mcInk2)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 8)
            EmergencyPill(number: EmergencyNumber.current)
        }
    }

    private func greeting(date: Date) -> some View {
        let hour = Calendar.current.component(.hour, from: date)
        let base = Greeting.text(hour: hour, firstName: nil)
        let name = Greeting.cleanedFirstName(authViewModel.firstName)
        return VStack(alignment: .leading, spacing: 2) {
            Text(name == nil ? base : base + ",")
            HStack(alignment: .lastTextBaseline, spacing: 10) {
                if let name {
                    Text(name)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                HeartbeatLine(variant: .flourish, lineWidth: 2.5, drawsIn: true)
                    .frame(width: 96, height: 22)
                    .alignmentGuide(.lastTextBaseline) { dimensions in dimensions[.bottom] - 4 }
            }
        }
        .font(.mcDisplay(40, relativeTo: .largeTitle))
        .foregroundStyle(Color.mcInk)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Greeting.text(hour: hour, firstName: authViewModel.firstName))
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("home.greeting")
    }

    // MARK: - Ask

    private var askField: some View {
        Composer(
            text: $question,
            placeholder: "Ask a health question",
            isBusy: false,
            isListening: speech.isListening,
            focus: $askFocused,
            idPrefix: "home",
            raised: true,
            onSend: ask,
            onMic: { Task { await speech.toggle() } }
        )
    }

    private func ask() {
        let text = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        speech.stop()
        askFocused = false
        question = ""
        route = ChatRoute(starter: .question(text))
    }

    // MARK: - Topics

    private var topics: some View {
        let columns = dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(ChatTopic.all) { topic in
                Button {
                    route = ChatRoute(starter: .topic(topic))
                } label: {
                    VStack(alignment: .leading, spacing: 12) {
                        IconTile(systemName: topic.systemImage, color: topic.tint, size: 30)
                        Text(topic.title)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.mcInk)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
                    .background(Color.mcSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.mcLine.opacity(0.7), lineWidth: 0.5)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(topic.title)
                .accessibilityHint("Opens a new chat with example questions")
                .accessibilityIdentifier("home.topic.\(topic.id)")
            }
        }
    }

    // MARK: - Recent

    @ViewBuilder
    private var recentChats: some View {
        let recent = Array(conversationListViewModel.conversations.prefix(3))
        if !recent.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    SectionHeading(text: "Recent")
                    Button("See all") {
                        showsAllChats = true
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.mcBlueText)
                    .frame(minHeight: 44)
                    .accessibilityLabel("See all chats")
                    .accessibilityIdentifier("home.seeAll")
                }

                VStack(spacing: 0) {
                    ForEach(Array(recent.enumerated()), id: \.element.id) { index, conversation in
                        if index > 0 {
                            Divider()
                                .overlay(Color.mcLine)
                                .padding(.leading, 16)
                        }
                        Button {
                            route = ChatRoute(conversation: conversation)
                        } label: {
                            HStack(spacing: 10) {
                                Text(conversation.title)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(Color.mcInk)
                                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(DateFormatting.chatDay(conversation.updatedAt))
                                    .font(.subheadline)
                                    .foregroundStyle(Color.mcInk2)
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(Color.mcInk2)
                                    .accessibilityHidden(true)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .frame(minHeight: 50)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                        .accessibilityHint("Opens this chat")
                        .accessibilityIdentifier("home.recent.\(index)")
                    }
                }
                .background(Color.mcSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.mcLine.opacity(0.7), lineWidth: 0.5)
                )
            }
        }
    }
}
