import SwiftUI
import KeyboardShortcuts
import ServiceManagement

struct SettingsView: View {
    @ObservedObject private var settings = SettingsStore.shared
    @ObservedObject private var appState = AppState.shared
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section("Hotkeys") {
                LabeledContent("Hold to talk") {
                    Text("Right ⌥ (Option)")
                        .foregroundStyle(.secondary)
                }
                KeyboardShortcuts.Recorder("Toggle dictation:", name: .toggleDictation)
                Text("Double-tap Right ⌥ to lock hands-free; tap once to stop. Esc discards a recording in progress."
                     + (FeatureFlags.holdToLockHandsFree ? " Holding ≥1.5 s and releasing also locks hands-free." : ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Speech to text") {
                Picker("Spoken language", selection: $settings.language) {
                    ForEach(SettingsStore.languages, id: \.code) { lang in
                        Text(lang.label).tag(lang.code)
                    }
                }
                Picker("Whisper model", selection: $settings.whisperModel) {
                    Text("Large v3 Turbo — best accuracy (~1.6 GB)")
                        .tag(SettingsStore.whisperModels[0])
                    Text("Large v3 Turbo compressed (~0.6 GB)")
                        .tag(SettingsStore.whisperModels[1])
                    Text("Small — fastest (~0.5 GB)")
                        .tag(SettingsStore.whisperModels[2])
                    Text("Base — lightest")
                        .tag(SettingsStore.whisperModels[3])
                }
                Text("Changing the model triggers a download on next dictation if it isn't cached yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if FeatureFlags.streamingPreview {
                    Toggle("Live preview while speaking", isOn: $settings.streamingPreview)
                    Text("Shows a running transcript in the pill as you talk. It's disposable — the pasted text always comes from the final pass — and falls back silently if the model can't keep up.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Spoken commands") {
                Toggle("Spoken punctuation & commands", isOn: $settings.spokenCommandsEnabled)
                Text("Say \"new line\" / \"नई लाइन\", \"new paragraph\", \"full stop\", \"comma\", \"question mark\" — or \"scratch that\" / \"रहने दो\" to discard a dictation. Phrases after an article stay literal (\"a new line of code\").")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Code mode") {
                Toggle("Developer-aware dictation in terminals & editors", isOn: $settings.codeModeEnabled)
                Text("In Terminal, iTerm, VS Code, Cursor, Xcode, JetBrains IDEs and friends: no auto-capitalization, no trailing period, LLM polish off. Spoken casing: \"camel case get user name\" → getUserName (also snake, kebab, pascal, screaming snake). Spoken symbols: \"dash m\" → -m, \"pipe\" → |, \"server dot js\" → server.js, \"open paren\", \"fat arrow\", \"underscore\"…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Cleanup") {
                Toggle("Polish text with local LLM (Ollama)", isOn: $settings.llmCleanupEnabled)
                if settings.llmCleanupEnabled {
                    TextField("Ollama model", text: $settings.ollamaModel)
                        .help("Small models like gemma3:1b keep latency and memory low. Large models (7B+) are slow next to Whisper on 16 GB.")
                }
                Text("Filler words (um, uh) are always removed, even without the LLM. Small models can occasionally drop or swap words — leave this off if exact wording matters.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("General") {
                Toggle("Show Dock icon", isOn: $settings.showDockIcon)
                Text("Useful when a crowded menu bar (or the notch) hides Vani's status icon. Right-click the Dock icon for Scratchpad, Dashboard, and Settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            if enabled {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
            }

            if let last = appState.lastTranscript {
                Section("Last transcript") {
                    Text(last)
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }
}

@MainActor
final class SettingsWindow {
    static let shared = SettingsWindow()
    private var window: NSWindow?

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView())
            let win = NSWindow(contentViewController: hosting)
            win.title = "Vani Settings"
            win.styleMask = [.titled, .closable]
            win.isReleasedWhenClosed = false
            win.center()
            window = win
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
