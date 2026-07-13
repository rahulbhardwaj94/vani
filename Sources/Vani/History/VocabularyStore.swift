import Foundation
import VaniCore

/// User-defined corrections for words Whisper keeps mishearing —
/// e.g. "rb flow" → "Vani", "nest js" → "NestJS".
/// Applied as the LAST pipeline step (after the LLM) so corrections and
/// casing always win. Matching lives in VaniCore (VocabularyRules.apply)
/// where it's unit-tested; this class only owns persistence and UI state.
@MainActor
final class VocabularyStore: ObservableObject {
    static let shared = VocabularyStore()

    typealias Rule = VocabularyRule

    @Published var rules: [Rule] = [] {
        didSet { save() }
    }
    /// Auto-learned candidates (from quick re-dictations) awaiting the
    /// user's accept/dismiss. Persisted so they survive relaunches.
    @Published var suggestions: [Rule] = [] {
        didSet { saveSuggestions() }
    }

    private let fileURL: URL
    private let suggestionsURL: URL

    private init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "Vani")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appending(path: "vocabulary.json")
        suggestionsURL = dir.appending(path: "suggestions.json")
        rules = (try? JSONDecoder().decode([Rule].self, from: Data(contentsOf: fileURL))) ?? []
        suggestions = (try? JSONDecoder().decode([Rule].self, from: Data(contentsOf: suggestionsURL))) ?? []
    }

    func apply(to text: String) -> String {
        VocabularyRules.apply(rules: rules, to: text)
    }

    /// Queue an auto-learned candidate unless an equivalent rule or
    /// suggestion already exists. Capped so a bad day can't flood the UI.
    func suggest(find: String, replace: String) {
        let key = find.lowercased()
        guard !rules.contains(where: { $0.find.lowercased() == key }),
              !suggestions.contains(where: { $0.find.lowercased() == key }),
              find.lowercased() != replace.lowercased() || find != replace
        else { return }
        suggestions.insert(Rule(find: find, replace: replace), at: 0)
        if suggestions.count > 12 { suggestions.removeLast(suggestions.count - 12) }
        VaniLog.log("suggested correction: \"\(find)\" → \"\(replace)\"")
    }

    func accept(_ suggestion: Rule) {
        suggestions.removeAll { $0.id == suggestion.id }
        rules.append(suggestion)
    }

    func dismiss(_ suggestion: Rule) {
        suggestions.removeAll { $0.id == suggestion.id }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(rules) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    private func saveSuggestions() {
        if let data = try? JSONEncoder().encode(suggestions) {
            try? data.write(to: suggestionsURL, options: .atomic)
        }
    }
}
