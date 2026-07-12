import Foundation

/// Word-level diff between what the user actually said (a known calibration
/// sentence) and what Whisper heard — the engine behind "Teach Vani your
/// voice". Stable mishears become vocabulary-rule suggestions.
public enum TranscriptDiff {
    /// A contiguous run the model got wrong: `heard` is what to match in
    /// future transcripts, `expected` the replacement.
    public struct Mishear: Equatable {
        public let heard: String
        public let expected: String
        public init(heard: String, expected: String) {
            self.heard = heard
            self.expected = expected
        }
    }

    /// Aligns the two token streams (Levenshtein over case/punctuation-folded
    /// words) and returns the substitution runs. Case-only differences count
    /// ("hindi" → "Hindi" is a useful casing rule); punctuation-only ones
    /// don't. Pure insertions/deletions are ignored on their own — a rule
    /// needs something to match on both sides.
    public static func mishears(expected: String, heard: String) -> [Mishear] {
        let exp = tokens(of: expected)
        let hrd = tokens(of: heard)
        guard !exp.isEmpty, !hrd.isEmpty else { return [] }

        // DP edit distance over folded tokens.
        var dp = Array(repeating: Array(repeating: 0, count: exp.count + 1),
                       count: hrd.count + 1)
        for i in 0...hrd.count { dp[i][0] = i }
        for j in 0...exp.count { dp[0][j] = j }
        for i in 1...hrd.count {
            for j in 1...exp.count {
                let same = hrd[i - 1].folded == exp[j - 1].folded
                dp[i][j] = same
                    ? dp[i - 1][j - 1]
                    : 1 + min(dp[i - 1][j - 1], dp[i - 1][j], dp[i][j - 1])
            }
        }

        // Backtrack, grouping consecutive non-match ops into blocks.
        var blocks: [(heard: [Token], expected: [Token])] = []
        var current: (heard: [Token], expected: [Token])? = nil
        var i = hrd.count, j = exp.count
        func flush() {
            if let block = current { blocks.append(block) }
            current = nil
        }
        while i > 0 || j > 0 {
            if i > 0, j > 0, hrd[i - 1].folded == exp[j - 1].folded {
                // Exact fold match — but a raw-case difference is a rule too.
                if hrd[i - 1].clean != exp[j - 1].clean {
                    if current == nil { current = ([], []) }
                    current!.heard.insert(hrd[i - 1], at: 0)
                    current!.expected.insert(exp[j - 1], at: 0)
                } else {
                    flush()
                }
                i -= 1; j -= 1
            } else if i > 0, j > 0, dp[i][j] == dp[i - 1][j - 1] + 1 {
                if current == nil { current = ([], []) }
                current!.heard.insert(hrd[i - 1], at: 0)
                current!.expected.insert(exp[j - 1], at: 0)
                i -= 1; j -= 1
            } else if i > 0, dp[i][j] == dp[i - 1][j] + 1 {
                if current == nil { current = ([], []) }
                current!.heard.insert(hrd[i - 1], at: 0)
                i -= 1
            } else {
                if current == nil { current = ([], []) }
                current!.expected.insert(exp[j - 1], at: 0)
                j -= 1
            }
        }
        flush()
        blocks.reverse()

        return blocks.compactMap { block in
            let heardText = block.heard.map(\.clean).joined(separator: " ")
            let expectedText = block.expected.map(\.clean).joined(separator: " ")
            guard !heardText.isEmpty, !expectedText.isEmpty,
                  heardText != expectedText else { return nil }
            return Mishear(heard: heardText, expected: expectedText)
        }
    }

    private struct Token {
        let clean: String  // edge punctuation stripped, case preserved
        let folded: String // clean, lowercased + diacritic-insensitive
    }

    private static func tokens(of text: String) -> [Token] {
        text.split(whereSeparator: \.isWhitespace).compactMap { word in
            let clean = word.trimmingCharacters(in: .punctuationCharacters)
            guard !clean.isEmpty else { return nil }
            return Token(clean: clean, folded: clean.folding(
                options: [.caseInsensitive, .diacriticInsensitive], locale: nil
            ))
        }
    }
}
