import Foundation

/// Spoken casing for identifiers — the reason dictation tools die in code:
/// "camel case get user name" → `getUserName`. The command word cases the
/// words that follow it, up to the next punctuation mark (Whisper turns the
/// natural pause after an identifier into `,` or `.`, so pauses bound it).
public enum CasingCommands {
    /// Order matters: multi-word command names before their prefixes.
    private static let styles: [(phrase: String, transform: ([String]) -> String)] = [
        ("screaming snake case", { $0.map { $0.uppercased() }.joined(separator: "_") }),
        ("camel case", { words in
            guard let first = words.first?.lowercased() else { return "" }
            return first + words.dropFirst().map(\.capitalizedWord).joined()
        }),
        ("pascal case", { $0.map(\.capitalizedWord).joined() }),
        ("snake case", { $0.map { $0.lowercased() }.joined(separator: "_") }),
        ("kebab case", { $0.map { $0.lowercased() }.joined(separator: "-") }),
    ]

    public static func apply(to text: String) -> String {
        var result = text
        for style in styles {
            let phrase = style.phrase.replacingOccurrences(of: " ", with: #"\s+"#)
            // Command phrase, then 1–8 following words captured up to (not
            // including) punctuation or end. Case-insensitive; an article
            // before the phrase keeps it literal ("a camel case example").
            let pattern = #"(?i)(?<!\b(?:a|an|the)\s)(?<!\w)"# + phrase
                + #"[:,]?\s+((?:[\p{L}\p{N}']+(?:\s+|(?=[^\s\p{L}\p{N}'])|$)){1,8})"#
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }

            // Replace from the end so earlier ranges stay valid.
            let matches = regex.matches(
                in: result, range: NSRange(result.startIndex..., in: result)
            ).reversed()
            for match in matches {
                guard let whole = Range(match.range, in: result),
                      let capture = Range(match.range(at: 1), in: result) else { continue }
                let words = result[capture]
                    .split(whereSeparator: \.isWhitespace)
                    .map(String.init)
                guard !words.isEmpty else { continue }
                // Keep whatever trailing whitespace the capture swallowed.
                let trailing = result[capture].suffix(while: \.isWhitespace)
                result.replaceSubrange(whole, with: style.transform(words) + trailing)
            }
        }
        return result
    }
}

private extension String {
    /// First letter uppercased, rest untouched ("name" → "Name", "iOS" → "IOS"
    /// is avoided by lowercasing first: dictated words arrive lowercase).
    var capitalizedWord: String {
        guard let first = first else { return self }
        return first.uppercased() + dropFirst().lowercased()
    }
}

private extension Substring {
    func suffix(while predicate: (Character) -> Bool) -> Substring {
        var end = endIndex
        while end > startIndex, predicate(self[index(before: end)]) {
            end = index(before: end)
        }
        return self[end...]
    }
}
