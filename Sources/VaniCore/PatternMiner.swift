import Foundation

/// A completed dictation reduced to when it happened and how much was said.
/// `words` is carried so future scoring can weight substantial sessions over
/// one-word corrections; the miner currently treats every event equally.
public struct DictationEvent {
    public let date: Date
    public let words: Int

    public init(date: Date, words: Int) {
        self.date = date
        self.words = words
    }
}

/// A recurring dictation habit: "dictates around `hour`:00 on these weekdays".
public struct Pattern: Equatable {
    /// Calendar weekday numbers (1 = Sunday in the Gregorian calendar).
    public let weekdaySet: Set<Int>
    /// The cluster center rounded to the nearest whole hour — the value shown
    /// to the user; scheduling math uses `minuteOfDay`.
    public let hour: Int
    /// Cluster center in minutes after midnight. The habit's window is
    /// `PatternMiner.windowHalfWidthMinutes` either side of this.
    public let minuteOfDay: Int
    /// Fraction of the observed weeks that hit the window, in 0...1
    /// (averaged when several weekdays merge into one pattern).
    public let confidence: Double

    public init(weekdaySet: Set<Int>, hour: Int, minuteOfDay: Int, confidence: Double) {
        self.weekdaySet = weekdaySet
        self.hour = hour
        self.minuteOfDay = minuteOfDay
        self.confidence = confidence
    }
}

/// Mines dictation history for time-of-day / day-of-week habits so the app
/// can offer quiet suggestions ("you usually dictate standup notes now").
///
/// All date math goes through the injected `Calendar` — never the current
/// locale or timezone — so results are reproducible in tests.
public enum PatternMiner {
    /// Events within ± this of a cluster center count as the same habit.
    public static let windowHalfWidthMinutes = 45
    /// Suggest a pattern when its window opens within this many minutes.
    public static let imminentLeadMinutes = 15

    /// Fewer repetitions than this is coincidence, not habit.
    static let minOccurrences = 3
    /// Repetitions must span weeks — three dictations in one morning are a
    /// work session, not a routine.
    static let minDistinctWeeks = 2
    /// Habits older than this stop influencing suggestions; schedules drift.
    static let lookbackWeeks = 8

    /// Recurring clusters, strongest first. Confidence is the fraction of
    /// weeks-with-any-dictation that also hit the cluster's window, so a
    /// vacation week with no dictation at all doesn't dilute a solid habit.
    public static func patterns(in events: [DictationEvent], now: Date, calendar: Calendar) -> [Pattern] {
        guard let cutoff = calendar.date(byAdding: .weekOfYear, value: -lookbackWeeks, to: now) else {
            return []
        }
        let recent = events.filter { $0.date >= cutoff && $0.date <= now }
        guard !recent.isEmpty else { return [] }

        struct Occurrence {
            let weekday: Int
            let minute: Int
            let week: Int // yearForWeekOfYear * 100 + weekOfYear — unique per calendar week
        }
        var occurrences: [Occurrence] = []
        var observedWeeks = Set<Int>()
        for event in recent {
            let c = calendar.dateComponents(
                [.weekday, .hour, .minute, .weekOfYear, .yearForWeekOfYear],
                from: event.date
            )
            guard let weekday = c.weekday, let hour = c.hour, let minute = c.minute,
                  let weekOfYear = c.weekOfYear, let weekYear = c.yearForWeekOfYear else { continue }
            let week = weekYear * 100 + weekOfYear
            observedWeeks.insert(week)
            occurrences.append(Occurrence(weekday: weekday, minute: hour * 60 + minute, week: week))
        }
        guard !observedWeeks.isEmpty else { return [] }

        // Per-weekday greedy clustering over sorted minute-of-day: a run ends
        // when the next event falls outside the full window width from the
        // run's earliest member. Anchoring on the earliest keeps the split
        // deterministic without iterative center refitting.
        struct Cluster {
            let weekday: Int
            let center: Int
            let confidence: Double
        }
        var clusters: [Cluster] = []
        for weekday in 1...7 {
            let day = occurrences
                .filter { $0.weekday == weekday }
                .sorted { ($0.minute, $0.week) < ($1.minute, $1.week) }
            var i = 0
            while i < day.count {
                var j = i
                while j + 1 < day.count,
                      day[j + 1].minute - day[i].minute <= windowHalfWidthMinutes * 2 {
                    j += 1
                }
                let run = day[i...j]
                let hitWeeks = Set(run.map(\.week))
                if run.count >= minOccurrences, hitWeeks.count >= minDistinctWeeks {
                    clusters.append(Cluster(
                        weekday: weekday,
                        center: run.map(\.minute).reduce(0, +) / run.count,
                        confidence: Double(hitWeeks.count) / Double(observedWeeks.count)
                    ))
                }
                i = j + 1
            }
        }

        // Weekdays whose clusters land on the same hour are one habit
        // ("weekday mornings"), not five separate patterns.
        var byHour: [Int: [Cluster]] = [:]
        for cluster in clusters {
            let hour = ((cluster.center + 30) / 60) % 24
            byHour[hour, default: []].append(cluster)
        }
        return byHour
            .map { hour, group in
                Pattern(
                    weekdaySet: Set(group.map(\.weekday)),
                    hour: hour,
                    minuteOfDay: group.map(\.center).reduce(0, +) / group.count,
                    confidence: group.map(\.confidence).reduce(0, +) / Double(group.count)
                )
            }
            .sorted {
                if $0.confidence != $1.confidence { return $0.confidence > $1.confidence }
                if $0.hour != $1.hour { return $0.hour < $1.hour }
                return ($0.weekdaySet.min() ?? 0) < ($1.weekdaySet.min() ?? 0)
            }
    }

    /// The strongest pattern whose window opens within the next
    /// `imminentLeadMinutes`, if any. A window already underway returns nil —
    /// the point is to suggest *before* the habitual moment, not during it.
    public static func imminentPattern(in events: [DictationEvent], now: Date, calendar: Calendar) -> Pattern? {
        let nowWeekday = calendar.component(.weekday, from: now)
        let nowMinute = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        for pattern in patterns(in: events, now: now, calendar: calendar) {
            for weekday in pattern.weekdaySet {
                var start = pattern.minuteOfDay - windowHalfWidthMinutes
                var startDay = weekday
                if start < 0 { // window opens late the previous day
                    start += 24 * 60
                    startDay = startDay == 1 ? 7 : startDay - 1
                }
                let dayDelta = (startDay - nowWeekday + 7) % 7
                let lead = dayDelta * 24 * 60 + start - nowMinute
                if lead >= 0, lead <= imminentLeadMinutes {
                    return pattern
                }
            }
        }
        return nil
    }
}
