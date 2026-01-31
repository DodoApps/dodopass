import SwiftUI
import AppKit

/// Main application entry point.
@main
struct DodoPassApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var vaultManager = VaultManager.shared
    @StateObject private var toastManager = ToastManager.shared

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(vaultManager)
                .environmentObject(toastManager)
                .frame(minWidth: 900, minHeight: 600)
                .onAppear {
                    configureWindow()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            AppCommands(vaultManager: vaultManager)
        }
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }

        Settings {
            SettingsView()
                .environmentObject(vaultManager)
        }
    }

    // MARK: - Private Methods

    private func configureWindow() {
        // Configure window appearance
        if let window = NSApplication.shared.windows.first {
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.backgroundColor = NSColor(DodoColors.background)
        }
    }

    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            // App became active
            break
        case .inactive:
            // App became inactive - consider locking after timeout
            break
        case .background:
            // App moved to background - lock vault if configured
            Task {
                if UserDefaults.standard.bool(forKey: "lockOnBackground") {
                    await vaultManager.lock()
                }
            }
        @unknown default:
            break
        }
    }
}

// MARK: - Content View

struct ContentView: View {
    @EnvironmentObject var vaultManager: VaultManager
    @State private var showOnboarding = false

    var body: some View {
        Group {
            if !vaultManager.vaultExists {
                OnboardingView()
            } else if vaultManager.isLocked {
                LockScreen(vaultManager: vaultManager)
            } else {
                MainView()
            }
        }
        .overlay(alignment: .top) {
            ToastContainerView()
        }
    }
}

// MARK: - Toast Container

struct ToastContainerView: View {
    @StateObject private var toastManager = ToastManager.shared

    var body: some View {
        VStack {
            if let toast = toastManager.currentToast {
                ToastView(
                    message: toast.message,
                    icon: toast.icon,
                    type: toast.type
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .onTapGesture {
                    toastManager.dismiss()
                }
            }
        }
        .padding(.top, Theme.Spacing.lg)
        .animation(.spring(response: 0.3), value: toastManager.currentToast?.id)
    }
}
