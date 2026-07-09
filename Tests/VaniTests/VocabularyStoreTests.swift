import VaniCore

private func apply(_ find: String, _ replace: String, to text: String) -> String {
    VocabularyRules.apply(rules: [VocabularyRule(find: find, replace: replace)], to: text)
}

func vocabularyRulesTests() {
    // Regression: a rule saved with a trailing space ("core ml ") used to
    // swallow the space after the match — "core ml to run" → "coreMLto run".
    expect(
        apply("core ml ", "coreML", to: "whisper kit with core ml to run"),
        "whisper kit with coreML to run"
    )

    // Case-insensitive match, replacement casing wins.
    expect(apply("core ml", "CoreML", to: "uses Core ML today"), "uses CoreML today")
    expect(apply("rb flow", "Vani", to: "I built RB Flow"), "I built Vani")

    // Whole words/phrases only.
    expect(apply("core ml", "CoreML", to: "score mlx models"), "score mlx models")
    expect(apply("ml", "ML", to: "html page"), "html page")

    // Whitespace inside a rule matches any whitespace run.
    expect(apply("core ml", "CoreML", to: "core  ml"), "CoreML")
    expect(apply("core ml", "CoreML", to: "core\nml"), "CoreML")

    // Every occurrence is replaced.
    expect(apply("core ml", "CoreML", to: "core ml and core ml"), "CoreML and CoreML")

    // Multiple rules all apply.
    expect(
        VocabularyRules.apply(
            rules: [
                VocabularyRule(find: "core ml", replace: "CoreML"),
                VocabularyRule(find: "whisper kit", replace: "WhisperKit"),
            ],
            to: "whisper kit uses core ml"
        ),
        "WhisperKit uses CoreML"
    )

    // Empty/blank find never matches.
    expect(apply("", "x", to: "unchanged"), "unchanged")
    expect(apply("   ", "x", to: "unchanged"), "unchanged")

    // Regex metacharacters in rules are literal, and symbol-edged rules
    // still match (no word boundary exists after "+").
    expect(apply("c++", "C++", to: "i like c++ a lot"), "i like C++ a lot")
}
