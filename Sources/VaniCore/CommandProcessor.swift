import Foundation

/// Spoken punctuation & commands — deterministic and rule-based, never LLM
/// (on-brand: Vani never rewrites you). English and Hindi triggers, matched
/// only as standalone whole phrases:
///
///   "first point new line second point"  →  "first point\nSecond point"
///   "are you coming question mark"       →  "are you coming?"
///   "…blah blah scratch that"            →  "" (utterance discarded)
///
/// A phrase preceded by an article stays literal, so "I added a new line of
/// code" is untouched.
public enum CommandProcessor {

    /// Applies all commands. Returns "" when the utterance ends with a
    /// discard command ("scratch that" / "रहने दो") — callers already treat
    /// an empty transcript as nothing-to-paste.
    public static func apply(to text: String) -> String {
        if discardPattern.firstMatch(in: text, range: fullRange(text)) != nil {
            return ""
        }
        var result = text
        for command in commands {
            result = command.pattern.stringByReplacingMatches(
                in: result, range: fullRange(result), withTemplate: command.template
            )
        }
        result = tidy(result)
        result = capitalizingSentenceStarts(result)
        return result
    }

    // MARK: - Command table

    private struct Command {
        let pattern: NSRegularExpression
        let template: String
    }

    /// Commands are skipped after an article/determiner so phrases used as
    /// nouns ("a new line of code", "add a comma here") stay literal.
    private static let articleGuard = #"(?<!\b(?:a|an|the|एक)\s)"#

    /// Line/paragraph breaks swallow surrounding whitespace and one trailing
    /// "." or "," (Whisper often punctuates the command itself: "New line.").
    private static func breakCommand(_ phrases: [String], insert: String) -> Command {
        Command(
            pattern: regex(#"\s*"# + articleGuard + #"(?<!\w)(?:"# + alternation(phrases) + #")(?!\w)[.,]?\s*"#),
            template: NSRegularExpression.escapedTemplate(for: insert)
        )
    }

    /// Punctuation commands attach to the previous word: leading whitespace
    /// (and a comma Whisper put before the command) is swallowed, as is one
    /// trailing punctuation mark.
    private static func punctuationCommand(_ phrases: [String], symbol: String) -> Command {
        Command(
            pattern: regex(#"\s*(?:,\s*)?"# + articleGuard + #"(?<!\w)(?:"# + alternation(phrases) + #")(?!\w)[.,!?]?"#),
            template: NSRegularExpression.escapedTemplate(for: symbol)
        )
    }

    private static let commands: [Command] = [
        breakCommand(["new paragraph", "नया पैराग्राफ", "naya paragraph"], insert: "\n\n"),
        breakCommand(["new line", "नई लाइन", "nayi line", "nai line"], insert: "\n"),
        punctuationCommand(["full stop", "पूर्ण विराम", "purn viram", "poorna viram"], symbol: "."),
        punctuationCommand(["comma", "कॉमा"], symbol: ","),
        punctuationCommand(["question mark", "प्रश्न चिह्न", "prashn chinh"], symbol: "?"),
        punctuationCommand(["exclamation mark", "exclamation point"], symbol: "!"),
    ]

    /// "scratch that" (EN) / "रहने दो" (HI) at the end of the utterance
    /// discards the whole dictation.
    private static let discardPattern = regex(
        #"(?:^|\s)(?:"# + alternation(["scratch that", "रहने दो", "rehne do", "rahne do"]) + #")\s*[.!,]?\s*$"#
    )

    // MARK: - Helpers

    private static func alternation(_ phrases: [String]) -> String {
        phrases
            .map {
                NSRegularExpression.escapedPattern(for: $0)
                    .replacingOccurrences(of: " ", with: #"\s+"#)
            }
            .joined(separator: "|")
    }

    private static func regex(_ pattern: String) -> NSRegularExpression {
        try! NSRegularExpression(pattern: "(?i)" + pattern)
    }

    private static func fullRange(_ s: String) -> NSRange {
        NSRange(s.startIndex..., in: s)
    }

    /// Collapses spacing artifacts the replacements can leave behind, without
    /// touching intentional newlines.
    private static func tidy(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: #"[ \t]{2,}"#, with: " ", options: .regularExpression)
        result = result.replacingOccurrences(of: #"[ \t]+\n"#, with: "\n", options: .regularExpression)
        result = result.replacingOccurrences(of: #"\n[ \t]+"#, with: "\n", options: .regularExpression)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Inserted "." and newlines start a new sentence; Whisper only
    /// capitalizes the sentences it punctuated itself. (No-op for Devanagari,
    /// which has no case.)
    private static let sentenceStart = try! NSRegularExpression(pattern: #"(?:[.!?]\s+|\n)(\p{Ll})"#)

    private static func capitalizingSentenceStarts(_ text: String) -> String {
        var result = text
        for match in sentenceStart.matches(in: result, range: fullRange(result)).reversed() {
            guard let range = Range(match.range(at: 1), in: result) else { continue }
            result.replaceSubrange(range, with: result[range].uppercased())
        }
        return result
    }
}
