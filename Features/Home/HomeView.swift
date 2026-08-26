import SwiftUI

struct HomeView: View {
    
    // MARK: - State
    
    /// Represents the high-level UI state.
    /// Kept intentionally minimal: idle vs. displaying a result.
    enum AppState {
        case idle
        case result(String)
    }
    
    @State private var appState: AppState = .idle
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 32) {
            
            Spacer()
            
            // App Header & Purpose
            headerSection
            
            Spacer()
            
            // Placeholder Result Area (visible only when in result state)
            if case .result(let message) = appState {
                resultSection(message: message)
            }
            
            Spacer()
            
            // Primary Action Button
            identifyButton
            
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Subviews
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "eye.circle")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
                .accessibilityHidden(true) // Decorative icon hidden from VoiceOver
            
            Text("TestApp")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Identify what's in front of you")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        // Combine header texts so VoiceOver reads as a single cohesive unit
        .accessibilityElement(children: .combine)
        .accessibilityLabel("TestApp. Identify what's in front of you.")
    }
    
    private var identifyButton: some View {
        Button {
            // Placeholder action to verify state transition
            appState = .result("Baseline working. Camera not connected yet.")
        } label: {
            Label("Identify", systemImage: "camera.viewfinder")
                .font(.title3)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .accessibilityLabel("Identify")
        .accessibilityHint("Simulates object identification. Camera will be connected in a future ticket.")
    }
    
    private func resultSection(message: String) -> some View {
        Text(message)
            .font(.title2)
            .fontWeight(.medium)
            .multilineTextAlignment(.center)
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
            .accessibilityLabel("Result: \(message)")
    }
}

// MARK: - Preview

#Preview {
    HomeView()
}
