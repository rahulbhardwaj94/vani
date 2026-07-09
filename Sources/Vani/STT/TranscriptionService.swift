import Foundation
import WhisperKit

/// Owns the WhisperKit pipeline. Loaded once at launch (in the background)
/// and kept warm so each dictation only pays inference cost.
actor TranscriptionService {
    static let shared = TranscriptionService()

    enum State: Equatable {
        case unloaded
        case downloading
        case loading
        case ready
        case failed(String)
    }

    private(set) var state: State = .unloaded
    private var whisperKit: WhisperKit?
    private var loadedModel: String?

    /// Idempotent; safe to call at launch and again before first use.
    func warmUp(model: String) async {
        if state == .ready, loadedModel == model { return }
        if state == .downloading || state == .loading { return }

        do {
            state = .downloading
            NSLog("Vani: loading Whisper model '%@'…", model)
            let config = WhisperKitConfig(model: model)
            config.prewarm = true
            state = .loading
            let kit = try await WhisperKit(config)
            whisperKit = kit
            loadedModel = model
            state = .ready
            NSLog("Vani: Whisper model ready")
        } catch {
            state = .failed(error.localizedDescription)
            NSLog("Vani: Whisper load failed: %@", error.localizedDescription)
        }
    }

    /// Transcribes 16 kHz mono Float32 samples; returns the raw transcript.
    /// `language` is a Whisper code ("hi", "en", ...) or "auto" to detect.
    /// WhisperKit's defaults force English (usePrefillPrompt: true prefills
    /// "en" unless told otherwise), so we must pass options explicitly.
    func transcribe(samples: [Float], model: String, language: String) async throws -> String {
        if state != .ready || loadedModel != model {
            await warmUp(model: model)
        }
        guard let whisperKit, state == .ready else {
            throw NSError(domain: "Vani.stt", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Speech model is not loaded."
            ])
        }

        let options = DecodingOptions(
            task: .transcribe,
            language: language == "auto" ? nil : language,
            usePrefillPrompt: true,
            detectLanguage: language == "auto"
        )
        let results = try await whisperKit.transcribe(audioArray: samples, decodeOptions: options)
        return results.map(\.text).joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
