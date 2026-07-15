import Foundation
import VaniCore
import VaniSTT

// Vani regression harness: every fixtures/<name>.wav is transcribed by the
// REAL engine (same TranscriptionService the app ships) and run through the
// same deterministic text pipeline, then scored as word error rate against
// fixtures/<name>.txt. Scores are compared to fixtures/baseline.json:
// a fixture more than `tolerance` worse than its baseline fails the run.
//
//   swift run -c release VaniRegress                  # compare to baseline
//   swift run -c release VaniRegress --update-baseline # accept current scores
//
// Generate/refresh the synthetic fixtures first: ./scripts/gen-fixtures.sh
// Drop real recordings (16 kHz mono 16-bit wav + sidecar .txt) into
// fixtures/ to grow the corpus — the harness picks up every pair.

setvbuf(stdout, nil, _IONBF, 0)

let fixturesDir = URL(fileURLWithPath: "fixtures", isDirectory: true)
let baselineURL = fixturesDir.appendingPathComponent("baseline.json")
let updateBaseline = CommandLine.arguments.contains("--update-baseline")
let model = "openai_whisper-large-v3-v20240930"
/// A fixture may be this much worse than its baseline WER before the run
/// fails — Whisper has mild run-to-run jitter on marginal audio.
let tolerance = 0.02

struct Score: Codable { var wer: Double; var chars: Int }

/// The personal corpus: real dictations the app saved (Settings →
/// Listening → "Save recordings for testing"). Same wav+txt convention;
/// the .txt starts as the pipeline's output and becomes ground truth the
/// moment the user hand-corrects it.
let corpusDir = FileManager.default
    .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("Vani/corpus", isDirectory: true)

func wavList(_ dir: URL) -> [URL] {
    ((try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [])
        .filter { $0.pathExtension == "wav" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
}
let wavs = wavList(fixturesDir) + wavList(corpusDir)

guard !wavs.isEmpty else {
    print("no fixtures found in fixtures/ — run ./scripts/gen-fixtures.sh first")
    exit(2)
}

let baseline: [String: Score] = (try? Data(contentsOf: baselineURL))
    .flatMap { try? JSONDecoder().decode([String: Score].self, from: $0) } ?? [:]

// --probe <file.wav>: language-detection diagnostics instead of the harness.
// Splits the clip on pauses the same way transcribe(language:"auto") does,
// prints each segment's top language probabilities, and decodes it under
// en, hi, and auto so code-switch misfires can be seen side by side.
if let probeIdx = CommandLine.arguments.firstIndex(of: "--probe"),
   CommandLine.arguments.count > probeIdx + 1 {
    let wav = URL(fileURLWithPath: CommandLine.arguments[probeIdx + 1])
    // Optional third token: probe a different model (e.g. openai_whisper-small,
    // the preview model the app's fast per-segment language ID runs on).
    let model = CommandLine.arguments.count > probeIdx + 2
        ? CommandLine.arguments[probeIdx + 2] : model
    let sem = DispatchSemaphore(value: 0)
    Task {
        await TranscriptionService.shared.warmUp(model: model)
        let samples = try WavIO.readMono16k(wav)
        let segments = TranscriptionService.speechSegments(in: samples)
        print("\(segments.count) segments in \(wav.lastPathComponent)")
        for (i, seg) in segments.enumerated() {
            let slice = Array(samples[seg.start..<seg.end])
            print(String(format: "segment %d: %.1f–%.1fs", i,
                Double(seg.start) / 16_000, Double(seg.end) / 16_000))
            if let probs = await TranscriptionService.shared.languageProbs(slice) {
                let top = probs.sorted { $0.value > $1.value }.prefix(4)
                    .map { String(format: "%@ %.2f", $0.key, $0.value) }
                print("  probs: " + top.joined(separator: "  "))
            }
            for lang in ["en", "hi", nil] {
                let text = (try? await TranscriptionService.shared.decodeChunk(
                    samples: slice, model: model, language: lang)) ?? "<error>"
                print("  [\(lang ?? "auto")] \(text)")
            }
        }
        sem.signal()
    }
    sem.wait()
    exit(0)
}

print("Vani regression harness — \(wavs.count) fixtures, model \(model)")
print("loading model…")

let sem = DispatchSemaphore(value: 0)
var results: [(name: String, score: Score, expected: String, got: String)] = []
var failures: [String] = []

Task {
    await TranscriptionService.shared.warmUp(model: model)

    for wav in wavs {
        let name = wav.deletingPathExtension().lastPathComponent
        let expectedURL = wav.deletingPathExtension().appendingPathExtension("txt")
        guard let expected = try? String(contentsOf: expectedURL, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines) else {
            print("  \(name): SKIP (no sidecar .txt)")
            continue
        }
        do {
            let samples = try WavIO.readMono16k(wav)
            let started = Date()
            let raw = try await TranscriptionService.shared.transcribe(
                samples: samples, model: model, language: "auto"
            )
            let seconds = Date().timeIntervalSince(started)
            // The same deterministic text pipeline the app applies to
            // every dictation (minus user-specific vocabulary/snippets,
            // which aren't part of the repo).
            var text = TextCleaner.clean(raw)
            text = HinglishNormalizer.normalize(text)
            let wer = TranscriptDiff.wer(expected: expected, heard: text)
            let score = Score(wer: wer, chars: text.count)
            results.append((name, score, expected, text))

            let base = baseline[name]
            let delta = base.map { wer - $0.wer }
            let flag: String
            if let delta, delta > tolerance {
                flag = "REGRESSED (baseline \(String(format: "%.1f", (base?.wer ?? 0) * 100))%)"
                failures.append(name)
            } else if base == nil {
                flag = "new"
            } else {
                flag = delta! < -tolerance ? "improved" : "ok"
            }
            let padded = name.padding(toLength: max(28, name.count), withPad: " ", startingAt: 0)
            print(String(format: "  %@ WER %5.1f%%  %4.1fs audio → %.2fs  %@",
                padded, wer * 100, Double(samples.count) / 16_000, seconds, flag))
            if wer > 0 {
                print("      expected: \(expected)")
                print("      got:      \(text)")
            }
        } catch {
            print("  \(name): ERROR \(error)")
            failures.append(name)
        }
    }

    if updateBaseline {
        let scores = Dictionary(uniqueKeysWithValues: results.map { ($0.name, $0.score) })
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        try? (try? enc.encode(scores))?.write(to: baselineURL)
        print("baseline updated: \(baselineURL.path) (\(scores.count) fixtures)")
    }

    let mean = results.isEmpty ? 0 : results.map(\.score.wer).reduce(0, +) / Double(results.count)
    print(String(format: "mean WER %.1f%% across %d fixtures", mean * 100, results.count))
    sem.signal()
}

sem.wait()
if !failures.isEmpty {
    print("FAIL: \(failures.joined(separator: ", "))")
    exit(1)
}
print(updateBaseline ? "OK (baseline written)" : "OK — no regressions")
exit(0)
