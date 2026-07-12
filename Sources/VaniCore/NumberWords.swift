import Foundation

/// Number words → digits for code mode: "port eighty eighty" → `port 8080`,
/// "twenty twenty six" → `2026`, "one hundred and five" → `105`.
///
/// Two composition rules cover how people actually speak numbers:
/// - a run of single digits concatenates: "eight zero eight zero" → 8080
/// - otherwise words compose arithmetically into groups ("three thousand
///   two hundred" → 3200), and *adjacent* groups concatenate — which is
///   exactly how ports and years are spoken ("eighty eighty", "twenty
///   twenty six").
/// A lone "one" stays a word ("the one thing that matters").
public enum NumberWords {
    private static let units: [String: Int] = [
        "zero": 0, "one": 1, "two": 2, "three": 3, "four": 4,
        "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9,
    ]
    private static let teens: [String: Int] = [
        "ten": 10, "eleven": 11, "twelve": 12, "thirteen": 13, "fourteen": 14,
        "fifteen": 15, "sixteen": 16, "seventeen": 17, "eighteen": 18, "nineteen": 19,
    ]
    private static let tens: [String: Int] = [
        "twenty": 20, "thirty": 30, "forty": 40, "fifty": 50,
        "sixty": 60, "seventy": 70, "eighty": 80, "ninety": 90,
    ]

    private static let runPattern: NSRegularExpression = {
        let words = (units.keys.map { $0 } + teens.keys + tens.keys + ["hundred", "thousand"])
            .joined(separator: "|")
        // Number words chained by spaces/hyphens, with "and" allowed only
        // *between* number words ("one hundred and five").
        return try! NSRegularExpression(
            pattern: #"(?i)(?<![\w-])(?:"# + words + #")(?:[\s-]+(?:and[\s-]+)?(?:"# + words + #"))*(?![\w-])"#
        )
    }()

    public static func apply(to text: String) -> String {
        let matches = runPattern.matches(
            in: text, range: NSRange(text.startIndex..., in: text)
        ).reversed()
        var result = text
        for match in matches {
            guard let range = Range(match.range, in: result) else { continue }
            let phrase = String(result[range])
            guard let digits = convert(phrase) else { continue }
            result.replaceSubrange(range, with: digits)
        }
        return result
    }

    /// nil = leave the phrase as words.
    private static func convert(_ phrase: String) -> String? {
        let words = phrase.lowercased()
            .split(whereSeparator: { $0 == " " || $0 == "-" || $0 == "\n" })
            .map(String.init)
            .filter { $0 != "and" }
        guard !words.isEmpty else { return nil }
        if words == ["one"] { return nil }

        // All single digits (and more than one of them): concatenate.
        if words.count > 1, words.allSatisfy({ units[$0] != nil }) {
            return words.map { String(units[$0]!) }.joined()
        }

        // Arithmetic groups; adjacent groups concatenate their digits.
        var groups: [Int] = []
        var current = 0   // running value of the open group
        var partial = 0   // value since the last "thousand"
        var open = false
        var last = ""     // previous word class: u/teen/tens/hundred/thousand

        func close() {
            if open { groups.append(current + partial) }
            current = 0; partial = 0; open = false; last = ""
        }
        for word in words {
            if let u = units[word] {
                if ["u", "teen"].contains(last) || (last == "tens" && u == 0) { close() }
                if last == "tens", u == 0 { close() }
                partial += u; open = true
                last = "u"
            } else if let t = teens[word] {
                if ["u", "teen", "tens"].contains(last) { close() }
                partial += t; open = true
                last = "teen"
            } else if let t = tens[word] {
                if ["u", "teen", "tens"].contains(last) { close() }
                partial += t; open = true
                last = "tens"
            } else if word == "hundred" {
                guard open, ["u", "teen"].contains(last) else { return nil }
                partial *= 100
                last = "hundred"
            } else { // thousand
                guard open else { return nil }
                current += max(partial, 1) * 1000
                partial = 0
                last = "thousand"
            }
        }
        close()
        guard !groups.isEmpty else { return nil }
        return groups.map(String.init).joined()
    }
}
