import Foundation
import VaniCore

func casingCommandsTests() {
    // The headline: identifiers by voice.
    expect(CasingCommands.apply(to: "camel case get user name"), "getUserName")
    expect(CasingCommands.apply(to: "snake case get user name"), "get_user_name")
    expect(CasingCommands.apply(to: "kebab case main header view"), "main-header-view")
    expect(CasingCommands.apply(to: "pascal case dictation controller"), "DictationController")
    expect(CasingCommands.apply(to: "screaming snake case max retry count"), "MAX_RETRY_COUNT")

    // Whisper punctuates the pause after the identifier: casing stops there.
    expect(
        CasingCommands.apply(to: "rename it to camel case user profile store, then commit."),
        "rename it to userProfileStore, then commit."
    )

    // Capitalized command word (sentence start) still works.
    expect(CasingCommands.apply(to: "Camel case fetch results."), "fetchResults.")

    // An article keeps the phrase literal — talking *about* camel case.
    expect(
        CasingCommands.apply(to: "I prefer the camel case naming convention"),
        "I prefer the camel case naming convention"
    )

    // Two commands in one dictation.
    expect(
        CasingCommands.apply(to: "snake case user id, equals camel case fetch current user"),
        "user_id, equals fetchCurrentUser"
    )

    // No command → untouched.
    expect(CasingCommands.apply(to: "just a normal sentence"), "just a normal sentence")
}

func transcriptAccuracyTests() {
    // Two real mishears → 2 corrected words.
    expect(
        String(TranscriptDiff.correctedWordCount(
            raw: "Bonnie uses whisper kit on my Mac",
            final: "Vani uses WhisperKit on my Mac"
        )),
        "2"
    )
    // Case-only and filler-removal differences aren't mishears.
    expect(
        String(TranscriptDiff.correctedWordCount(
            raw: "um, hindi is great",
            final: "Hindi is great"
        )),
        "0"
    )
    // Perfect transcript → 0.
    expect(String(TranscriptDiff.correctedWordCount(raw: "hello world", final: "Hello world.")), "0")
}
