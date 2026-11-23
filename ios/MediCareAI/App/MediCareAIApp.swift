import SwiftUI

@main
struct MediCareAIApp: App {
    @StateObject private var context = AppContext()

    init() {
        NavigationBarStyle.apply()
    }

    private var forcedColorScheme: ColorScheme? {
        switch UITestHooks.colorScheme {
        case "dark": return .dark
        case "light": return .light
        default: return nil
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(context)
                .environmentObject(context.authViewModel)
                .environmentObject(context.conversationListViewModel)
                .environmentObject(context.v10ViewModel)
                .environmentObject(context.settingsViewModel)
                .preferredColorScheme(forcedColorScheme)
        }
    }
}
