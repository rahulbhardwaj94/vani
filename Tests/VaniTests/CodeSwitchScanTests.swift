import Foundation
import VaniCore

func codeSwitchScanTests() {
    let rate = 16_000
    let window = Int(1.5 * Double(rate))

    /// Runs the async scan synchronously for the plain test runner.
    func scan(
        total: Int,
        detect: @escaping (Range<Int>) -> String?,
        splitPoint: @escaping (Range<Int>) -> Int = { $0.lowerBound + $0.count / 2 }
    ) -> [CodeSwitchScan.Run]? {
        var result: [CodeSwitchScan.Run]?
        let sem = DispatchSemaphore(value: 0)
        Task {
            result = await CodeSwitchScan.runs(
                totalSamples: total, windowSamples: window,
                detect: { detect($0) }, splitPoint: splitPoint
            )
            sem.signal()
        }
        sem.wait()
        return result
    }

    // Monolingual span: head and tail agree → no split.
    expect(String(describing: scan(total: 10 * rate) { _ in "en" }), "nil")

    // Too short to window (head and tail would overlap the switch region).
    expect(String(describing: scan(total: window * 2 - 1) { _ in "en" }), "nil")

    // Unknown verdict at an endpoint (ID misfire, implausible language):
    // never guess — no split.
    expect(String(describing: scan(total: 10 * rate) { range in
        range.lowerBound == 0 ? nil : "hi"
    }), "nil")

    // en→hi switch at 6.0 s of 10 s: majority-vote detector flips where the
    // window center crosses the boundary.
    let boundary = 6 * rate
    var interval: Range<Int>?
    let runs = scan(
        total: 10 * rate,
        detect: { range in
            let center = range.lowerBound + range.count / 2
            return center < boundary ? "en" : "hi"
        },
        splitPoint: { interval = $0; return $0.lowerBound + $0.count / 2 }
    )
    expect(String(runs?.count ?? 0), "2")
    expect(runs?.first?.language ?? "", "en")
    expect(runs?.last?.language ?? "", "hi")
    // The true boundary lies inside the interval handed to splitPoint, and
    // the runs tile the span exactly around the returned cut.
    expect(String(interval.map { $0.contains(boundary) } ?? false), "true")
    expect(String(runs?.first?.start ?? -1), "0")
    expect(String(runs?.first?.end == runs?.last?.start), "true")
    expect(String(runs?.last?.end ?? -1), String(10 * rate))
}
