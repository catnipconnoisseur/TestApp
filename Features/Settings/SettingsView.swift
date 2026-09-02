import SwiftUI

/// Settings sheet containing speech language, API key configuration, and developer diagnostics.
/// Accessed via the gear icon on the camera screen.
struct SettingsView: View {
    
    @Binding var selectedLocale: Locale
    @Binding var showDeveloperDiagnostics: Bool
    @State private var apiKeyInput: String = MultimodalConfig.apiKey
    @State private var showQuickAccessGuide = false
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                
                // MARK: - Speech Section
                
                Section {
                    Picker("Language", selection: $selectedLocale) {
                        Text("English").tag(Locale(identifier: "en-US"))
                        Text("Indonesian").tag(Locale(identifier: "id-ID"))
                    }
                    .accessibilityLabel("Speech recognition language")
                    .accessibilityHint("Choose between English and Indonesian for voice input.")
                } header: {
                    Text("Speech")
                } footer: {
                    Text("The language used for voice recognition when you hold and speak.")
                }
                
                // MARK: - Gemini Section
                
                Section {
                    HStack {
                        Text("Status")
                        Spacer()
                        if MultimodalConfig.hasConfiguredKey {
                            Label("Configured", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.subheadline)
                        } else {
                            Label("Not Configured", systemImage: "exclamationmark.circle.fill")
                                .foregroundStyle(.orange)
                                .font(.subheadline)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("API Key status: \(MultimodalConfig.hasConfiguredKey ? "Configured" : "Not configured")")
                    
                    SecureField("Paste API Key", text: $apiKeyInput)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .accessibilityLabel("API Key")
                        .accessibilityHint("Enter your Gemini API key for visual analysis.")
                    
                    if MultimodalConfig.hasConfiguredKey {
                        Button(role: .destructive) {
                            MultimodalConfig.apiKey = ""
                            apiKeyInput = ""
                        } label: {
                            Text("Clear Stored Key")
                        }
                    }
                } header: {
                    Text("AI Visual Analysis")
                } footer: {
                    Text("Your API key is stored locally on this device and is never shared.")
                }
                
                // MARK: - Quick Access Section
                
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(selectedLocale.identifier.hasPrefix("id") ? "Tombol Tindakan & Pintasan" : "Action Button & Shortcuts", systemImage: "button.programmable")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        Text(selectedLocale.identifier.hasPrefix("id")
                             ? "Buka TestApp secara instan tanpa mencari aplikasi di layar utama menggunakan Tombol Tindakan iPhone atau Siri."
                             : "Open TestApp instantly without searching on your Home Screen using your iPhone's Action Button or Siri.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Button {
                            showQuickAccessGuide = true
                        } label: {
                            HStack {
                                Image(systemName: "slider.horizontal.3")
                                Text(selectedLocale.identifier.hasPrefix("id") ? "Panduan Pengaturan Akses Cepat" : "Quick Access Setup Guide")
                            }
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        }
                        .padding(.top, 2)
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(selectedLocale.identifier.hasPrefix("id") ? "Panduan Akses Cepat dan Tombol Tindakan" : "Quick Access and Action Button setup guide")
                } header: {
                    Text(selectedLocale.identifier.hasPrefix("id") ? "Akses Cepat" : "Quick Access")
                } footer: {
                    Text(selectedLocale.identifier.hasPrefix("id")
                         ? "Anda juga dapat mengucapkan 'Hey Siri, Tanya TestApp' dari mana saja."
                         : "You can also say 'Hey Siri, Ask TestApp' from anywhere.")
                }
                
                // MARK: - Developer Section
                
                Section {
                    Toggle("Show Diagnostics on Camera", isOn: $showDeveloperDiagnostics)
                        .accessibilityLabel("Show developer diagnostics")
                        .accessibilityHint("When enabled, technical details appear below the result card on the camera screen.")
                } header: {
                    Text("Developer")
                } footer: {
                    Text("Shows technical diagnostic details such as latency, confidence scores, and recognition data on the camera screen.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        // Save API key on dismiss
                        let trimmed = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed != MultimodalConfig.apiKey {
                            MultimodalConfig.apiKey = trimmed
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showQuickAccessGuide) {
                QuickAccessSetupSheet(isIndonesian: selectedLocale.identifier.hasPrefix("id"))
            }
        }
    }
}

#Preview {
    SettingsView(
        selectedLocale: .constant(Locale(identifier: "en-US")),
        showDeveloperDiagnostics: .constant(false)
    )
}
