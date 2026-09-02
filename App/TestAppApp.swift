import AppIntents
import SwiftUI

@main
struct TestAppApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    init() {
        // Index shortcuts with Siri and Action Button on app launch
        TestAppShortcuts.updateAppShortcutParameters()
    }
    
    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                CameraView()
            } else {
                WelcomeView(hasCompletedOnboarding: $hasCompletedOnboarding)
            }
        }
    }
}

