import Foundation
import AppIntents

/// App Intent enabling quick access to TestApp via the Action Button, Siri, Spotlight, and Shortcuts.
@available(iOS 16.0, *)
struct QuickAccessIntent: AppIntent {
    static var title: LocalizedStringResource = "Ask TestApp"
    static var description = IntentDescription("Open TestApp to ask a question about what the camera sees.")
    
    // Directs the system to immediately foreground the application
    static var openAppWhenRun: Bool = true
    
    @MainActor
    func perform() async throws -> some IntentResult {
        // Record that this launch/foreground was triggered via Quick Access / Action Button
        UserDefaults.standard.set(true, forKey: "launchedFromQuickAccess")
        return .result()
    }
}

/// Exposes TestApp shortcuts automatically to Siri, Spotlight, Shortcuts app, and Action Button configuration.
@available(iOS 16.0, *)
struct TestAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: QuickAccessIntent(),
            phrases: [
                "Ask \(.applicationName)",
                "Open \(.applicationName)",
                "What do I see with \(.applicationName)",
                "Tanya \(.applicationName)",
                "Buka \(.applicationName)"
            ],
            shortTitle: "Ask TestApp",
            systemImageName: "eye"
        )
    }
}
