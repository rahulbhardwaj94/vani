import Foundation

/// Finds a language switch *inside* a pause-free span of speech.
///
/// Pause-based segmentation assumes people breathe at the switch; fluent
/// Hinglish speakers don't ("Send the invoice tonight बाक़ी details कल discuss
/// करेंगे" in one breath). Whisper then decodes the fused span under a single
/// language token, which is destructive in both directions — the wrong-language
/// half gets translated (en) or dropped (hi). The only correct handling is to
/// locate the switch and decode each side in its own language.
///
/// The search is model-agnostic: `detect` is an injected closure returning the
/// language of a sample range (or nil when it can't tell — too short, or a
/// language the user doesn't speak, i.e. an ID misfire). Head and tail windows
/// are detected first; if they agree the span is monolingual and the caller
/// pays only one extra detect versus today. If they differ, the flip point is
/// binary-searched: with a single switch, a window's verdict is the majority
/// language of its span, so verdicts flip exactly where the window center
/// crosses the boundary — the classic bisection invariant.
public enum CodeSwitchScan {
    /// A same-language stretch of the span.
    public struct Run: Equatable {
        public let start: Int
        public let end: Int
        public let language: String

        public init(start: Int, end: Int, language: String) {
            self.start = start
            self.end = end
            self.language = language
        }
    }

    /// Locate the switch in `totalSamples` of speech, splitting at
    /// `splitPoint(interval)` — callers pick the quietest moment inside the
    /// final uncertainty interval so the cut lands between words.
    ///
    /// Returns nil when the span is monolingual, too short to window, or any
    /// needed verdict is unknowable — callers keep their existing
    /// whole-span behavior. Never guesses: an unknown endpoint means no split.
    public static func runs(
        totalSamples: Int,
        windowSamples: Int,
        detect: (Range<Int>) async -> String?,
        splitPoint: (Range<Int>) -> Int
    ) async -> [Run]? {
        // Windows must not overlap, or head/tail share the switch region.
        guard totalSamples >= windowSamples * 2 else { return nil }

        guard let head = await detect(0..<windowSamples),
              let tail = await detect((totalSamples - windowSamples)..<totalSamples)
        else { return nil }
        guard head != tail else { return nil }

        // Bisect on window centers — but only coarsely. A window straddling
        // the switch gives a majority-vote verdict that's noisy in practice
        // (a 1.5 s window with 0.6 s en + 0.9 s hi misdetected en in
        // testing), and one wrong verdict routes the search away from the
        // real boundary. So stop while the interval is still several windows
        // wide and let `splitPoint` find the actual moment of the switch:
        // people switch languages at word boundaries, and the micro-pause
        // there is the quietest spot in any interval that contains it.
        var lo = windowSamples / 2                    // center of head window
        var hi = totalSamples - windowSamples / 2     // center of tail window
        while hi - lo > windowSamples * 4 {
            let mid = (lo + hi) / 2
            let start = max(0, min(mid - windowSamples / 2, totalSamples - windowSamples))
            guard let verdict = await detect(start..<(start + windowSamples)) else { break }
            if verdict == head {
                lo = mid
            } else {
                hi = mid
            }
        }

        let cut = min(max(splitPoint(lo..<hi), 1), totalSamples - 1)
        return [
            Run(start: 0, end: cut, language: head),
            Run(start: cut, end: totalSamples, language: tail),
        ]
    }
}
