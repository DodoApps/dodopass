import SwiftUI

/// A transient toast notification.
struct ToastView: View {
    let message: String
    var icon: String?
    var type: ToastType = .info

    enum ToastType {
        case info
        case success
        case warning
        case error

        var color: Color {
            switch self {
            case .info: return DodoColors.accent
            case .success: return DodoColors.success
            case .warning: return DodoColors.warning
            case .error: return DodoColors.error
            }
        }
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(type.color)
            }

            Text(message)
                .font(DodoTypography.body)
                .foregroundColor(DodoColors.textPrimary)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
        .background(DodoColors.backgroundSecondary)
        .cornerRadius(Theme.Radius.md)
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Toast Manager

/// Manages toast display and lifecycle.
@MainActor
final class ToastManager: ObservableObject {
    // MARK: - Singleton

    static let shared = ToastManager()

    // MARK: - Published State

    @Published private(set) var currentToast: Toast?
    @Published private(set) var toasts: [Toast] = []

    struct Toast: Identifiable, Equatable {
        let id = UUID()
        let message: String
        let icon: String?
        let type: ToastView.ToastType
        let duration: TimeInterval
    }

    private var dismissTask: Task<Void, Never>?

    func show(_ message: String, icon: String? = nil, type: ToastView.ToastType = .info, duration: TimeInterval = 2.5) {
        // Cancel any existing dismiss task
        dismissTask?.cancel()

        // Show new toast
        let newToast = Toast(message: message, icon: icon, type: type, duration: duration)
        currentToast = newToast

        // Schedule dismiss with captured toast ID to prevent race condition
        let toastId = newToast.id
        dismissTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                // Only dismiss if this toast is still the current one
                if self?.currentToast?.id == toastId {
                    self?.dismiss()
                }
            } catch {
                // Task was cancelled, do nothing
            }
        }
    }

    func dismiss() {
        withAnimation(Theme.Animation.normal) {
            currentToast = nil
        }
    }

    func dismiss(id: UUID) {
        withAnimation(Theme.Animation.normal) {
            toasts.removeAll { $0.id == id }
        }
    }

    func show(message: String, type: ToastView.ToastType = .info) {
        show(message, type: type)
    }
}

// MARK: - Toast Container

/// A container that displays toasts at the bottom of the screen.
struct ToastContainer: View {
    @ObservedObject var toastManager: ToastManager

    var body: some View {
        VStack {
            Spacer()

            if let toast = toastManager.currentToast {
                ToastView(message: toast.message, icon: toast.icon, type: toast.type)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onTapGesture {
                        toastManager.dismiss()
                    }
                    .padding(.bottom, Theme.Spacing.xxl)
            }
        }
        .animation(Theme.Animation.spring, value: toastManager.currentToast?.id)
    }
}

// MARK: - Environment Key

private struct ToastManagerKey: EnvironmentKey {
    static let defaultValue: ToastManager? = nil
}

extension EnvironmentValues {
    var toastManager: ToastManager? {
        get { self[ToastManagerKey.self] }
        set { self[ToastManagerKey.self] = newValue }
    }
}

// MARK: - Preview

#if DEBUG
struct ToastView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            ToastView(message: "Copied to clipboard", icon: "doc.on.doc.fill", type: .info)
            ToastView(message: "Password saved", icon: "checkmark.circle.fill", type: .success)
            ToastView(message: "Weak password", icon: "exclamationmark.triangle.fill", type: .warning)
            ToastView(message: "Failed to sync", icon: "xmark.circle.fill", type: .error)
        }
        .padding()
        .background(DodoColors.background)
    }
}
#endif
