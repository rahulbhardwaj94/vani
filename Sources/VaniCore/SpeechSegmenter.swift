import Foundation

/// Turns raw voice-activity ranges (from a VAD) into pause-delimited speech
/// segments: the units the transcriber detects a language for and decodes
/// independently, so a mid-utterance language switch is handled per segment.
///
/// The VAD itself lives in WhisperKit (energy-based); only this merge/pad/prune
/// step is here so it can be unit-tested without loading a model.
public enum SpeechSegmenter {
    /// Merge adjacent voice-active sample ranges into segments.
    /// - Active ranges separated by less than `mergeGapSeconds` are one segment
    ///   (natural within-sentence pauses don't fragment speech).
    /// - Each kept segment is padded by `padSeconds` on both sides (clamped to
    ///   the clip) so a cut doesn't clip word edges.
    /// - Segments shorter than `minSegmentSeconds` after padding are dropped as
    ///   noise blips.
    ///
    /// Returns a single segment (or none) when there's no pause long enough to
    /// split on — the caller then decodes the whole clip in one pass.
    public static func merge(
        activeChunks: [(start: Int, end: Int)],
        totalSamples: Int,
        sampleRate: Int = 16_000,
        mergeGapSeconds: Double = 0.3,
        padSeconds: Double = 0.1,
        minSegmentSeconds: Double = 0.2
    ) -> [(start: Int, end: Int)] {
        let mergeGap = Int(Double(sampleRate) * mergeGapSeconds)
        let pad = Int(Double(sampleRate) * padSeconds)
        let minLen = Int(Double(sampleRate) * minSegmentSeconds)

        var merged: [(start: Int, end: Int)] = []
        for chunk in activeChunks where chunk.end > chunk.start {
            if let last = merged.last, chunk.start - last.end < mergeGap {
                merged[merged.count - 1].end = chunk.end
            } else {
                merged.append(chunk)
            }
        }

        return merged.compactMap { seg in
            let start = max(0, seg.start - pad)
            let end = min(totalSamples, seg.end + pad)
            return end - start >= minLen ? (start: start, end: end) : nil
        }
    }

    /// RMS of each `frameLength`-sample frame — the quantity the energy VAD
    /// thresholds against.
    public static func frameRMS(of samples: [Float], frameLength: Int) -> [Float] {
        guard frameLength > 0, !samples.isEmpty else { return [] }
        var result: [Float] = []
        result.reserveCapacity(samples.count / frameLength + 1)
        var i = 0
        while i < samples.count {
            let end = min(i + frameLength, samples.count)
            var sum: Float = 0
            for j in i..<end { sum += samples[j] * samples[j] }
            result.append((sum / Float(end - i)).squareRoot())
            i += frameLength
        }
        return result
    }

    /// A voice-activity threshold derived from the audio itself. A fixed
    /// threshold breaks on real microphones: a quiet input (measured speech
    /// RMS ~0.016 on the reporting user's mic) sits below WhisperKit's 0.02
    /// default, so the VAD calls nearly all speech silence. Instead, anchor
    /// on the loud end of the clip (90th percentile ≈ voiced speech) and the
    /// quiet end (10th percentile ≈ room tone), and put the bar well below
    /// speech but above the floor. Clamped so pathological clips (all
    /// silence, clipping) stay sane.
    public static func adaptiveEnergyThreshold(frameRMS: [Float]) -> Float {
        guard frameRMS.count >= 5 else { return 0.005 }
        let sorted = frameRMS.sorted()
        let floor = sorted[sorted.count / 10]
        let speech = sorted[sorted.count * 9 / 10]
        let threshold = max(floor * 2, speech * 0.2)
        return min(max(threshold, 0.0015), 0.02)
    }

    /// Which of these segments are safely *closed* — fully in the past, with
    /// enough margin after them that the VAD won't extend them as more audio
    /// arrives. The incremental transcriber decodes closed segments while the
    /// user is still speaking; the still-growing last segment never qualifies.
    public static func closedSegments(
        segments: [(start: Int, end: Int)],
        totalSamples: Int,
        sampleRate: Int = 16_000,
        closeMarginSeconds: Double = 0.5
    ) -> [(start: Int, end: Int)] {
        let margin = Int(Double(sampleRate) * closeMarginSeconds)
        return segments.filter { $0.end + margin <= totalSamples }
    }

    /// The quietest split point within `searchRange` of the samples: center of
    /// the minimum-RMS window. Used to force-close a chunk when someone talks
    /// for a very long time without ever pausing long enough for the VAD.
    public static func quietestSplit(
        in samples: [Float],
        searchRange: Range<Int>,
        windowSamples: Int = 1_600
    ) -> Int {
        let range = searchRange.clamped(to: 0..<samples.count)
        guard range.count > windowSamples else { return range.lowerBound + range.count / 2 }

        var best = range.lowerBound
        var bestEnergy = Float.greatestFiniteMagnitude
        var i = range.lowerBound
        while i + windowSamples <= range.upperBound {
            var sum: Float = 0
            for j in i..<(i + windowSamples) { sum += samples[j] * samples[j] }
            if sum < bestEnergy {
                bestEnergy = sum
                best = i
            }
            i += windowSamples / 2
        }
        return best + windowSamples / 2
    }

    /// Language-ID smoothing: a short segment (a filler, "umm", one word)
    /// carries too little signal for reliable detection — in the field an
    /// English breath was tagged Hindi and decoded to junk ("तेगे एंड").
    /// Segments shorter than `minIndependentSeconds` inherit the language of
    /// their nearest long neighbor (ties → the earlier one) instead of
    /// trusting their own detection. All-short inputs are left unchanged.
    public static func smoothLanguages(
        segments: [(start: Int, end: Int)],
        languages: [String],
        sampleRate: Int = 16_000,
        minIndependentSeconds: Double = 2.0
    ) -> [String] {
        guard segments.count == languages.count, !segments.isEmpty else { return languages }
        let minLen = Int(Double(sampleRate) * minIndependentSeconds)
        let isLong = segments.map { $0.end - $0.start >= minLen }
        guard isLong.contains(true) else { return languages }

        return languages.enumerated().map { index, language in
            if isLong[index] { return language }
            // Nearest by audio gap, not by index — a filler belongs to the
            // speech it's contiguous with, not whichever side has more
            // segments. Ties go to the earlier (preceding) run.
            var best = index
            var bestGap = Int.max
            for j in segments.indices where isLong[j] {
                let gap = j < index
                    ? segments[index].start - segments[j].end
                    : segments[j].start - segments[index].end
                if gap < bestGap {
                    bestGap = gap
                    best = j
                }
            }
            return languages[best]
        }
    }

    /// Collapse adjacent segments that detected the same language into one
    /// span (first start → last end, silence between them included). The
    /// split threshold is deliberately eager so a code-switch with only a
    /// breath-length pause is caught; this regroups the false splits, so the
    /// expensive decode runs once per language *run*, not once per pause —
    /// and each decode keeps cross-pause context for punctuation.
    public static func groupByLanguage(
        segments: [(start: Int, end: Int)],
        languages: [String]
    ) -> [(start: Int, end: Int, language: String)] {
        var groups: [(start: Int, end: Int, language: String)] = []
        for (seg, lang) in zip(segments, languages) {
            if let last = groups.last, last.language == lang {
                groups[groups.count - 1].end = seg.end
            } else {
                groups.append((start: seg.start, end: seg.end, language: lang))
            }
        }
        return groups
    }
}
