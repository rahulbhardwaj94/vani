# Vani v0.2 — Feature Specs

Build order: **1. Streaming preview → 2. Spoken commands (EN + HI) → 3. Hinglish
normalization → 4. Homebrew cask.** Each feature ships independently; the app
is releasable after any of them.

---

## 1. Streaming preview while speaking

### Problem
The user speaks into a silent pill and only finds out *after* releasing the key
whether Vani heard them correctly. That uncertainty is the single biggest
anxiety in dictation, and the main "feels a generation old" gap vs Wispr Flow.

### UX
- While recording, the HUD pill grows one line: live partial transcript,
  monochrome, single line, tail-truncated (`…the last ~48 chars visible`).
- Partial text renders at ~60% opacity; on stop, the pill returns to the
  current transcribe→paste flow unchanged. No flicker between partials:
  only append/replace from a stable prefix.
- Off by default? **No — on by default**, settings toggle "Live preview"
  (`SettingsStore.streamingPreview`). Falls back silently to today's behavior
  if the preview transcriber can't keep up.

### Technical design
- `TranscriptionService` gains a preview loop: while recording, every ~1.5 s
  transcribe the *entire accumulated buffer* (`AudioRecorder` exposes a
  `snapshot() -> [Float]` — copy under the existing lock, cheap at 16 kHz).
  Whisper is not incremental; full-buffer re-decode with
  `usePrefillPrompt` + temperature 0 gives stable prefixes in practice.
- Serialize on the existing actor; if a pass takes longer than the interval,
  skip the next tick (never queue). Cap preview passes at 60 s of audio; past
  that, decode only the last 30 s window for preview (final pass still uses
  the full buffer).
- Publish partials via `AppState.previewTranscript: String?`; HUD observes.
- The **final** transcript still comes from the one full-buffer pass after
  stop — preview output is never inserted.
- Model: reuse the loaded model (no second model in memory on a 16 GB
  machine). If p95 preview latency > 1.5× interval on the user's hardware,
  auto-disable for the session and log.

### Acceptance
- Dictating a 30 s paragraph shows partials updating ≤2 s behind speech.
- Final pasted text is byte-identical to the same audio with preview off.
- Memory high-water mark grows < 300 MB vs preview off.
- Hindi/auto language preview works (partials may flip script mid-way; fine).

### Effort & risks
~2–3 days. Risk: large-v3-turbo re-decode of long buffers heats up the ANE —
mitigated by the 30 s preview window and tick-skipping.

---

## 2. Spoken commands — English + Hindi

### Problem
"New line" comes out as the words *new line*. Without spoken punctuation and
structure, Vani can't be a daily driver for email/docs. Hindi voice commands
exist in no competing product.

### UX
Deterministic, rule-based (never LLM — on-brand: "never rewrites you").
Commands are recognized **only as whole standalone phrases** (surrounded by
boundaries/pauses-turned-punctuation), so dictating the sentence "I added a
new line of code" is untouched.

Initial lexicon (each with EN + HI trigger):

| Action | English | Hindi |
|---|---|---|
| newline | "new line" | "नई लाइन" / "nayi line" |
| paragraph break | "new paragraph" | "नया पैराग्राफ" |
| `.` | "full stop" / "period" | "पूर्ण विराम" |
| `,` | "comma" | "कॉमा" |
| `?` | "question mark" | "प्रश्न चिह्न" |
| discard utterance | "scratch that" | "रहने दो" |

"Scratch that" (v1 scope) discards the *current* dictation entirely — it does
not edit already-pasted text.

### Technical design
- New `Cleanup/CommandProcessor.swift`, runs after `TextCleaner`, before
  vocabulary. Input: cleaned transcript; output: text with commands applied.
- Matching: case/diacritic-insensitive, tolerant of Whisper's punctuation
  around the phrase (`"New line."` → newline). Hindi triggers matched in both
  Devanagari and common romanizations (Whisper emits either).
- Settings toggle "Spoken commands" (default on) + a Dashboard reference
  sheet listing the lexicon.
- `TranscriptStore` keeps the raw (pre-command) text in `raw`, as today.

### Acceptance
- "first point new line second point" → `first point\nsecond point`.
- "मेरा नाम राहुल है नई लाइन धन्यवाद" → two lines.
- "I added a new line of code" → unchanged.
- "…blah blah scratch that" → nothing pasted, HUD fades, no history entry.

### Effort & risks
~2 days incl. a real unit-test target (first tests in the repo — set up
`VaniTests` with SwiftPM). Risk: false positives; mitigated by
whole-phrase-with-boundary matching and the raw text kept in history.

---

## 3. Hinglish normalization

### Problem
Real Indian speech is code-switched ("kal meeting hai at 4pm"). Whisper
flip-flops output between Devanagari and Latin unpredictably across (even
within) utterances. Nobody else solves this; it's Vani's wedge.

### UX
New setting **Hinglish output** (shown when language is auto/hi):
- **As heard** (default) — today's behavior, whatever Whisper emits.
- **Romanized** — Devanagari Hindi tokens transliterated to Latin
  ("कल मीटिंग है" → "kal meeting hai"). For WhatsApp-style typists.
- **Devanagari** — Latin *Hindi* tokens transliterated to Devanagari;
  English words stay in Latin ("kal meeting hai at 4pm" →
  "कल मीटिंग है at 4pm").

### Technical design
- New `Cleanup/ScriptNormalizer.swift`, after CommandProcessor.
- Romanized mode: `NSString.applyingTransform(.latinToDevanagari, reverse:
  true)` (ICU, built-in, zero dependencies) on Devanagari runs only.
- Devanagari mode is the hard one: token-level Hindi-vs-English
  classification of Latin tokens before transliterating. Approach: a bundled
  wordlist of the ~10k most common English words + the user's vocabulary =
  "keep Latin"; digits/URLs/emails/acronyms keep Latin; everything else
  romanized-Hindi → ICU transform → Devanagari. Ship behind the setting,
  expect iteration; keep `raw` in history for comparison.
- Unit tests with a fixture set of ~50 real code-switched sentences.

### Acceptance
- Script is consistent per mode across 20 consecutive mixed dictations.
- English technical terms ("deploy", "meeting", names from vocabulary) are
  never transliterated in Devanagari mode.
- Pure-English dictation is byte-identical in all three modes.

### Effort & risks
~3–4 days, mostly the classifier wordlist + tests. ICU transliteration of
*romanized* Hindi is imperfect ("hai" → है needs a small exceptions map for
~200 common words); ship the exceptions map, iterate from history data.

---

## 4. Homebrew cask

### Problem
Install today = clone + two scripts + trust a self-signed cert. Every bounced
installer is a lost star/user.

### Plan (two stages)
**Stage A — own tap (ship now, free):**
- Repo `rahulbhardwaj94/homebrew-tap`, cask `vani.rb`:
  `brew install --cask rahulbhardwaj94/tap/vani`.
- Release automation: `scripts/release.sh` builds, zips `Vani.app`, creates a
  GitHub release with the artifact + sha256, and bumps the cask formula.
- Self-signed app ⇒ Gatekeeper quarantine: the cask sets no workaround;
  README + cask caveats document `xattr -d com.apple.quarantine` /
  right-click-Open, honestly. (Casks may not auto-strip quarantine.)
- Permissions note in caveats: mic/accessibility/input-monitoring onboarding
  runs on first launch.

**Stage B — Developer ID + notarization (when ready to spend $99/yr):**
- `codesign` with Developer ID + `notarytool` in `release.sh`; then apply to
  the main `homebrew/cask` repo (requires the app to be notarized and to
  meet notability bar — GitHub stars help).

### Acceptance (Stage A)
- Fresh macOS user: `brew install --cask rahulbhardwaj94/tap/vani` →
  right-click-Open → onboarding appears. No clone, no Xcode CLT needed.

### Effort & risks
~1 day for Stage A. Risk: self-signed + download = scary Gatekeeper dialog;
that's inherent until Stage B.

---

## Backlog (agreed, not yet scheduled)

From the top-10 analysis, still open after this spec: escape hatch (Esc to
cancel + re-insert last dictation), per-app profiles, vocabulary → Whisper
prompt biasing, Parakeet as fast STT engine, scratchpad fallback window when
no text field is focused, shareable stats card, weekly recap notification.
Already shipped: stats dashboard, custom vocabulary (post-hoc), hands-free
lock, monochrome HUD, app icon.
