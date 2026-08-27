import Foundation

/// Manages local configuration and secure local storage for the multimodal API key.
/// Never hardcodes API keys in tracked source control.
enum MultimodalConfig {
    
    private static let keyStorageKey = "com.testapp.multimodal.apiKey"
    
    /// Retrieves the active API key from local Secrets file (gitignored), local UserDefaults, or Info.plist.
    static var apiKey: String {
        get {
            // 1. Check gitignored local Secrets file if present
            #if canImport(Foundation)
            if let secretsClass = NSClassFromString("TestApp.Secrets") as? AnyObject.Type {
                // If Secrets struct exists
            }
            #endif
            
            // Check compiled local Secrets struct
            if !Secrets.apiKey.isEmpty {
                return Secrets.apiKey
            }
            
            // 2. Check local UserDefaults storage (configured via 🔑 button)
            if let stored = UserDefaults.standard.string(forKey: keyStorageKey), !stored.isEmpty {
                return stored
            }
            
            // 3. Check Info.plist environment
            if let plistKey = Bundle.main.infoDictionary?["MULTIMODAL_API_KEY"] as? String,
               !plistKey.isEmpty,
               plistKey != "$(MULTIMODAL_API_KEY)" {
                return plistKey
            }
            
            return ""
        }
        set {
            UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: keyStorageKey)
        }
    }
    
    static var hasConfiguredKey: Bool {
        !apiKey.isEmpty
    }
}
