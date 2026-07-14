import Foundation

/// Repairs the seams between incrementally decoded dictation chunks.
///
/// Whisper punctuates each pause-delimited chunk as if it were a complete
/// utterance, so a naive space-join litters long dictations with spurious
/// sentence breaks: `"git commit dash." + "M, fix…"` → "git commit dash. M,
/// fix…". This joiner applies conservative, deterministic heuristics at each
/// boundary — it never deletes words, only adjusts boundary punctuation,
/// casing, and whitespace. Inner content of every part is preserved exactly.
public enum ChunkJoiner {
    public static func join(_ parts: [String]) -> String {
        let parts = parts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard let first = parts.first else { return "" }
        var result = first

        // Words that appear lowercased somewhere in the transcript are safe
        // to lowercase at a boundary (they're demonstrably not proper nouns
        // in this dictation). Used by the no-terminal-punctuation heuristic.
        var lowercasedElsewhere = Set<String>()
        for part in parts {
            for token in part.split(whereSeparator: { $0.isWhitespace }) {
                let word = strip(String(token))
                if let f = word.first, f.isLowercase {
                    lowercasedElsewhere.insert(word.lowercased())
                }
            }
        }

        for i in 1..<parts.count {
            result = joinPair(
                result, prev: parts[i - 1], next: parts[i],
                lowercasedElsewhere: lowercasedElsewhere
            )
        }
        return result
    }

    // MARK: - Per-boundary decision

    private static func joinPair(
        _ result: String, prev: String, next: String,
        lowercasedElsewhere: Set<String>
    ) -> String {
        // Never touch Devanagari joints — Hindi punctuation/casing rules
        // don't apply, and the danda is never a chunk artifact we can judge.
        if containsDevanagari(prev) || containsDevanagari(next) {
            return result + " " + next
        }
        guard let firstToken = next.split(whereSeparator: { $0.isWhitespace })
            .first.map(String.init)
        else { return result + " " + next }
        let firstWord = strip(firstToken)
        let startsCapitalized = firstWord.first?.isUppercase == true

        // Heuristic 1a — spurious period. Field example: "git commit dash." +
        // "M, fix the race condition" → the stray period broke the "dash m"
        // → "-m" symbol command downstream. Merge (drop the period, lowercase
        // the next word) only when the boundary carries a strong signal that
        // it is not a real sentence end (see shouldMerge).
        if prev.hasSuffix("."), !prev.hasSuffix(".."), startsCapitalized,
           shouldMerge(prev: prev, next: next, nextFirstWord: firstWord) {
            var joined = result
            // "V.A.D." — the trailing dot belongs to the acronym, keep it.
            if !endsWithDottedAcronym(prev) { joined = String(joined.dropLast()) }
            return joined + " " + lowercasingFirstWord(of: next, token: firstToken)
        }

        if prev.hasSuffix(",") {
            // Same strong-signal merge for a boundary comma before a
            // capitalized continuation ("git commit dash," + "M fix…").
            if startsCapitalized,
               shouldMerge(prev: prev, next: next, nextFirstWord: firstWord) {
                return String(result.dropLast()) + " "
                    + lowercasingFirstWord(of: next, token: firstToken)
            }
            // Heuristic 1b — spurious comma. Field example: "maybe voice," +
            // "editing" → "maybe voice editing". An utterance-final comma on
            // a very short fragment followed by a lowercase continuation is a
            // chunk artifact — unless the next word is a conjunction, where a
            // comma is plausibly real ("we tried it, but…").
            if firstWord.first?.isLowercase == true,
               fragmentWords(of: prev).count <= 3,
               !commaSafeContinuations.contains(firstWord.lowercased()) {
                return String(result.dropLast()) + " " + next
            }
        }

        // Heuristic 2 — no terminal punctuation on the left, capitalized word
        // on the right: Whisper capitalized the chunk start as an utterance
        // start. Lowercase it when the word is provably safe (appears
        // lowercased elsewhere, or is a function word), or when the left side
        // demonstrably ends mid-clause — on a connective or discourse adverb
        // ("…editing but" + "Honestly, …", "…but honestly" + "Accuracy
        // comes first", both field examples). "I", acronyms, and possible
        // proper nouns elsewhere stay.
        if let last = prev.last, !".?!,".contains(last), startsCapitalized,
           firstWord != "I", !firstWord.hasPrefix("I'"), !isAcronym(firstToken) {
            let word = firstWord.lowercased()
            let prevLast = fragmentWords(of: prev).last.map { strip($0).lowercased() } ?? ""
            let safeWord = lowercasedElsewhere.contains(word) || functionWords.contains(word)
            // Only conjunctions/adverbs, not prepositions or articles:
            // names routinely follow "to"/"with" ("talk to Rahul") but
            // essentially never a discourse adverb ("honestly Accuracy").
            let midClause = coordConjunctions.contains(prevLast)
                || discourseAdverbs.contains(prevLast)
            if safeWord || midClause {
                return result + " " + lowercasingFirstWord(of: next, token: firstToken)
            }
        }

        return result + " " + next
    }

    /// Signals that a period/comma at a chunk boundary is NOT a real sentence
    /// end. Deliberately conservative: a boundary with none of these signals
    /// is left alone ("It works." + "Now the second point." stays two
    /// sentences).
    private static func shouldMerge(
        prev: String, next: String, nextFirstWord: String
    ) -> Bool {
        let frag = fragmentWords(of: prev)
        let lastWord = frag.last.map { strip($0).lowercased() } ?? ""
        // S1: the left side ends in a connective/preposition/article/spoken
        // symbol — nobody ends a sentence on "dash" ("git commit dash." +
        // "M, …").
        if connectives.contains(lastWord) { return true }
        // S2: the right side starts with a single stray letter ("M," in the
        // same field example).
        if nextFirstWord.count == 1, nextFirstWord != "I" { return true }
        // S3: the right side is a 1–2 word "sentence" of its own
        // ("Adaptive." in "And the adapter. Adaptive. V.A.D. Threshold. …")
        // — Whisper almost never legitimately emits those mid-dictation.
        let nextWords = next.split(whereSeparator: { $0.isWhitespace })
        if nextWords.count <= 2, next.hasSuffix("."), !next.hasSuffix("..") {
            return true
        }
        // S4: the left side's final sentence fragment is a single word
        // ("Threshold." + "Holds my quiet microphone" from the same example).
        if frag.count == 1 { return true }
        // S5: the final fragment is two words starting with a hedge —
        // "Maybe voice." + "Editing but…" (field) is a trailing-off phrase,
        // not a sentence. "It works." is subject+verb and stays.
        if frag.count == 2, let first = frag.first,
           hedgeStarters.contains(strip(first).lowercased()) {
            return true
        }
        return false
    }

    // MARK: - Helpers

    /// Words of the last sentence fragment of a part (text after its last
    /// internal sentence break, trailing terminator excluded).
    private static func fragmentWords(of part: String) -> [String] {
        var text = part
        while let last = text.last, ".!?,".contains(last) { text.removeLast() }
        let fragment = text
            .components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .last ?? text
        return fragment.split(whereSeparator: { $0.isWhitespace }).map(String.init)
    }

    /// Lowercases the first letter of `next`, unless the leading token is
    /// "I"/"I'…" or an acronym ("VAD", "V.A.D.") whose casing is meaningful.
    private static func lowercasingFirstWord(of next: String, token: String) -> String {
        let word = strip(token)
        if word == "I" || word.hasPrefix("I'") || isAcronym(token) { return next }
        guard let first = next.first else { return next }
        return first.lowercased() + next.dropFirst()
    }

    private static func isAcronym(_ token: String) -> Bool {
        // Dotted acronym: "V.A.D." / "e.g." style letter-dot runs.
        if token.range(of: #"^([A-Za-z]\.){2,}$"#, options: .regularExpression) != nil {
            return true
        }
        // All-caps run of 2+ letters: "VAD", "API".
        let word = strip(token)
        return word.count >= 2 && word.allSatisfy { $0.isUppercase }
    }

    private static func endsWithDottedAcronym(_ part: String) -> Bool {
        guard let last = part.split(whereSeparator: { $0.isWhitespace }).last else {
            return false
        }
        return String(last).range(
            of: #"^([A-Za-z]\.)+$"#, options: .regularExpression
        ) != nil
    }

    private static func containsDevanagari(_ text: String) -> Bool {
        text.unicodeScalars.contains { (0x0900...0x097F).contains($0.value) }
    }

    private static func strip(_ token: String) -> String {
        token.trimmingCharacters(in: CharacterSet(charactersIn: ".,!?;:\"'()"))
    }

    /// Words a sentence essentially never ends on: if a chunk "ends" here,
    /// the terminator is a boundary artifact. Includes the spoken-symbol and
    /// number words used by code-mode commands ("dash", "dot", "one" …).
    private static let connectives: Set<String> = [
        "and", "or", "but", "so", "nor", "yet",
        "the", "a", "an",
        "to", "of", "for", "with", "in", "on", "at", "by", "from", "into", "onto",
        "than", "as", "per", "via",
        "dash", "dot", "comma", "colon", "semicolon", "slash", "underscore",
        "plus", "minus", "equals", "point",
        "zero", "one", "two", "three", "four", "five",
        "six", "seven", "eight", "nine", "ten",
    ]

    /// After a boundary comma, these lowercase words plausibly continue a
    /// real clause ("we tried it, but…") — keep the comma.
    private static let commaSafeContinuations: Set<String> = [
        "but", "and", "or", "so", "nor", "yet", "because", "which", "though",
        "then", "not",
    ]

    /// A two-word fragment opening with one of these is a trailing-off
    /// hedge ("maybe voice."), not a sentence.
    private static let hedgeStarters: Set<String> = [
        "maybe", "perhaps", "also", "like", "then", "so",
        "and", "but", "or", "plus", "possibly", "probably",
    ]

    /// Coordinating conjunctions — a chunk ending on one always continues.
    private static let coordConjunctions: Set<String> = [
        "but", "and", "or", "so", "yet", "nor",
    ]

    /// Discourse adverbs that sit mid-clause before the speaker's point —
    /// a chunk ending on one guarantees the next chunk continues the clause.
    private static let discourseAdverbs: Set<String> = [
        "honestly", "basically", "actually", "really", "probably",
        "definitely", "obviously", "literally", "seriously", "frankly",
        "maybe", "perhaps", "usually", "generally", "essentially",
    ]

    /// Common English function words that are always safe to lowercase at a
    /// no-punctuation boundary (they are never proper nouns).
    private static let functionWords: Set<String> = [
        "the", "a", "an", "and", "or", "but", "so", "to", "of", "in", "on",
        "at", "for", "with", "from", "by", "is", "are", "was", "were", "be",
        "it", "its", "this", "that", "these", "those", "we", "you", "they",
        "he", "she", "not", "as", "if", "then", "than", "when", "which",
        "what", "how", "why", "who", "will", "would", "can", "could",
        "should", "just", "also", "very", "more", "some", "all", "there",
        "here", "now", "my", "your", "our", "their",
    ]
}
