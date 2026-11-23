import SwiftUI

@main
struct MediCareAIApp: App {
    @StateObject private var context = AppContext()

    init() {
        NavigationBarStyle.apply()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(context)
                .environmentObject(context.authViewModel)
                .environmentObject(context.conversationListViewModel)
                .environmentObject(context.v10ViewModel)
                .environmentObject(context.settingsViewModel)
        }
    }
}
