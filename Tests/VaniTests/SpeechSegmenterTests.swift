import Foundation
import VaniCore

/// Sample-rate the segmenter defaults to; keeps the fixtures readable in seconds.
private let sr = 16_000

/// Renders segments as "start-end,…" in whole samples for easy assertions.
private func fmt(_ segments: [(start: Int, end: Int)]) -> String {
    segments.map { "\($0.start)-\($0.end)" }.joined(separator: ",")
}

func speechSegmenterTests() {
    // A short pause (< 0.5 s) between two active runs stays a single segment.
    // Runs: [1.0s..2.0s] and [2.3s..3.0s], gap 0.3s → merged, then padded 0.1s.
    expect(
        fmt(SpeechSegmenter.merge(
            activeChunks: [(sr, sr * 2), (sr * 23 / 10, sr * 3)],
            totalSamples: sr * 4
        )),
        "14400-49600" // (1.0-0.1)s .. (3.0+0.1)s
    )

    // A real pause (≥ 0.5 s) splits into two segments — the code-switch case.
    // Runs: [1.0s..2.0s] and [2.6s..3.6s], gap 0.6s → two segments.
    expect(
        fmt(SpeechSegmenter.merge(
            activeChunks: [(sr, sr * 2), (sr * 26 / 10, sr * 36 / 10)],
            totalSamples: sr * 4
        )),
        "14400-33600,40000-59200"
    )

    // Padding clamps to the clip bounds (no negative start, no overrun).
    expect(
        fmt(SpeechSegmenter.merge(
            activeChunks: [(0, sr)],
            totalSamples: sr
        )),
        "0-16000"
    )

    // Noise blip shorter than 0.2 s is dropped.
    expect(
        fmt(SpeechSegmenter.merge(
            activeChunks: [(sr, sr + sr / 20)], // 0.05 s of audio
            totalSamples: sr * 2,
            padSeconds: 0 // isolate the min-length prune from padding
        )),
        ""
    )

    // Empty input → no segments.
    expect(fmt(SpeechSegmenter.merge(activeChunks: [], totalSamples: sr * 2)), "")

    // Three runs, first two close, third after a long gap → two segments.
    expect(
        fmt(SpeechSegmenter.merge(
            activeChunks: [(sr, sr * 2), (sr * 22 / 10, sr * 3), (sr * 4, sr * 5)],
            totalSamples: sr * 6,
            padSeconds: 0
        )),
        "16000-48000,64000-80000"
    )
}
