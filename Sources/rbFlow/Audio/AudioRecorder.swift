import AVFoundation

/// Captures microphone audio and accumulates it as 16 kHz mono Float32 —
/// the format Whisper expects. The AVAudioEngine tap runs on a real-time
/// audio thread: the tap closure only converts and appends to a buffer
/// guarded by a lock (no allocation-heavy or blocking work).
final class AudioRecorder {
    static let targetSampleRate: Double = 16_000

    private let engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private let lock = NSLock()
    private var samples: [Float] = []
    private(set) var isRecording = false

    /// Called from the audio tap thread with the RMS level of each buffer
    /// (~10–20 Hz). Keep the handler cheap; hop actors inside it if needed.
    var onLevel: ((Float) -> Void)?

    private lazy var targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: Self.targetSampleRate,
        channels: 1,
        interleaved: false
    )!

    func start() throws {
        guard !isRecording else { return }

        lock.lock()
        samples.removeAll(keepingCapacity: true)
        samples.reserveCapacity(Int(Self.targetSampleRate) * 60)
        lock.unlock()

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0 else {
            throw NSError(domain: "rbFlow.audio", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "No audio input device available."
            ])
        }
        converter = AVAudioConverter(from: inputFormat, to: targetFormat)

        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.append(buffer)
        }

        engine.prepare()
        try engine.start()
        isRecording = true
    }

    /// Stops capture and returns the recorded utterance.
    func stop() -> [Float] {
        guard isRecording else { return [] }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRecording = false

        lock.lock()
        defer { lock.unlock() }
        let result = samples
        samples = []
        return result
    }

    private func append(_ buffer: AVAudioPCMBuffer) {
        guard let converter else { return }

        let ratio = Self.targetSampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 16
        guard let out = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return }

        var consumed = false
        var error: NSError?
        converter.convert(to: out, error: &error) { _, outStatus in
            if consumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            outStatus.pointee = .haveData
            return buffer
        }
        guard error == nil, out.frameLength > 0, let channel = out.floatChannelData?[0] else { return }

        lock.lock()
        samples.append(contentsOf: UnsafeBufferPointer(start: channel, count: Int(out.frameLength)))
        lock.unlock()

        if let onLevel {
            let count = Int(out.frameLength)
            var sum: Float = 0
            for i in 0..<count { sum += channel[i] * channel[i] }
            onLevel(sqrt(sum / Float(count)))
        }
    }
}
