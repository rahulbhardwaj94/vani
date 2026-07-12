import SwiftUI
import UserNotifications

@main
struct VaniApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        MenuBarExtra {
            MenuContent()
                .environmentObject(appState)
        } label: {
            Image(systemName: appState.status.symbolName)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar only by default; LSUIElement in Info.plist hides the Dock
        // icon, but enforce it when run as a bare executable during
        // development. The "Show Dock icon" setting overrides to .regular —
        // the escape hatch for menu bars crowded enough to hide the status
        // item (notch).
        NSApp.setActivationPolicy(
            SettingsStore.shared.showDockIcon ? .regular : .accessory
        )

        if !PermissionsManager.shared.allGranted {
            OnboardingWindow.shared.show()
        }

        DictationController.shared.start()

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
    }

    /// Menu-bar apps have no Dock icon, and a crowded menu bar (or the
    /// notch) can hide the status item — leaving no way into the app at
    /// all. Launching Vani again (double-click in Applications, Launchpad,
    /// Spotlight) lands here: open the Dashboard.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        DashboardWindow.shared.show()
        return true
    }

    /// Right-click menu on the Dock icon (when "Show Dock icon" is on).
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        menu.addItem(withTitle: "Scratchpad", action: #selector(openScratchpad), keyEquivalent: "")
        menu.addItem(withTitle: "Dashboard", action: #selector(openDashboard), keyEquivalent: "")
        menu.addItem(withTitle: "Settings", action: #selector(openSettings), keyEquivalent: "")
        menu.items.forEach { $0.target = self }
        return menu
    }

    @objc private func openScratchpad() { ScratchpadWindow.shared.show() }
    @objc private func openDashboard() { DashboardWindow.shared.show() }
    @objc private func openSettings() { SettingsWindow.shared.show() }
}

/// Global app status, drives the menu-bar icon.
enum DictationStatus {
    case idle
    case recording
    case transcribing
    case injecting

    var symbolName: String {
        switch self {
        case .idle: "mic"
        case .recording: "mic.fill"
        case .transcribing: "waveform"
        case .injecting: "arrow.down.doc"
        }
    }

    var label: String {
        switch self {
        case .idle: "Idle"
        case .recording: "Recording…"
        case .transcribing: "Transcribing…"
        case .injecting: "Inserting text…"
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var status: DictationStatus = .idle
    @Published var lastTranscript: String?
    /// Live partial transcript shown in the HUD while recording, updated every
    /// ~1.5 s. Never inserted — the final paste always comes from the full pass.
    @Published var previewTranscript: String?
    /// Mic RMS level while recording, 0…~0.3 typical speech. Drives the HUD bars.
    @Published var audioLevel: Float = 0
    /// True when locked into hands-free mode (tap once to stop).
    @Published var isHandsFree = false
    /// When the current recording started; drives the HUD's elapsed timer.
    @Published var recordingStartedAt: Date?
    /// Model download/load progress text; nil when the model is ready.
    @Published var modelStatus: String?

    private init() {}
}

struct MenuContent: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Text("Vani — \(appState.status.label)")
        if let modelStatus = appState.modelStatus {
            Text(modelStatus)
        }
        Divider()
        Button("Scratchpad…") {
            ScratchpadWindow.shared.show()
        }
        Button("Dashboard…") {
            DashboardWindow.shared.show()
        }
        Button("Settings…") {
            SettingsWindow.shared.show()
        }
        Button("Setup & Permissions…") {
            OnboardingWindow.shared.show()
        }
        Divider()
        Button("Quit Vani") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
