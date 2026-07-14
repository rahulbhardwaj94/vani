import Foundation
import VaniCore

func wavIOTests() {
    // Round trip: write → read returns the same samples (within 16-bit
    // quantization).
    let original: [Float] = (0..<16_000).map { sin(Float($0) * 0.01) * 0.5 }
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("vani-wavio-test.wav")
    defer { try? FileManager.default.removeItem(at: url) }

    do {
        try WavIO.writeMono16k(original, to: url)
        let read = try WavIO.readMono16k(url)
        expect(String(read.count), String(original.count))
        let maxError = zip(read, original).map { abs($0 - $1) }.max() ?? 1
        expect(String(maxError < 0.001), "true")
    } catch {
        expect("threw \(error)", "no throw")
    }

    // Garbage input is rejected, not crashed on.
    let bad = FileManager.default.temporaryDirectory
        .appendingPathComponent("vani-wavio-bad.wav")
    try? Data("not a wav at all".utf8).write(to: bad)
    defer { try? FileManager.default.removeItem(at: bad) }
    do {
        _ = try WavIO.readMono16k(bad)
        expect("no throw", "throw")
    } catch {
        expect("threw", "threw")
    }
}
