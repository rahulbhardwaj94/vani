import Foundation
import VaniCore

func symbolCommandsTests() {
    // The killer terminal cases.
    expect(SymbolCommands.apply(to: "git commit dash m"), "git commit -m")
    expect(SymbolCommands.apply(to: "ls pipe grep foo"), "ls | grep foo")
    expect(SymbolCommands.apply(to: "cd src slash components"), "cd src/components")
    expect(SymbolCommands.apply(to: "open server dot js"), "open server.js")

    // Whisper punctuating the pause after a symbol still resolves.
    expect(SymbolCommands.apply(to: "ls pipe, grep foo"), "ls | grep foo")

    // Identifier plumbing.
    expect(SymbolCommands.apply(to: "user underscore name"), "user_name")
    expect(SymbolCommands.apply(to: "key colon value"), "key: value")
    expect(SymbolCommands.apply(to: "a fat arrow b"), "a => b")
    expect(SymbolCommands.apply(to: "x double equals y"), "x == y")
    expect(SymbolCommands.apply(to: "count equals count plus one"), "count = count + 1"
        .replacingOccurrences(of: "1", with: "one")) // digits aren't ours to convert

    // Bracket pairs glue inward.
    expect(SymbolCommands.apply(to: "open paren x close paren"), "(x)")
    expect(SymbolCommands.apply(to: "open brace close brace"), "{}")

    // Prefix symbols glue right.
    expect(SymbolCommands.apply(to: "at sign main actor"), "@main actor")
    expect(SymbolCommands.apply(to: "dollar sign home"), "$home")

    // Words containing trigger substrings stay intact.
    expect(SymbolCommands.apply(to: "update the dashboard"), "update the dashboard")
    expect(SymbolCommands.apply(to: "the pipeline is fast"), "the pipeline is fast")
    expect(SymbolCommands.apply(to: "adopt the protocol"), "adopt the protocol")
}

func languageSmoothingTests() {
    let sr = 16_000
    // A 1s filler between two long English runs loses its bogus "hi" tag.
    expect(
        SpeechSegmenter.smoothLanguages(
            segments: [(0, sr * 5), (sr * 5, sr * 6), (sr * 6, sr * 11)],
            languages: ["en", "hi", "en"]
        ).joined(separator: ","),
        "en,en,en"
    )
    // A genuinely long Hindi run keeps its own detection.
    expect(
        SpeechSegmenter.smoothLanguages(
            segments: [(0, sr * 5), (sr * 5, sr * 9)],
            languages: ["en", "hi"]
        ).joined(separator: ","),
        "en,hi"
    )
    // Short segment attaches to the *nearest* long neighbor.
    expect(
        SpeechSegmenter.smoothLanguages(
            segments: [(0, sr * 4), (sr * 8, sr * 9), (sr * 9, sr * 14)],
            languages: ["en", "en", "hi"]
        ).joined(separator: ","),
        "en,hi,hi"
    )
    // Everything short → nothing to anchor on, unchanged.
    expect(
        SpeechSegmenter.smoothLanguages(
            segments: [(0, sr), (sr, sr * 2)],
            languages: ["en", "hi"]
        ).joined(separator: ","),
        "en,hi"
    )
}
