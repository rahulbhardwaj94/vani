import Foundation

/// Context-aware correction: nudge near-miss words toward terms that are
/// demonstrably on the user's mind — clipboard contents, recent dictations.
/// Whisper hears "cube ernetes"; the clipboard says "kubernetes"; fix it.
/// Deliberately conservative: only distinctive context terms, only small
/// edit distances, never touching short common words.
public enum ContextBoost {
    /// Terms worth boosting toward, extracted from context text: distinctive
    /// tokens — capitalized mid-sentence, camelCase, containing digits/
    /// symbols, or simply long — deduplicated, capped.
    public static func terms(from context: String, limit: Int = 150) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for rawToken in context.split(whereSeparator: { $0.isWhitespace || $0 == "," || $0 == "(" || $0 == ")" || $0 == "\"" }) {
            let token = rawToken.trimmingCharacters(in: .punctuationCharacters)
            guard token.count >= 4, token.count <= 40 else { continue }
            let distinctive = token.contains(where: \.isUppercase)
                || token.contains(where: \.isNumber)
                || token.contains(where: { "._-/".contains($0) })
                || token.count >= 8
            guard distinctive else { continue }
            let key = token.lowercased()
            if seen.insert(key).inserted {
                result.append(token)
                if result.count >= limit { break }
            }
        }
        return result
    }

    /// Replace transcript words that are a small edit away from a context
    /// term with that term (case of the term wins). Words under 5 chars are
    /// never touched; distance budget: 1 edit, or 2 for words ≥8 chars.
    public static func correct(_ text: String, terms: [String]) -> String {
        guard !terms.isEmpty else { return text }
        let index = Dictionary(grouping: terms, by: { $0.count })

        let words = text.split(separator: " ", omittingEmptySubsequences: false)
        let corrected = words.map { word -> String in
            let core = word.trimmingCharacters(in: .punctuationCharacters)
            guard core.count >= 5 else { return String(word) }
            let budget = core.count >= 8 ? 2 : 1
            let folded = core.lowercased()

            var best: String?
            var bestDistance = budget + 1
            for length in (core.count - budget)...(core.count + budget) {
                for term in index[length] ?? [] {
                    let termFolded = term.lowercased()
                    if termFolded == folded { return String(word) } // already right (incl. case: leave to vocab)
                    let d = editDistance(folded, termFolded, limit: bestDistance - 1)
                    if d < bestDistance {
                        bestDistance = d
                        best = term
                    }
                }
            }
            guard let best else { return String(word) }
            return String(word).replacingOccurrences(of: core, with: best)
        }
        return corrected.joined(separator: " ")
    }

    /// Levenshtein with early exit once `limit` is exceeded.
    static func editDistance(_ a: String, _ b: String, limit: Int) -> Int {
        if limit < 0 { return Int.max }
        let aChars = Array(a), bChars = Array(b)
        if abs(aChars.count - bChars.count) > limit { return Int.max }
        var previous = Array(0...bChars.count)
        for i in 1...max(aChars.count, 1) where !aChars.isEmpty {
            var current = [i] + Array(repeating: 0, count: bChars.count)
            var rowMin = i
            for j in 1...bChars.count {
                let cost = aChars[i - 1] == bChars[j - 1] ? 0 : 1
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
                rowMin = min(rowMin, current[j])
            }
            if rowMin > limit { return Int.max }
            previous = current
        }
        return previous[bChars.count] <= limit ? previous[bChars.count] : Int.max
    }
}
