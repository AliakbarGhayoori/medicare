import SwiftUI

@main
struct MediCareAIApp: App {
    @StateObject private var context = AppContext()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(context)
                .environmentObject(context.authViewModel)
                .environmentObject(context.chatViewModel)
                .environmentObject(context.conversationListViewModel)
                .environmentObject(context.v10ViewModel)
                .environmentObject(context.settingsViewModel)
        }
    }
}
