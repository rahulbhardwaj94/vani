import Foundation

/// Auto-learning dictionary: when a mishear lands, people immediately
/// re-dictate the corrected phrase. If a short utterance arrives right after
/// another and differs from some window of it by only a word or two, those
/// differing words are correction candidates ("heard X, you meant Y").
public enum CorrectionDetector {
    /// `previous`: the text just pasted. `current`: the quick follow-up
    /// utterance. Returns suggested rules, or [] if this doesn't look like a
    /// re-dictation.
    public static func candidates(previous: String, current: String) -> [TranscriptDiff.Mishear] {
        let currentWords = current.split(whereSeparator: \.isWhitespace)
        let previousWords = previous.split(whereSeparator: \.isWhitespace)
        // Re-dictations are short phrases, and correcting into something
        // longer than the source makes no sense.
        guard (1...6).contains(currentWords.count),
              previousWords.count >= currentWords.count else { return [] }

        var best: [TranscriptDiff.Mishear] = []
        var bestScore = Int.max
        let window = currentWords.count
        for start in 0...(previousWords.count - window) {
            let slice = previousWords[start..<(start + window)].joined(separator: " ")
            let pairs = TranscriptDiff.mishears(expected: current, heard: slice)
            guard !pairs.isEmpty else { continue } // identical → not a correction
            // Every pair must sound like a mishear: the two sides within
            // 75% relative edit distance — loose because mishears are
            // phonetic, not orthographic ("Bonnie"→"Vani" is 67%). Without
            // this, a one-word re-dictation "matches" any random word of
            // the previous text ("The"→"colonel" is 86%, rejected).
            guard pairs.allSatisfy(plausibleMishear) else { continue }
            // Changed words must be the minority of the window: mostly-equal
            // context is what distinguishes a correction from a new sentence.
            let changed = pairs.reduce(0) {
                $0 + $1.expected.split(whereSeparator: \.isWhitespace).count
            }
            guard changed * 2 <= window || window == 1 else { continue }
            if changed < bestScore {
                bestScore = changed
                best = pairs
            }
        }
        return best
    }

    private static func plausibleMishear(_ pair: TranscriptDiff.Mishear) -> Bool {
        let heard = pair.heard.lowercased()
        let expected = pair.expected.lowercased()
        let longest = max(heard.count, expected.count)
        let budget = longest * 3 / 4
        return ContextBoost.editDistance(heard, expected, limit: budget) <= budget
    }
}
