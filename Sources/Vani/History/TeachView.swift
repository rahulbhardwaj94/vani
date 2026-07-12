import SwiftUI
import VaniCore

/// "Teach Vani your voice": the user dictates a handful of known sentences;
/// each raw transcript is diffed against the expected text and the stable
/// mishears become vocabulary-rule suggestions. No model training — the
/// honest, on-device way to personalize: Whisper stays frozen, the
/// corrections layer learns your voice.
struct TeachView: View {
    @ObservedObject private var store = TranscriptStore.shared
    @ObservedObject private var vocab = VocabularyStore.shared

    private static let sentences = [
        "Vani uses WhisperKit with CoreML to run speech recognition locally on my Mac.",
        "The large-v3-turbo model runs on the Apple Neural Engine, even offline.",
        "Push the commit to GitHub and open a pull request on the main branch.",
        "Please schedule the meeting for tomorrow at 4:30 and email me the notes.",
        "मेरा नाम राहुल है और मुझे हिंदी में बोलना पसंद है।",
        "The weather is lovely today, so let's walk to the coffee shop together.",
    ]

    @State private var step = 0
    @State private var capture = ""
    @State private var lastSeenEntryID: UUID?
    @State private var suggestions: [TranscriptDiff.Mishear] = []
    @State private var accepted: Set<String> = []
    @State private var finished = false
    @State private var saved = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if finished {
                results
            } else {
                prompt
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { lastSeenEntryID = store.entries.first?.id }
        .onChange(of: store.entries.first?.id) { _, newID in
            guard !finished, let newID, newID != lastSeenEntryID,
                  let entry = store.entries.first else { return }
            lastSeenEntryID = newID
            record(entry)
        }
    }

    private var prompt: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Teach Vani your voice")
                .font(.title3.bold())
            Text("Read each sentence aloud exactly as written (hold Right ⌥, dictate into the field below). Vani compares what it heard with what you said and learns corrections for the words it gets wrong — sentence \(step + 1) of \(Self.sentences.count).")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("“\(Self.sentences[step])”")
                .font(.title3)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
                .textSelection(.enabled)

            TextField("Dictate here…", text: $capture)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Skip this sentence") { advance() }
                Spacer()
                if step > 0 || !suggestions.isEmpty {
                    Text("\(suggestions.count) correction\(suggestions.count == 1 ? "" : "s") found so far")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }

    private var results: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(suggestions.isEmpty ? "Nothing to teach 🎉" : "What Vani learned")
                .font(.title3.bold())
            if suggestions.isEmpty {
                Text("Every sentence came back right — your voice and this model already get along. Re-run anytime from this tab.")
                    .foregroundStyle(.secondary)
            } else {
                Text("Check the corrections worth keeping — they apply to every future dictation (Vocabulary tab).")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                List(suggestions, id: \.heard) { m in
                    Toggle(isOn: binding(for: m)) {
                        HStack {
                            Text("heard “\(m.heard)”")
                            Image(systemName: "arrow.right").foregroundStyle(.secondary)
                            Text(m.expected).bold()
                        }
                    }
                }
                .listStyle(.inset)
                .frame(minHeight: 160)
                Button(saved ? "Saved ✓" : "Save \(accepted.count) correction\(accepted.count == 1 ? "" : "s")") {
                    for m in suggestions where accepted.contains(m.heard) {
                        // Skip duplicates of existing rules.
                        if !vocab.rules.contains(where: { $0.find.lowercased() == m.heard.lowercased() }) {
                            vocab.rules.append(.init(find: m.heard, replace: m.expected))
                        }
                    }
                    saved = true
                }
                .disabled(accepted.isEmpty || saved)
            }
            Button("Start over") {
                step = 0
                suggestions = []
                accepted = []
                finished = false
                saved = false
                capture = ""
            }
            .buttonStyle(.link)
            Spacer()
        }
    }

    private func binding(for m: TranscriptDiff.Mishear) -> Binding<Bool> {
        Binding(
            get: { accepted.contains(m.heard) },
            set: { on in if on { accepted.insert(m.heard) } else { accepted.remove(m.heard) } }
        )
    }

    private func record(_ entry: TranscriptStore.Entry) {
        let heard = entry.raw ?? entry.text
        for m in TranscriptDiff.mishears(expected: Self.sentences[step], heard: heard)
        where !suggestions.contains(m) {
            suggestions.append(m)
            accepted.insert(m.heard)
        }
        advance()
    }

    private func advance() {
        capture = ""
        if step + 1 < Self.sentences.count {
            step += 1
        } else {
            finished = true
        }
    }
}
