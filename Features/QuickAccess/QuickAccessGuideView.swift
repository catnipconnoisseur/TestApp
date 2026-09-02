import AppIntents
import SwiftUI
import UIKit

// MARK: - Reusable Quick Access Setup & Guide View

/// Reusable sheet and card providing step-by-step guidance for configuring the iPhone Action Button, Siri, and Shortcuts.
/// Used in both WelcomeView (first-launch onboarding) and SettingsView (settings sheet).
struct QuickAccessSetupSheet: View {
    
    let isIndonesian: Bool
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasCompletedQuickAccessSetup") private var hasCompletedQuickAccessSetup = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                
                // Header Icon & Title
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.12))
                            .frame(width: 56, height: 56)
                        
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.blue)
                    }
                    .accessibilityHidden(true)
                    
                    Text(isIndonesian ? "Atur Akses Cepat" : "Set Up Quick Access")
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    
                    Text(isIndonesian
                         ? "Buka TestApp secara instan dengan Tombol Tindakan iPhone."
                         : "Open TestApp instantly with your iPhone's Action Button.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                }
                .padding(.top, 4)
                
                // Step-by-Step Setup Guide
                VStack(alignment: .leading, spacing: 12) {
                    setupStepRow(
                        stepNumber: "1",
                        title: isIndonesian ? "Buka Pengaturan iPhone" : "Open iPhone Settings",
                        detail: isIndonesian ? "Pilih menu 'Tombol Tindakan' (Action Button)." : "Tap the 'Action Button' menu in Settings."
                    )
                    
                    setupStepRow(
                        stepNumber: "2",
                        title: isIndonesian ? "Geser ke Pintasan" : "Swipe to Shortcut",
                        detail: isIndonesian ? "Pilih opsi 'Pintasan' (Shortcut)." : "Swipe to select the 'Shortcut' option."
                    )
                    
                    setupStepRow(
                        stepNumber: "3",
                        title: isIndonesian ? "Pilih Ask TestApp" : "Choose Ask TestApp",
                        detail: isIndonesian ? "Pilih pintasan 'Ask TestApp' atau 'Buka TestApp'." : "Choose the 'Ask TestApp' shortcut or 'Open TestApp'."
                    )
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemBackground))
                )
                
                // Compact Privacy & Agency Guarantee
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                    
                    Text(isIndonesian
                         ? "Akses Cepat hanya membuka kamera. Mikrofon tidak merekam otomatis."
                         : "Quick Access only opens the camera. Mic never records automatically.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
                .accessibilityElement(children: .combine)
                
                Spacer(minLength: 8)
                
                // Action Buttons
                VStack(spacing: 10) {
                    Button {
                        dismiss()
                    } label: {
                        Text(isIndonesian ? "Mengerti" : "Got It")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityLabel(isIndonesian ? "Mengerti" : "Got It")
                    .accessibilityHint(isIndonesian ? "Menutup panduan pengaturan akses cepat." : "Closes the quick access setup guide.")
                    
                    // Reset / Uncheck Option if already configured
                    if hasCompletedQuickAccessSetup {
                        Button(role: .destructive) {
                            hasCompletedQuickAccessSetup = false
                            dismiss()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.counterclockwise")
                                Text(isIndonesian ? "Tandai Belum Diatur (Atur Ulang)" : "Mark as Not Configured (Reset)")
                            }
                            .font(.caption)
                            .fontWeight(.medium)
                        }
                        .padding(.top, 2)
                        .accessibilityLabel(isIndonesian ? "Tandai Belum Diatur" : "Mark as Not Configured")
                        .accessibilityHint(isIndonesian ? "Membatalkan tanda bahwa Akses Cepat telah diatur." : "Unchecks the Quick Access setup status.")
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
            .navigationTitle(isIndonesian ? "Akses Cepat" : "Quick Access")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isIndonesian ? "Tutup" : "Close") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    // MARK: - Setup Step Row Helper
    
    private func setupStepRow(stepNumber: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 28, height: 28)
                
                Text(stepNumber)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.bold)
                
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(isIndonesian ? "Langkah" : "Step") \(stepNumber): \(title). \(detail)")
    }
}

// MARK: - Dedicated Quick Access Onboarding Card Component

/// Compact, accessible card presented on the Permissions / Setup screen of WelcomeView.
/// Allows the user to initiate guided Action Button setup or review/reset it if already configured.
struct QuickAccessOnboardingCardView: View {
    let isIndonesian: Bool
    let hasCompletedSetup: Bool
    let onSetupTapped: () -> Void
    var onResetTapped: (() -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: hasCompletedSetup ? "checkmark.seal.fill" : "bolt.fill")
                    .font(.title3)
                    .foregroundStyle(hasCompletedSetup ? Color.green : Color.blue)
                
                Text(cardTitle)
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text(hasCompletedSetup ? (isIndonesian ? "Diatur" : "Configured") : (isIndonesian ? "Opsional" : "Optional"))
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(hasCompletedSetup ? Color.green : Color.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(hasCompletedSetup ? Color.green.opacity(0.12) : Color(.systemGray5))
                    )
            }
            
            Text(cardDescription)
                .font(.footnote)
                .foregroundStyle(.secondary)
            
            // Privacy & user agency reassurance
            HStack(spacing: 6) {
                Image(systemName: "lock.shield.fill")
                    .font(.caption2)
                    .foregroundStyle(.green)
                
                Text(isIndonesian
                     ? "Akses Cepat hanya membuka kamera. Mikrofon tidak merekam otomatis."
                     : "Quick Access only opens the camera. The mic never records automatically.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 2)
            
            // Buttons Row
            HStack(spacing: 10) {
                Button {
                    onSetupTapped()
                } label: {
                    HStack {
                        Image(systemName: hasCompletedSetup ? "arrow.triangle.2.circlepath" : "slider.horizontal.3")
                        Text(buttonTitle)
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(buttonBackgroundColor)
                    )
                    .foregroundStyle(buttonForegroundColor)
                }
                .accessibilityLabel(accessibilityLabelText)
                .accessibilityHint(accessibilityHintText)
                
                // Uncheck / Reset button if already configured
                if hasCompletedSetup, let onResetTapped = onResetTapped {
                    Button {
                        onResetTapped()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                            Text(isIndonesian ? "Hapus" : "Uncheck")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray5))
                        )
                        .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel(isIndonesian ? "Batalkan tanda akses cepat" : "Uncheck Quick Access setup")
                    .accessibilityHint(isIndonesian ? "Mengembalikan status ke belum diatur (opsional)." : "Resets status back to optional.")
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(cardBorderColor, lineWidth: 1)
                )
        )
    }
    
    private var cardTitle: String {
        if hasCompletedSetup {
            return isIndonesian ? "Akses Cepat Diatur" : "Quick Access Configured"
        } else {
            return isIndonesian ? "Akses Cepat" : "Quick Access"
        }
    }
    
    private var cardDescription: String {
        if hasCompletedSetup {
            return isIndonesian
                ? "Tekan dan tahan Tombol Tindakan iPhone untuk membuka TestApp secara instan kapan saja."
                : "Press and hold your Action Button to open TestApp anytime."
        } else {
            return isIndonesian
                ? "Buka TestApp dengan cepat menggunakan Tombol Tindakan iPhone tanpa perlu mencari aplikasi."
                : "Open TestApp quickly with your iPhone's Action Button without searching for the app."
        }
    }
    
    private var buttonTitle: String {
        if hasCompletedSetup {
            return isIndonesian ? "Tinjau Pengaturan" : "Review Setup"
        } else {
            return isIndonesian ? "Atur Akses Cepat" : "Set Up Quick Access"
        }
    }
    
    private var buttonBackgroundColor: Color {
        hasCompletedSetup ? Color(.systemGray5) : Color.blue.opacity(0.12)
    }
    
    private var buttonForegroundColor: Color {
        hasCompletedSetup ? Color.primary : Color.blue
    }
    
    private var cardBorderColor: Color {
        hasCompletedSetup ? Color.green.opacity(0.3) : Color.blue.opacity(0.2)
    }
    
    private var accessibilityLabelText: String {
        if hasCompletedSetup {
            return isIndonesian ? "Tinjau Pengaturan Akses Cepat" : "Review Quick Access setup"
        } else {
            return isIndonesian ? "Atur Akses Cepat dengan Tombol Tindakan" : "Set Up Quick Access with Action Button"
        }
    }
    
    private var accessibilityHintText: String {
        isIndonesian
            ? "Membuka panduan langkah demi langkah untuk mengatur Tombol Tindakan iPhone. Akses Cepat bersifat opsional."
            : "Opens step-by-step instructions to configure the iPhone Action Button. Quick Access is optional."
    }
}
