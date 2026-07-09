import Foundation

/// A user-defined correction for a word Whisper keeps mishearing —
/// e.g. "rb flow" → "Vani", "nest js" → "NestJS".
public struct VocabularyRule: Identifiable, Codable, Equatable {
    public var id = UUID()
    public var find: String
    public var replace: String

    public init(id: UUID = UUID(), find: String, replace: String) {
        self.id = id
        self.find = find
        self.replace = replace
    }
}

public enum VocabularyRules {
    /// Applies every rule, case-insensitively, on whole words/phrases.
    /// Whitespace inside `find` matches any whitespace run, and stray
    /// whitespace around either field is ignored — a rule saved as
    /// "core ml " must never swallow the space after its match
    /// ("core ml to" → "coreMLto").
    public static func apply(rules: [VocabularyRule], to text: String) -> String {
        var result = text
        for rule in rules {
            let find = rule.find.trimmingCharacters(in: .whitespacesAndNewlines)
            let replace = rule.replace.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !find.isEmpty else { continue }

            let pattern = find.split(whereSeparator: \.isWhitespace)
                .map { NSRegularExpression.escapedPattern(for: String($0)) }
                .joined(separator: #"\s+"#)
            // Explicit lookarounds instead of \b: rules that end in symbols
            // ("c++") have no word boundary at their edge, so \b never matches.
            guard let regex = try? NSRegularExpression(
                pattern: #"(?i)(?<!\w)"# + pattern + #"(?!\w)"#
            ) else { continue }
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: NSRegularExpression.escapedTemplate(for: replace)
            )
        }
        return result
    }
}
