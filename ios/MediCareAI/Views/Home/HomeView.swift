import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var chatViewModel: ChatViewModel
    @EnvironmentObject private var conversationListViewModel: ConversationListViewModel
    @EnvironmentObject private var v10ViewModel: V10ViewModel

    @State private var navigateToChat = false
    @State private var pendingMessage: String?
    @State private var showAllConversations = false

    private let quickActions: [(icon: String, label: String, prompt: String)] = [
        ("waveform.path.ecg", "Check a symptom", "I've been experiencing "),
        ("pills.fill", "Medication question", "I want to ask about my medication: "),
        ("figure.run", "Exercise plan", "Can you suggest an exercise plan for me?"),
        ("fork.knife", "Nutrition advice", "What foods would be good for me?"),
        ("moon.zzz.fill", "Sleep help", "I've been having trouble sleeping. "),
        ("heart.text.square", "Understand a condition", "Can you explain what this condition means: ")
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                greetingSection
                mainCTACard
                quickActionsSection
                profileSummaryCard
                recentConversationsSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(
            LinearGradient(
                colors: [Color.mcBackground, Color.mcBackgroundSecondary.opacity(0.4)],
                startPoint: .top,
                endPoint: .bottom
            )
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(Color.mcAccent.opacity(0.06))
                    .frame(width: 260, height: 260)
                    .offset(x: 80, y: -100)
            }
            .ignoresSafeArea()
        )
        .navigationTitle("MediCare AI")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(isPresented: $navigateToChat) {
            ChatView(conversation: nil, initialMessage: pendingMessage)
                .onAppear { chatViewModel.startNewConversation() }
        }
        .navigationDestination(isPresented: $showAllConversations) {
            ConversationListView()
        }
        .task {
            await conversationListViewModel.loadInitial()
            await v10ViewModel.load()
        }
        .refreshable {
            await conversationListViewModel.loadInitial()
            await v10ViewModel.load()
        }
    }

    // MARK: - Greeting

    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(timeGreeting)
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.mcTextPrimary)

            Text("How are you feeling today?")
                .font(.body)
                .foregroundStyle(Color.mcTextSecondary)
        }
        .padding(.top, 8)
    }

    private var timeGreeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let name = userName

        if hour < 12 {
            return "Good morning, \(name)"
        } else if hour < 17 {
            return "Good afternoon, \(name)"
        } else {
            return "Good evening, \(name)"
        }
    }

    private var userName: String {
        guard let email = authViewModel.currentEmail else { return "there" }
        let local = email.components(separatedBy: "@").first ?? "there"
        return local.capitalized
    }

    // MARK: - Main CTA

    private var mainCTACard: some View {
        Button {
            pendingMessage = nil
            navigateToChat = true
        } label: {
            VStack(spacing: 16) {
                Image("home-hero")
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 120)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityHidden(true)

                VStack(spacing: 6) {
                    Text("Talk to MediCare AI")
                        .font(.headline)
                        .foregroundStyle(Color.mcTextPrimary)
                    Text("Ask anything about your health")
                        .font(.subheadline)
                        .foregroundStyle(Color.mcTextSecondary)
                }

                Image(systemName: "arrow.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.mcAccent)
            }
            .padding(20)
            .background(Color.mcBackgroundSecondary.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Quick start")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.mcTextSecondary)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ], spacing: 10) {
                ForEach(quickActions, id: \.label) { action in
                    Button {
                        pendingMessage = action.prompt
                        navigateToChat = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: action.icon)
                                .font(.callout)
                                .foregroundStyle(Color.mcAccent)
                                .frame(width: 24)

                            Text(action.label)
                                .font(.callout)
                                .foregroundStyle(Color.mcTextPrimary)
                                .lineLimit(1)

                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 13)
                        .background(Color.mcBackgroundSecondary.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Profile Summary

    @ViewBuilder
    private var profileSummaryCard: some View {
        if let digest = v10ViewModel.digest, let text = digest.digest, !text.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Your health profile", systemImage: "heart.text.square.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.mcTextSecondary)
                    Spacer()
                    NavigationLink {
                        V10MemoryView()
                    } label: {
                        Text("View")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.mcAccent)
                    }
                }

                Text(profilePreview(text))
                    .font(.callout)
                    .foregroundStyle(Color.mcTextPrimary)
                    .lineLimit(3)
                    .lineSpacing(2)
            }
            .padding(16)
            .background(Color.mcBackgroundSecondary.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else if !v10ViewModel.isLoading {
            VStack(alignment: .leading, spacing: 10) {
                Label("Build your health profile", systemImage: "heart.text.square")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.mcTextPrimary)

                Text("Start a conversation and your conditions, medications, and concerns will be remembered automatically.")
                    .font(.callout)
                    .foregroundStyle(Color.mcTextSecondary)
                    .lineSpacing(2)
            }
            .padding(16)
            .background(Color.mcBackgroundSecondary.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func profilePreview(_ text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }

        let preview = lines.prefix(4).joined(separator: "\n")
        if preview.count > 200 {
            return String(preview.prefix(200)) + "..."
        }
        return preview
    }

    // MARK: - Recent Conversations

    @ViewBuilder
    private var recentConversationsSection: some View {
        let recent = Array(conversationListViewModel.conversations.prefix(3))

        if !recent.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Recent conversations")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.mcTextSecondary)
                    Spacer()
                    if conversationListViewModel.conversations.count > 3 {
                        Button {
                            showAllConversations = true
                        } label: {
                            Text("See all")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color.mcAccent)
                        }
                    }
                }

                VStack(spacing: 6) {
                    ForEach(recent) { conversation in
                        NavigationLink {
                            ChatView(conversation: conversation)
                        } label: {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color.mcAccent.opacity(0.1))
                                    .frame(width: 34, height: 34)
                                    .overlay(
                                        Image(systemName: "message.fill")
                                            .font(.caption2)
                                            .foregroundStyle(Color.mcAccent)
                                    )

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(conversation.title)
                                        .font(.callout.weight(.medium))
                                        .foregroundStyle(Color.mcTextPrimary)
                                        .lineLimit(1)

                                    Text(conversation.lastMessage)
                                        .font(.caption)
                                        .foregroundStyle(Color.mcTextSecondary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Color.mcTextSecondary.opacity(0.4))
                            }
                            .padding(12)
                            .background(Color.mcBackgroundSecondary.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
