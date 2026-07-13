import Foundation
import VaniCore

private func fmt(_ pairs: [TranscriptDiff.Mishear]) -> String {
    pairs.map { "\($0.heard)→\($0.expected)" }.joined(separator: ",")
}

func correctionDetectorTests() {
    // Classic re-dictation: one wrong word in a longer sentence.
    expect(
        fmt(CorrectionDetector.candidates(
            previous: "Send the draft to Bonnie by Friday.",
            current: "to Vani by"
        )),
        "Bonnie→Vani"
    )
    // Single-word re-dictation.
    expect(
        fmt(CorrectionDetector.candidates(
            previous: "The kernel panicked under load.",
            current: "colonel"
        ).map { TranscriptDiff.Mishear(heard: $0.heard, expected: $0.expected) }),
        "kernel→colonel"
    )
    // A genuinely new sentence (mostly different words) is not a correction.
    expect(
        fmt(CorrectionDetector.candidates(
            previous: "Send the draft to Bonnie by Friday.",
            current: "schedule lunch tomorrow please"
        )),
        ""
    )
    // Identical follow-up → nothing.
    expect(
        fmt(CorrectionDetector.candidates(
            previous: "ship it today",
            current: "ship it today"
        )),
        ""
    )
    // Long follow-up (7+ words) is dictation, not correction.
    expect(
        fmt(CorrectionDetector.candidates(
            previous: "one two three",
            current: "this is a whole new long sentence here"
        )),
        ""
    )
}

func contextBoostTests() {
    // Distinctive-term extraction: camelCase, dotted, long; not short/common.
    expect(
        ContextBoost.terms(from: "open DictationController.swift and the readme now")
            .joined(separator: ","),
        "DictationController.swift"
    )
    // Near-miss word snaps to the clipboard term.
    expect(
        ContextBoost.correct("we deployed cubernetes today", terms: ["Kubernetes"]),
        "we deployed Kubernetes today"
    )
    // Punctuation around the word survives.
    expect(
        ContextBoost.correct("check langchain, then ship", terms: ["LangChain"]),
        "check langchain, then ship"  // distance 0 after fold → leave as-is
    )
    expect(
        ContextBoost.correct("check langchan, then ship", terms: ["LangChain"]),
        "check LangChain, then ship"
    )
    // Too far away → untouched; short words never touched.
    expect(
        ContextBoost.correct("the cat sat on the mat", terms: ["Kubernetes"]),
        "the cat sat on the mat"
    )
    // Common word near a term but under the distance budget rules.
    expect(
        ContextBoost.correct("that dictation was fast", terms: ["DictationController"]),
        "that dictation was fast"
    )
}
