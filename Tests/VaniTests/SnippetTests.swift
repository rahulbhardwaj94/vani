import Foundation
import VaniCore

/// Snippet expansion = the vocabulary engine with trailing-punctuation
/// swallowing. These tests pin the snippet-specific behaviors.
func snippetTests() {
    let signOff = VocabularyRule(
        find: "email sign off",
        replace: "Best regards,\nRahul Bhardwaj"
    )

    // Multi-line expansion, and Whisper's trigger-pause period is swallowed.
    expect(
        VocabularyRules.apply(rules: [signOff],
                              to: "Thanks for the update. Email sign off.",
                              swallowTrailingPunctuation: true),
        "Thanks for the update. Best regards,\nRahul Bhardwaj"
    )

    // Mid-sentence trigger expands in place; comma after it is swallowed.
    expect(
        VocabularyRules.apply(rules: [signOff],
                              to: "email sign off, and send it",
                              swallowTrailingPunctuation: true),
        "Best regards,\nRahul Bhardwaj and send it"
    )

    // Partial phrase does not trigger.
    expect(
        VocabularyRules.apply(rules: [signOff],
                              to: "the email sign was broken",
                              swallowTrailingPunctuation: true),
        "the email sign was broken"
    )

    // Vocabulary rules (no swallowing) keep punctuation intact — unchanged
    // behavior guard.
    expect(
        VocabularyRules.apply(rules: [VocabularyRule(find: "vani", replace: "Vani")],
                              to: "use vani."),
        "use Vani."
    )
}
