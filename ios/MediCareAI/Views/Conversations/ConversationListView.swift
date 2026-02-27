import SwiftUI

struct ConversationListView: View {
    @EnvironmentObject private var conversationListViewModel: ConversationListViewModel
    @EnvironmentObject private var chatViewModel: ChatViewModel

    @State private var pendingSuggestion: String?
    @State private var navigateToNewChat = false

    var body: some View {
        List {
            NavigationLink {
                ChatView(conversation: nil)
                    .onAppear { chatViewModel.startNewConversation() }
            } label: {
                Label("Start New Chat", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .accessibilityHint("Starts a new conversation")
            .accessibilityIdentifier("chat.newConversation")

            ForEach(conversationListViewModel.conversations) { conversation in
                NavigationLink {
                    ChatView(conversation: conversation)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(conversation.title)
                            .font(.headline)
                            .lineLimit(1)
                        Text(conversation.lastMessage)
                            .font(.callout)
                            .foregroundStyle(Color.mcTextSecondary)
                            .lineLimit(2)
                    }
                    .padding(.vertical, 6)
                }
                .accessibilityLabel(conversation.title)
                .accessibilityHint("Opens conversation")
                .task {
                    await conversationListViewModel.loadMoreIfNeeded(current: conversation)
                }
            }

            if conversationListViewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }

            if let errorMessage = conversationListViewModel.errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundStyle(Color.mcEmergencyRed)
                    Button("Try Again") {
                        Task { await conversationListViewModel.loadInitial() }
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.vertical, 6)
            }
        }
        .navigationTitle("Chat")
        .overlay {
            if conversationListViewModel.conversations.isEmpty && !conversationListViewModel.isLoading {
                VStack(spacing: 20) {
                    EmptyChatView { suggestion in
                        pendingSuggestion = suggestion
                        navigateToNewChat = true
                    }
                }
                .padding(.bottom, 60)
            }
        }
        .navigationDestination(isPresented: $navigateToNewChat) {
            ChatView(conversation: nil, initialMessage: pendingSuggestion)
                .onAppear { chatViewModel.startNewConversation() }
        }
        .task {
            await conversationListViewModel.loadInitial()
        }
        .refreshable {
            await conversationListViewModel.loadInitial()
        }
    }
}
