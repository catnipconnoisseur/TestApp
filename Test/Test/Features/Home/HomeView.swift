import SwiftUI

struct HomeView: View {
    
    // MARK: - State
    
    @State private var isPresentingCamera = false
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 32) {
            
            Spacer()
            
            // App Header & Purpose
            headerSection
            
            Spacer()
            
            // Instructions / Info Card
            infoCardSection
            
            Spacer()
            
            // Primary Action Button
            identifyButton
            
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .fullScreenCover(isPresented: $isPresentingCamera) {
            CameraView()
        }
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
    
    private var infoCardSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "camera.viewfinder")
                .font(.title)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            
            Text("Live Visual Input")
                .font(.headline)
            
            Text("Point your camera at an object or banknote to view the live preview.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .accessibilityElement(children: .combine)
    }
    
    private var identifyButton: some View {
        Button {
            isPresentingCamera = true
        } label: {
            Label("Open Camera", systemImage: "camera.fill")
                .font(.title3)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .accessibilityLabel("Open Camera")
        .accessibilityHint("Opens the full-screen camera preview to capture visual input.")
    }
}

// MARK: - Preview

#Preview {
    HomeView()
}
