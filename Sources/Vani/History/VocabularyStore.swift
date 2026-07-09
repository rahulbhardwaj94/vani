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

    private let fileURL: URL

    private init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "Vani")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appending(path: "vocabulary.json")
        rules = (try? JSONDecoder().decode([Rule].self, from: Data(contentsOf: fileURL))) ?? []
    }

    func apply(to text: String) -> String {
        VocabularyRules.apply(rules: rules, to: text)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(rules) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
