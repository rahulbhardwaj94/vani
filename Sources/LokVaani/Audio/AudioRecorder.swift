import AVFoundation

/// Captures microphone audio and accumulates it as 16 kHz mono Float32 —
/// the format Whisper expects. The AVAudioEngine tap runs on a real-time
/// audio thread: the tap closure only converts and appends to a buffer
/// guarded by a lock (no allocation-heavy or blocking work).
///
/// Each dictation gets a *fresh* AVAudioEngine. Reusing one engine across
/// many start/stop cycles accumulates stale HAL IO state in CoreAudio and
/// eventually segfaults on the IO thread mid-teardown (observed as
/// EXC_BAD_ACCESS in HALC_ProxyIOContext::IOWorkLoop while `engine.stop()`
/// waits in AudioOutputUnitStop). A per-session engine, an `active` flag the
/// tap checks under the lock, and a config-change observer close that race.
final class AudioRecorder {
    static let targetSampleRate: Double = 16_000

    /// One capture session: engine, converter, and the accumulated samples.
    /// The tap closure captures the session directly (not the recorder), so
    /// a late callback from a torn-down session can never touch a new one.
    private final class Session {
        let engine = AVAudioEngine()
        var converter: AVAudioConverter?
        let lock = NSLock()
        var samples: [Float] = []
        var active = true // guarded by `lock`; late tap callbacks bail out
        var configObserver: NSObjectProtocol?
    }

    private var session: Session?
    var isRecording: Bool { session != nil }

    /// Called from the audio tap thread with the RMS level of each buffer
    /// (~10–20 Hz). Keep the handler cheap; hop actors inside it if needed.
    var onLevel: ((Float) -> Void)?

    /// Called on the main queue if capture dies mid-recording — the input
    /// device changed or CoreAudio invalidated the engine's configuration
    /// (e.g. AirPods connecting switches the mic and its sample rate).
    /// The samples captured so far are preserved; call `stop()` to collect.
    var onInterruption: (() -> Void)?

    private lazy var targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: Self.targetSampleRate,
        channels: 1,
        interleaved: false
    )!

    func start() throws {
        guard session == nil else { return }

        let s = Session()
        // Reserve 10 minutes so hands-free dictations never reallocate the
        // buffer on the real-time audio thread while holding the lock.
        s.samples.reserveCapacity(Int(Self.targetSampleRate) * 600)

        let input = s.engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0 else {
            throw NSError(domain: "LokVaani.audio", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "No audio input device available."
            ])
        }
        s.converter = AVAudioConverter(from: inputFormat, to: targetFormat)

        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self, weak s] buffer, _ in
            guard let self, let s else { return }
            self.append(buffer, to: s)
        }

        // The engine stops delivering (or crashes, if we keep pulling) when
        // the input device or its format changes underneath it. Freeze the
        // session and let the controller finish with what we captured.
        s.configObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: s.engine, queue: .main
        ) { [weak self, weak s] _ in
            guard let self, let s, self.session === s else { return }
            s.lock.lock()
            s.active = false
            s.lock.unlock()
            self.onInterruption?()
        }

        s.engine.prepare()
        do {
            try s.engine.start()
        } catch {
            input.removeTap(onBus: 0)
            if let observer = s.configObserver {
                NotificationCenter.default.removeObserver(observer)
            }
            throw error
        }
        session = s
    }

    /// Stops capture and returns the recorded utterance.
    func stop() -> [Float] {
        guard let s = session else { return [] }
        session = nil

        if let observer = s.configObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        // Flip `active` first so any in-flight tap callback drops out before
        // the engine is torn down, then release the whole session with it.
        s.lock.lock()
        s.active = false
        s.lock.unlock()

        s.engine.inputNode.removeTap(onBus: 0)
        s.engine.stop()

        s.lock.lock()
        defer { s.lock.unlock() }
        return s.samples
    }

    private func append(_ buffer: AVAudioPCMBuffer, to s: Session) {
        guard let converter = s.converter else { return }

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

        s.lock.lock()
        guard s.active else {
            s.lock.unlock()
            return
        }
        s.samples.append(contentsOf: UnsafeBufferPointer(start: channel, count: Int(out.frameLength)))
        s.lock.unlock()

        if let onLevel {
            let count = Int(out.frameLength)
            var sum: Float = 0
            for i in 0..<count { sum += channel[i] * channel[i] }
            onLevel(sqrt(sum / Float(count)))
        }
    }
}
