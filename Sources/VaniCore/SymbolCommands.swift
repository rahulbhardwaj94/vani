import Foundation

/// Spoken symbols for code mode: "git commit dash m" → `git commit -m`,
/// "ls pipe grep foo" → `ls | grep foo`, "server dot js" → `server.js`.
/// Only ever applied when the paste target is a terminal/editor, which is
/// what makes single-word triggers like "dash" and "dot" acceptable.
public enum SymbolCommands {
    /// How the symbol binds to its neighbors.
    private enum Attach {
        case both   // no space either side: dot, slash, underscore
        case right  // glues to the next word: dash (flags), openers, $ @ #
        case left   // glues to the previous word: closers, ; and : (space after stays)
        case spaced // ordinary infix token: pipe, arrows, equals
    }

    /// Multi-word phrases before their prefixes ("double equals" before "equals").
    private static let symbols: [(phrase: String, symbol: String, attach: Attach)] = [
        ("triple equals", "===", .spaced),
        ("double equals", "==", .spaced),
        ("fat arrow", "=>", .spaced),
        ("thin arrow", "->", .spaced),
        ("open paren", "(", .right),
        ("close paren", ")", .left),
        ("open brace", "{", .right),
        ("close brace", "}", .left),
        ("open bracket", "[", .right),
        ("close bracket", "]", .left),
        ("double quote", "\"", .spaced),
        ("single quote", "'", .spaced),
        ("less than", "<", .spaced),
        ("greater than", ">", .spaced),
        ("at sign", "@", .right),
        ("dollar sign", "$", .right),
        ("hash sign", "#", .right),
        ("percent sign", "%", .spaced),
        ("ampersand", "&", .spaced),
        ("backtick", "`", .spaced),
        ("underscore", "_", .both),
        ("backslash", "\\", .both),
        ("semicolon", ";", .left),
        ("colon", ":", .left),
        ("equals", "=", .spaced),
        ("pipe", "|", .spaced),
        ("slash", "/", .both),
        ("dash", "-", .right),
        ("dot", ".", .both),
        ("star", "*", .spaced),
        ("plus", "+", .spaced),
        ("tilde", "~", .right),
    ]

    public static func apply(to text: String) -> String {
        var result = text
        for entry in symbols {
            let phrase = entry.phrase.replacingOccurrences(of: " ", with: #"\s+"#)
            // Whisper may punctuate the pause after a spoken symbol — swallow
            // one trailing comma/period so "pipe," still becomes "|".
            let core = #"(?i)(?<!\w)"# + phrase + #"(?!\w)[.,]?"#
            let (pattern, template): (String, String) = switch entry.attach {
            case .both:   (#"\s*"# + core + #"\s*"#, escaped(entry.symbol))
            case .right:  (core + #"\s*"#, escaped(entry.symbol))
            case .left:   (#"\s*"# + core, escaped(entry.symbol))
            case .spaced: (core, escaped(entry.symbol))
            }
            result = result.replacingOccurrences(
                of: pattern, with: template, options: .regularExpression
            )
        }
        return result
    }

    /// Escape `$` and `\` for use in a regex replacement template.
    private static func escaped(_ symbol: String) -> String {
        symbol
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "$", with: "\\$")
    }
}
