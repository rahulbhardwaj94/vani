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

    init(model: String, language: String, snapshot: @escaping () -> [Float]) {
        self.model = model
        self.language = language
        self.snapshot = snapshot
    }

    func start() {
        monitor = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Self.tickSeconds))
                guard !Task.isCancelled, let self else { return }
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
        guard frontier > 0 else { return nil }

        let tail = Array(fullSamples[min(frontier, fullSamples.count)...])
        if tail.count >= Int(AudioRecorder.targetSampleRate * 0.3) {
            // The tail is post-last-pause, so treat it as single-language:
            // detect (cheap, small model) and decode with running context.
            let lang: String? = language == "auto"
                ? await TranscriptionService.shared.detectLanguageAuto(tail)
                : language
            if let text = try? await TranscriptionService.shared.decodeChunk(
                samples: tail, model: model, language: lang
            ), !text.isEmpty {
                parts.append(text)
            }
        }
        NSLog("Vani: incremental finish — %d chunks pre-decoded, %.1fs tail",
              parts.count, Double(tail.count) / Double(Self.sampleRate))
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

        for seg in closed {
            guard !Task.isCancelled else { return }
            let chunk = Array(region[seg.start..<min(seg.end, region.count)])
            let lang: String? = language == "auto"
                ? await TranscriptionService.shared.detectLanguageAuto(chunk)
                : language
            do {
                let text = try await TranscriptionService.shared.decodeChunk(
                    samples: chunk, model: model, language: lang
                )
                if !text.isEmpty { parts.append(text) }
                // Advance even for empty text: the audio was silence/noise.
                frontier += seg.end
                // Segment indices after the first are relative to the old
                // frontier; simplest correct move is one chunk per pass and
                // re-segment next tick from the new frontier.
                return
            } catch {
                // Leave the frontier: the tail decode at finish() covers
                // everything after it, so a failed chunk costs latency only.
                NSLog("Vani: incremental chunk decode failed: %@", error.localizedDescription)
                return
            }
        }
    }
}

private extension Double {
    /// Seconds → samples at the recorder's 16 kHz rate.
    var samples: Int { Int(self * AudioRecorder.targetSampleRate) }
}
