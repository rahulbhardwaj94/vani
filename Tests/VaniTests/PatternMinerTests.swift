import Foundation
import VaniCore

/// Fixed calendar so weekday/week math never depends on the machine's locale.
private let utc: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    return c
}()

private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> Date {
    utc.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!
}

private func ev(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int, words: Int = 40) -> DictationEvent {
    DictationEvent(date: date(y, mo, d, h, mi), words: words)
}

private func fmt(_ patterns: [Pattern]) -> String {
    patterns.map { p in
        let wds = p.weekdaySet.sorted().map(String.init).joined(separator: ",")
        return "wd[\(wds)]@\(p.hour) c=\(String(format: "%.2f", p.confidence))"
    }.joined(separator: " | ")
}

private func fmt(_ pattern: Pattern?) -> String {
    pattern.map { fmt([$0]) } ?? "none"
}

func patternMinerTests() {
    // 2026-06-01 is a Monday (weekday 2). All fixtures live in June 2026 so
    // no week-of-year boundary is in play.

    // Three Mondays around 9:00 (±10 min) across three weeks; the stray
    // Wednesday event shares a week with Jun 8 so it neither forms a cluster
    // nor adds a qualifying week.
    let mondayMornings = [
        ev(2026, 6, 1, 9, 0),
        ev(2026, 6, 8, 9, 10),
        ev(2026, 6, 10, 14, 0),
        ev(2026, 6, 15, 8, 55),
    ]
    expect(
        fmt(PatternMiner.patterns(in: mondayMornings, now: date(2026, 6, 16, 12, 0), calendar: utc)),
        "wd[2]@9 c=1.00"
    )

    // A fourth observed week without a morning hit dilutes confidence to 3/4;
    // the lone 20:00 event is a single occurrence, so no second pattern.
    let withMissedWeek = mondayMornings + [ev(2026, 6, 22, 20, 0)]
    expect(
        fmt(PatternMiner.patterns(in: withMissedWeek, now: date(2026, 6, 22, 21, 0), calendar: utc)),
        "wd[2]@9 c=0.75"
    )

    // Monday and Wednesday clusters at the same hour merge into one habit.
    let monWed = [
        ev(2026, 6, 1, 9, 0), ev(2026, 6, 8, 9, 0), ev(2026, 6, 15, 9, 0),
        ev(2026, 6, 3, 9, 5), ev(2026, 6, 10, 9, 5), ev(2026, 6, 17, 9, 5),
    ]
    expect(
        fmt(PatternMiner.patterns(in: monWed, now: date(2026, 6, 18, 12, 0), calendar: utc)),
        "wd[2,4]@9 c=1.00"
    )

    // Two occurrences are below the habit threshold.
    expect(
        fmt(PatternMiner.patterns(
            in: [ev(2026, 6, 1, 9, 0), ev(2026, 6, 8, 9, 0)],
            now: date(2026, 6, 9, 12, 0), calendar: utc
        )),
        ""
    )

    // Three dictations in one morning: enough occurrences but a single week —
    // a work session, not a routine.
    expect(
        fmt(PatternMiner.patterns(
            in: [ev(2026, 6, 1, 9, 0), ev(2026, 6, 1, 9, 15), ev(2026, 6, 1, 9, 30)],
            now: date(2026, 6, 2, 12, 0), calendar: utc
        )),
        ""
    )

    // Scattered days and hours never land three-in-a-window on one weekday.
    let scattered = [
        ev(2026, 6, 1, 7, 0), ev(2026, 6, 2, 13, 30), ev(2026, 6, 4, 22, 10),
        ev(2026, 6, 9, 6, 45), ev(2026, 6, 11, 16, 20), ev(2026, 6, 13, 11, 0),
        ev(2026, 6, 16, 19, 40), ev(2026, 6, 18, 9, 15),
    ]
    expect(
        fmt(PatternMiner.patterns(in: scattered, now: date(2026, 6, 19, 12, 0), calendar: utc)),
        ""
    )

    // Empty history.
    expect(fmt(PatternMiner.patterns(in: [], now: date(2026, 6, 16, 12, 0), calendar: utc)), "")

    // Imminence. Cluster center for mondayMornings is 9:01 (mean of 8:55,
    // 9:00, 9:10), so the window opens at 8:16.
    // 8:05 Monday → opens in 11 min: imminent.
    expect(
        fmt(PatternMiner.imminentPattern(in: mondayMornings, now: date(2026, 6, 22, 8, 5), calendar: utc)),
        "wd[2]@9 c=1.00"
    )
    // 8:00 Monday → 16 min out, just beyond the lead.
    expect(
        fmt(PatternMiner.imminentPattern(in: mondayMornings, now: date(2026, 6, 22, 8, 0), calendar: utc)),
        "none"
    )
    // 8:59 Monday → window already open; suggestions come before the habitual
    // moment, not during it.
    expect(
        fmt(PatternMiner.imminentPattern(in: mondayMornings, now: date(2026, 6, 22, 8, 59), calendar: utc)),
        "none"
    )
    // Tuesday morning → wrong weekday entirely.
    expect(
        fmt(PatternMiner.imminentPattern(in: mondayMornings, now: date(2026, 6, 23, 8, 5), calendar: utc)),
        "none"
    )
}
