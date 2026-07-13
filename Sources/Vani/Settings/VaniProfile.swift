import AppKit
import Foundation
import VaniCore
import UniformTypeIdentifiers

/// Everything that makes Vani *yours*, as one portable JSON file: vocabulary,
/// snippets, and behavior settings. Export it, put it in your dotfiles or
/// iCloud Drive, import on a new Mac — personalization without a cloud
/// account. (Wispr syncs this through their servers, Pro-only; here the file
/// is simply yours.)
struct VaniProfile: Codable {
    var version = 1
    var vocabulary: [VocabularyRule]
    var snippets: [SnippetStore.Snippet]
    var settings: Settings

    struct Settings: Codable {
        var language: String
        var whisperModel: String
        var llmCleanupEnabled: Bool
        var ollamaModel: String
        var spokenCommandsEnabled: Bool
        var codeModeEnabled: Bool
        var whisperModeEnabled: Bool
        var contextBoostEnabled: Bool
    }

    @MainActor
    static func current() -> VaniProfile {
        let s = SettingsStore.shared
        return VaniProfile(
            vocabulary: VocabularyStore.shared.rules,
            snippets: SnippetStore.shared.snippets,
            settings: Settings(
                language: s.language,
                whisperModel: s.whisperModel,
                llmCleanupEnabled: s.llmCleanupEnabled,
                ollamaModel: s.ollamaModel,
                spokenCommandsEnabled: s.spokenCommandsEnabled,
                codeModeEnabled: s.codeModeEnabled,
                whisperModeEnabled: s.whisperModeEnabled,
                contextBoostEnabled: s.contextBoostEnabled
            )
        )
    }

    /// Merge into the running app: rules/snippets appended unless an
    /// equivalent already exists; settings applied outright.
    @MainActor
    func apply() {
        let vocab = VocabularyStore.shared
        for rule in vocabulary
        where !vocab.rules.contains(where: { $0.find.lowercased() == rule.find.lowercased() }) {
            vocab.rules.append(rule)
        }
        let snips = SnippetStore.shared
        for snippet in snippets
        where !snips.snippets.contains(where: { $0.trigger.lowercased() == snippet.trigger.lowercased() }) {
            snips.snippets.append(snippet)
        }
        let s = SettingsStore.shared
        s.language = settings.language
        s.whisperModel = settings.whisperModel
        s.llmCleanupEnabled = settings.llmCleanupEnabled
        s.ollamaModel = settings.ollamaModel
        s.spokenCommandsEnabled = settings.spokenCommandsEnabled
        s.codeModeEnabled = settings.codeModeEnabled
        s.whisperModeEnabled = settings.whisperModeEnabled
        s.contextBoostEnabled = settings.contextBoostEnabled
    }

    @MainActor
    static func exportViaPanel() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "vani-profile.json"
        panel.title = "Export Vani Profile"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(current()) {
            try? data.write(to: url, options: .atomic)
        }
    }

    @MainActor
    static func importViaPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.title = "Import Vani Profile"
        guard panel.runModal() == .OK, let url = panel.url,
              let data = try? Data(contentsOf: url),
              let profile = try? JSONDecoder().decode(VaniProfile.self, from: data)
        else { return }
        profile.apply()
    }
}
