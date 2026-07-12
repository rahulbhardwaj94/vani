import Foundation
import VaniCore

/// Voice snippets: say a short trigger phrase, get a saved block of text —
/// "email sign off" → your three-line signature. Persisted as JSON next to
/// vocabulary; expansion reuses the vocabulary matching engine (whole-phrase,
/// case-insensitive) with trailing-punctuation swallowing.
@MainActor
final class SnippetStore: ObservableObject {
    static let shared = SnippetStore()

    struct Snippet: Identifiable, Codable, Equatable {
        var id = UUID()
        var trigger: String
        var expansion: String
    }

    @Published var snippets: [Snippet] = [] {
        didSet { save() }
    }

    private let fileURL: URL

    private init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "Vani")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appending(path: "snippets.json")
        snippets = (try? JSONDecoder().decode([Snippet].self, from: Data(contentsOf: fileURL))) ?? []
    }

    func apply(to text: String) -> String {
        guard !snippets.isEmpty else { return text }
        return VocabularyRules.apply(
            rules: snippets.map { VocabularyRule(find: $0.trigger, replace: $0.expansion) },
            to: text,
            swallowTrailingPunctuation: true
        )
    }

    private func save() {
        if let data = try? JSONEncoder().encode(snippets) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
