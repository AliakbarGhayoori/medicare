import SwiftUI

/// Every chat, newest first, as an inset grouped list.
struct ConversationListView: View {
    @EnvironmentObject private var context: AppContext
    @EnvironmentObject private var conversationListViewModel: ConversationListViewModel

    @State private var route: ChatRoute?

    var body: some View {
        List {
            Section {
                Button {
                    route = ChatRoute()
                } label: {
                    Label {
                        Text("New chat")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.mcBlueText)
                    } icon: {
                        IconTile(systemName: "square.and.pencil", color: .tileBlue)
                    }
                }
                .frame(minHeight: 44)
                .accessibilityHint("Starts a new chat")
                .accessibilityIdentifier("chat.newConversation")
            }

            if !conversationListViewModel.conversations.isEmpty {
                Section {
                    ForEach(conversationListViewModel.conversations) { conversation in
                        Button {
                            route = ChatRoute(conversation: conversation)
                        } label: {
                            row(for: conversation)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityHint("Opens this chat")
                        .task {
                            await conversationListViewModel.loadMoreIfNeeded(current: conversation)
                        }
                    }
                }
            }

            if conversationListViewModel.isLoading {
                HStack {
                    Spacer()
                    HeartbeatActivity()
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }

            if let errorMessage = conversationListViewModel.errorMessage {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(errorMessage)
                            .font(.body)
                            .foregroundStyle(Color.mcInk)
                        Button("Try again") {
                            Task { await conversationListViewModel.loadInitial() }
                        }
                        .buttonStyle(SecondaryButtonStyle(tint: .mcBlueText))
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .mcScreenBackground()
        .accessibilityIdentifier("screen.pastChats")
        .navigationTitle("Past chats")
        .navigationBarTitleDisplayMode(.large)
        .overlay {
            if conversationListViewModel.conversations.isEmpty
                && !conversationListViewModel.isLoading
                && conversationListViewModel.errorMessage == nil {
                ContentUnavailableView(
                    "No chats yet",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Your questions and answers will show here.")
                )
                .foregroundStyle(Color.mcInk2)
                .padding(.top, 80)
            }
        }
        .navigationDestination(item: $route) { route in
            ChatView(
                viewModel: context.makeChatViewModel(),
                conversation: route.conversation,
                starter: route.starter
            )
        }
        .task {
            await conversationListViewModel.loadInitial()
        }
        .refreshable {
            await conversationListViewModel.loadInitial()
        }
    }

    private func row(for conversation: Conversation) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(conversation.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.mcInk)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                let preview = ChatPreview.text(conversation.lastMessage)
                if !preview.isEmpty {
                    Text(preview)
                        .font(.subheadline)
                        .foregroundStyle(Color.mcInk2)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(DateFormatting.chatDay(conversation.updatedAt))
                .font(.subheadline)
                .foregroundStyle(Color.mcInk2)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.mcInk2)
                .padding(.top, 3)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
