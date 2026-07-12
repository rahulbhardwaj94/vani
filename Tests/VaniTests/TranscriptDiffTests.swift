import Foundation
import VaniCore

private func fmt(_ mishears: [TranscriptDiff.Mishear]) -> String {
    mishears.map { "\($0.heard)→\($0.expected)" }.joined(separator: ",")
}

func transcriptDiffTests() {
    // The classic field mishear: name + split technical term.
    expect(
        fmt(TranscriptDiff.mishears(
            expected: "Vani uses CoreML on my Mac.",
            heard: "Bonnie uses core ml on my Mac."
        )),
        "Bonnie→Vani,core ml→CoreML"
    )

    // Identical (modulo punctuation) → nothing to learn.
    expect(
        fmt(TranscriptDiff.mishears(
            expected: "Hello world, this works.",
            heard: "Hello world this works"
        )),
        ""
    )

    // Case-only difference is a learnable casing rule.
    expect(
        fmt(TranscriptDiff.mishears(
            expected: "I speak Hindi every day.",
            heard: "I speak hindi every day."
        )),
        "hindi→Hindi"
    )

    // Missing word (pure deletion) is not a rule — nothing to match on.
    expect(
        fmt(TranscriptDiff.mishears(
            expected: "the quick brown fox",
            heard: "the brown fox"
        )),
        ""
    )

    // Multi-word substitution run stays one suggestion.
    expect(
        fmt(TranscriptDiff.mishears(
            expected: "the large-v3-turbo model",
            heard: "the large V3 turbo model"
        )),
        "large V3 turbo→large-v3-turbo"
    )

    // Devanagari alignment works.
    expect(
        fmt(TranscriptDiff.mishears(
            expected: "मेरा नाम राहुल है",
            heard: "मेरा नाम राहुल हैं"
        )),
        "हैं→है"
    )

    // Empty heard → no crash, no suggestions.
    expect(fmt(TranscriptDiff.mishears(expected: "anything", heard: "")), "")
}
