import Foundation

/// Collapses stretched pronunciations into the word the speaker meant:
/// "Gooooogle" → "Google", "sooooo" → "so". Not a rewrite — the stretched
/// spelling is Whisper's rendering of emphasis, and the collapsed form is
/// the word that was actually said. Deterministic and conservative: a run
/// only collapses when the result validates as a real word (`isWord`,
/// injected — the app passes the system spell checker plus the user's
/// vocabulary), so "aaaargh" with no valid collapse stays exactly as is.
public enum Elongation {
    /// Normalizes every token containing a letter repeated 3+ times.
    /// `isWord` decides validity of candidate collapses (lowercased input).
    public static func normalize(_ text: String, isWord: (String) -> Bool) -> String {
        let tokens = text.components(separatedBy: " ")
        let fixed = tokens.map { token -> String in
            collapse(token, isWord: isWord)
        }
        return fixed.joined(separator: " ")
    }

    private static func collapse(_ token: String, isWord: (String) -> Bool) -> String {
        // Fast path: no letter appears 3+ times consecutively.
        guard hasLongRun(token) else { return token }
        // Only Latin words — never touch Devanagari or mixed junk.
        guard token.unicodeScalars.allSatisfy({
            CharacterSet.letters.contains($0) || CharacterSet.punctuationCharacters.contains($0)
        }) else { return token }

        // Split trailing/leading punctuation off so "Gooooogle," validates.
        let core = token.trimmingCharacters(in: .punctuationCharacters)
        guard hasLongRun(core), !core.isEmpty else { return token }
        let prefix = String(token.prefix(while: { !$0.isLetter }))
        let suffix = String(token.reversed().prefix(while: { !$0.isLetter }).reversed())

        // Candidates: every 3+ run reduced to 2 ("Gooooogle" → "Google"),
        // then to 1 ("sooooo" → "so"), then mixed (2s first, 1s as
        // fallback). First candidate that is a real word wins.
        for candidate in [runsCollapsed(core, to: 2), runsCollapsed(core, to: 1)] {
            if candidate != core, isWord(candidate.lowercased()) {
                return prefix + candidate + suffix
            }
        }
        return token
    }

    private static func hasLongRun(_ s: String) -> Bool {
        var count = 1
        var prev: Character?
        for ch in s.lowercased() {
            if ch == prev { count += 1; if count >= 3, ch.isLetter { return true } }
            else { count = 1; prev = ch }
        }
        return false
    }

    /// Every run of 3+ identical letters reduced to `n` repeats.
    private static func runsCollapsed(_ s: String, to n: Int) -> String {
        var out = ""
        var run: [Character] = []
        func flush() {
            if run.count >= 3, let f = run.first, f.isLetter {
                out.append(contentsOf: Array(repeating: f, count: n))
            } else {
                out.append(contentsOf: run)
            }
            run = []
        }
        for ch in s {
            if let last = run.last, last.lowercased() == ch.lowercased() {
                run.append(ch)
            } else {
                flush()
                run = [ch]
            }
        }
        flush()
        return out
    }
}

private extension Character {
    func lowercased() -> String { String(self).lowercased() }
}
