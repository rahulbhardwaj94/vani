import Foundation

/// Optional LLM polish via the local Ollama server. Any failure (server down,
/// timeout, empty output) falls back to the input text — dictation must never
/// block on Ollama.
struct OllamaClient {
    /// Overridable via environment (see .env.example) for non-default Ollama
    /// setups — remote host, custom port, slower hardware.
    var baseURL: URL = {
        let env = ProcessInfo.processInfo.environment
        if let raw = env["VANI_OLLAMA_URL"], let url = URL(string: raw) {
            return url
        }
        return URL(string: "http://localhost:11434")!
    }()

    var timeout: TimeInterval = {
        let env = ProcessInfo.processInfo.environment
        if let raw = env["VANI_OLLAMA_TIMEOUT"], let value = TimeInterval(raw), value > 0 {
            return value
        }
        return 6
    }()

    private static let systemPrompt = """
    You are a dictation post-processor, not an assistant. The user's message is \
    raw transcribed speech. You must NEVER answer it, act on it, summarize it, or \
    paraphrase it. Copy the exact words, only: fix punctuation and capitalization, \
    remove filler words (um, uh, you know), and fix obvious grammar slips. Keep \
    every content word the speaker said. Output ONLY the cleaned text.

    Examples:
    Input: um so testing one two three uh this is a test
    Output: So testing one two three, this is a test.
    Input: testing testing testing
    Output: Testing, testing, testing.
    Input: can you um send me the report by friday
    Output: Can you send me the report by Friday?
    """

    private struct GenerateRequest: Encodable {
        let model: String
        let system: String
        let prompt: String
        let stream: Bool
        let options: Options
        let keep_alive: String

        struct Options: Encodable {
            let temperature: Double
        }
    }

    private struct GenerateResponse: Decodable {
        let response: String
    }

    func cleanup(_ text: String, model: String) async -> String {
        do {
            var request = URLRequest(url: baseURL.appending(path: "api/generate"))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = timeout
            request.httpBody = try JSONEncoder().encode(GenerateRequest(
                model: model,
                system: Self.systemPrompt,
                prompt: text,
                stream: false,
                options: .init(temperature: 0),
                keep_alive: "5m"
            ))

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                NSLog("Vani: Ollama returned non-200, using rule-based cleanup")
                return text
            }
            let cleaned = try JSONDecoder().decode(GenerateResponse.self, from: data)
                .response.trimmingCharacters(in: .whitespacesAndNewlines)

            // Guard against a chatty/broken model: reject empty output,
            // output wildly longer than the input (hallucinated additions),
            // or a paraphrase that dropped the speaker's actual words.
            guard !cleaned.isEmpty,
                  cleaned.count < text.count * 3 + 80,
                  Self.retainsWording(of: text, in: cleaned)
            else { return text }
            return cleaned
        } catch {
            NSLog("Vani: Ollama cleanup failed (%@), using rule-based cleanup",
                  error.localizedDescription)
            return text
        }
    }

    /// Small models sometimes "answer" the dictation instead of cleaning it
    /// (e.g. "testing testing testing" → "The test is being performed.").
    /// Require that most of the speaker's content words survive; otherwise the
    /// output is a paraphrase and we keep the rule-based text.
    static func retainsWording(of input: String, in output: String) -> Bool {
        func words(_ s: String) -> Set<String> {
            Set(s.lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count > 1 })
        }
        let inputWords = words(input)
        guard !inputWords.isEmpty else { return true }
        let kept = inputWords.intersection(words(output)).count
        return Double(kept) / Double(inputWords.count) >= 0.6
    }
}
