import Foundation
import VaniCore

/// Decodes a dictation *while it is being spoken* so that stopping only ever
/// waits for the tail, not the whole recording.
///
/// While recording, a monitor loop watches the accumulating buffer. Whenever
/// the VAD closes a pause-delimited segment (with margin, so it can't grow),
/// that chunk is transcribed in the background. On stop, only the audio after
/// the last decoded chunk remains, so release-to-paste latency is roughly
/// constant (~the tail decode) regardless of dictation length. Chunks decode
/// without cross-chunk prompt context — see decodeChunk for why.
///
/// Short dictations never activate it (`finish` returns nil and the caller
/// uses the classic single-pass path, including its code-switch grouping).
@MainActor
final class IncrementalTranscriber {
    /// Don't bother until the buffer is longer than this — below it, the
    /// classic single pass is already fast and decodes with full context.
    private static let activateAfterSeconds = 8.0
    private static let tickSeconds = 1.0
    /// Force-close a chunk if someone speaks this long without a VAD pause,
    /// splitting at the quietest moment near the limit.
    private static let maxOpenSeconds = 25.0
    private static let sampleRate = Int(AudioRecorder.targetSampleRate)

    private let model: String
    private let language: String
    private let snapshot: () -> [Float]

    /// Transcripts of decoded chunks, in order.
    private var parts: [String] = []
    /// Absolute sample index up to which audio has been decoded.
    private var frontier = 0
    private var monitor: Task<Void, Never>?
    /// Set when anything anomalous happens (a decode threw, or audio decoded
    /// empty even with added context). Correctness beats latency: a degraded
    /// run abandons all pre-decoded parts and finish() returns nil so the
    /// caller re-decodes the *entire* buffer on the classic path — words can
    /// never be lost.
    private var degraded = false
    /// The chunk at the current frontier decoded to empty text (a filler or
    /// breath the model nulled out). Instead of degrading immediately, wait
    /// for the next closed segment and decode both spans as one chunk — with
    /// context the model transcribes it, or it truly was silence. Only a
    /// second empty on the merged span degrades. If recording stops first,
    /// the tail (which starts at the unmoved frontier) covers it anyway.
    private var emptyAtFrontier = false

    init(model: String, language: String, snapshot: @escaping () -> [Float]) {
        self.model = model
        self.language = language
        self.snapshot = snapshot
    }

    func start() {
        monitor = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Self.tickSeconds))
                guard !Task.isCancelled, let self, !self.degraded else { return }
                await self.decodeNewlyClosedChunks(in: self.snapshot())
            }
        }
    }

    func cancel() {
        monitor?.cancel()
        monitor = nil
    }

    /// Final assembly after the recording stopped. Returns the full joined
    /// transcript, or nil if no chunks were decoded (caller falls back to the
    /// classic path). `fullSamples` is the complete recording.
    func finish(fullSamples: [Float]) async -> String? {
        monitor?.cancel()
        // Wait out any in-flight chunk decode so `parts`/`frontier` are final.
        await monitor?.value
        monitor = nil
        if degraded {
            VaniLog.log("incremental DEGRADED → classic full decode")
            return nil
        }
        guard frontier > 0 else { return nil }

        let tail = Array(fullSamples[min(frontier, fullSamples.count)...])
        if tail.count >= Int(AudioRecorder.targetSampleRate * 0.3) {
            // The tail is post-last-pause, so treat it as single-language.
            let lang: String? = language == "auto"
                ? await TranscriptionService.shared.detectLanguageAuto(tail)
                : language
            let text = (try? await TranscriptionService.shared.decodeChunk(
                samples: tail, model: model, language: lang
            )) ?? ""
            VaniLog.log(String(format: "tail %.1fs [%@] → %d chars",
                Double(tail.count) / Double(Self.sampleRate), lang ?? "auto", text.count))
            if text.isEmpty {
                // A silent tail is plausible (trailing room tone), but we
                // can't tell it apart from a failed decode — replay the
                // whole buffer classically rather than risk dropped words.
                VaniLog.log("empty tail → classic full decode")
                return nil
            }
            parts.append(text)
        }
        VaniLog.log("incremental finish: \(parts.count) parts, frontier \(frontier)")
        return parts.joined(separator: " ")
    }

    private func decodeNewlyClosedChunks(in samples: [Float]) async {
        guard samples.count > Self.activateAfterSeconds.samples else { return }
        guard frontier < samples.count else { return }

        let region = Array(samples[frontier...])
        let segments = TranscriptionService.speechSegments(in: region)
        var closed = SpeechSegmenter.closedSegments(
            segments: segments, totalSamples: region.count
        )

        // No pause for a very long time: force a split at the quietest
        // stretch near the limit so the backlog can't grow unbounded.
        if closed.isEmpty, region.count > Self.maxOpenSeconds.samples {
            let cut = SpeechSegmenter.quietestSplit(
                in: region,
                searchRange: (Self.maxOpenSeconds - 6).samples..<Self.maxOpenSeconds.samples
            )
            closed = [(start: 0, end: cut)]
        }

        guard let first = closed.first, !Task.isCancelled else { return }

        let seg: (start: Int, end: Int)
        if emptyAtFrontier {
            // Retry the nulled-out span merged with the next closed segment.
            guard closed.count >= 2 else { return }
            seg = (start: first.start, end: closed[1].end)
        } else {
            seg = first
        }

        if seg.end - seg.start < Int(AudioRecorder.targetSampleRate * 0.5) {
            // A sub-half-second blip (click, breath) isn't dictation;
            // Whisper legitimately returns nothing for these, so decode
            // nothing and don't treat the emptiness as an anomaly.
            VaniLog.log(String(format: "skip blip %.1f-%.1fs",
                Double(frontier + seg.start) / Double(Self.sampleRate),
                Double(frontier + seg.end) / Double(Self.sampleRate)))
            frontier += seg.end
            return
        }
        let chunk = Array(region[seg.start..<min(seg.end, region.count)])
        let lang: String? = language == "auto"
            ? await TranscriptionService.shared.detectLanguageAuto(chunk)
            : language
        var rms: Float = 0
        for s in chunk { rms += s * s }
        rms = (rms / Float(max(chunk.count, 1))).squareRoot()
        do {
            let started = Date()
            let text = try await TranscriptionService.shared.decodeChunk(
                samples: chunk, model: model, language: lang
            )
            VaniLog.log(String(format: "chunk %.1f-%.1fs [%@] rms %.4f → %d chars in %.2fs%@",
                Double(frontier + seg.start) / Double(Self.sampleRate),
                Double(frontier + seg.end) / Double(Self.sampleRate),
                lang ?? "auto", rms, text.count, Date().timeIntervalSince(started),
                emptyAtFrontier ? " (merged retry)" : ""))
            guard !text.isEmpty else {
                if emptyAtFrontier {
                    // Even with the next phrase appended it decoded empty —
                    // that's no longer explainable as a filler. Replay
                    // everything classically.
                    degraded = true
                } else {
                    emptyAtFrontier = true
                }
                return
            }
            parts.append(text)
            frontier += seg.end
            emptyAtFrontier = false
            // Segment indices are relative to the old frontier; simplest
            // correct move is one chunk per pass and re-segment next tick.
            return
        } catch {
            VaniLog.log("chunk decode threw: \(error.localizedDescription) → degraded")
            degraded = true
            return
        }
    }
}

private extension Double {
    /// Seconds → samples at the recorder's 16 kHz rate.
    var samples: Int { Int(self * AudioRecorder.targetSampleRate) }
}
