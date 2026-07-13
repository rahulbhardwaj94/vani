# Vani Mark VI — Standing

Always-on wake word: say **"Vani"** (or **"सुनो Vani"**) and dictation starts
hands-free, no key held. Plus an explicit **ambient mode** — a continuously
listening scratchpad session for meetings and thinking-out-loud. Both are
opt-in, off by default, and visibly, honestly *on* when on.

Build order: **1. KWS engine + wake→record handoff → 2. Standing UX
(indicator, auto-suspend, settings) → 3. Ambient mode.** The app is
releasable after any milestone.

---

## Problem

Vani today needs a hand on the keyboard. That fails exactly when dictation is
most valuable: cooking, whiteboarding, pacing with a thought, hands in a
repair. Wispr Flow and SuperWhisper don't do hands-free wake either — a
fully-local wake word is open field. But an always-on microphone in a
privacy-absolutist app is a contradiction unless the design is *louder about
listening than the OS requires it to be*. The orange mic dot will be lit
permanently; we treat that as a feature and build the UX around it.

## Engine evaluation (researched 2026-07)

| Engine | Offline? | License | Custom "Vani"? | Hindi "सुनो"? | No-Xcode Swift path | Verdict |
|---|---|---|---|---|---|---|
| **sherpa-onnx KWS** (zipformer, open-vocabulary) | Yes, fully | Apache-2.0 | Yes — any phrase as BPE tokens, no training | Partial (romanized approximation) | C API + prebuilt static `xcframework`, SwiftPM `binaryTarget` works under CLT | **Primary** |
| **openWakeWord** custom model | Yes, fully | Apache-2.0 (incl. Google speech-embedding backbone) | Yes — train on synthetic TTS clips of "Hey Vani" (Colab pipeline exists) | Yes, if a Hindi TTS voice (e.g. Piper hi) generates samples | ONNX→CoreML converter is **dead** (removed in coremltools 6); must convert the TF graph via coremltools TF2 path, or embed onnxruntime — both real work | **Fallback** |
| Picovoice Porcupine | On-device compute, **but the SDK phones home** — AccessKey validation and usage reporting require periodic internet | SDK Apache-2.0, models proprietary; free tier = 3 users/month, commercial beyond that is contact-sales | Yes (Console) | Yes (Hindi is a supported language) | iOS-centric SPM binding; macOS via C lib | **Rejected** — "calls home servers to stay active" is disqualifying for an app whose one promise is *nothing leaves the machine, ever*. Free tier also can't cover an open-source app's users. |
| Apple SoundAnalysis + Create ML sound classifier | Yes | n/a (OS) | Needs recorded/synthetic samples; window-based classification (~1 s windows), not streaming KWS | Same | `CreateML.framework` is scriptable, but training data collection and window latency make it a science project | Rejected |
| microWakeWord | Yes | Apache-2.0 | Yes, but training is "intended for advanced users… still very difficult" (their words) | Unclear | TFLite-for-microcontrollers runtime — wrong target; models are Inception-based streaming TF, same conversion pain as openWakeWord with less tooling | Rejected |
| Roll our own CoreML KWS | Yes | Ours | Everything from scratch | Everything from scratch | Native | Rejected as v1 — this is openWakeWord's architecture minus openWakeWord's tooling |

**Decision: sherpa-onnx open-vocabulary keyword spotting.** It is the only
option that is simultaneously (a) Apache-2.0 end to end — MIT-compatible,
(b) truly offline with no license server, (c) zero-training — the keyword is
a *text file*, so "Vani", "Hey Vani", and user-customized wake phrases all
ship day one and users can change the phrase in Settings without anyone
training a model, and (d) integrable without Xcode: sherpa-onnx publishes a
prebuilt static `sherpa-onnx.xcframework` per release; SwiftPM binary targets
(and our `build-app.sh`) link it fine under Command Line Tools.

The KWS model is `sherpa-onnx-kws-zipformer-gigaspeech-3.3M` (English, 3.3 MB
— vs our 1.6 GB Whisper model, a rounding error). It decodes only the
keyword lattice; per-keyword boosting score and trigger threshold tune the
false-accept/false-reject tradeoff. "Vani" is short (two syllables — short
wake words are inherently more false-positive-prone), so the shipped default
is **"Hey Vani"** with plain "Vani" as an opt-in "I accept more
misfires" alternative.

**"सुनो Vani"**: the gigaspeech model is English-only. v1 ships "सुनो Vani" as
romanized BPE tokens ("soono vani") on the English model — it works because
KWS matches acoustics, not spelling, but accuracy is unvalidated. If it
tests badly, milestone 3 falls back to English-wake-only and Hindi wake moves
to the openWakeWord path (train "सुनो वाणी" on Piper Hindi TTS synthetic
samples — openWakeWord's headline feature is exactly "strong performance
even when training on fully-synthetic data").

**Fallback path** (if sherpa-onnx accuracy or the xcframework integration
disappoints): openWakeWord custom model, converted from its TF graph to
CoreML via coremltools' TF2 converter (the ONNX converter route is dead —
deprecated in coremltools 5, gone in 6 — so we convert upstream of ONNX).
Melspectrogram frontend reimplemented in Swift with Accelerate/vDSP.
Budget +1 week over the primary path.

### CPU / battery

Published numbers for these engines are Raspberry-Pi-class: Porcupine <4% of
one RPi3 core; openWakeWord runs 15–20 models real-time on one RPi3 core;
sherpa-onnx's KWS zipformer is in the same 3 MB class. An M4 efficiency core
is ~2 orders of magnitude faster than an RPi3 core — expect **<1% of one
E-core** for VAD+KWS, effectively unmeasurable in Activity Monitor. The real
battery cost is keeping the audio pipeline awake: an open `AVAudioEngine`
input prevents some package-idle states. Mitigations: 16 kHz mono tap,
16 kHz hardware sample rate where the device allows, no voice-processing IO
(we don't need AEC for KWS), and a **Silero-style VAD gate in front of KWS**
(the Home Assistant/openWakeWord pattern) so the KWS model only runs on
frames that contain speech. Acceptance below includes a measured budget.

---

## UX

### Honesty first

- The orange mic indicator will be on whenever Standing is on. We never
  work around it, and the onboarding sheet for this feature says exactly
  that: *"macOS will show the orange microphone dot the entire time
  Standing is enabled. That's correct — Vani is listening for its name.
  Audio is analyzed in memory and discarded; nothing is stored or sent
  anywhere until the wake word is heard."*
- Menu-bar icon gets a third state: idle / **standing** (distinct glyph —
  the bolt with an open ear arc) / recording. Standing state is visible at
  a glance, always.
- Clicking the menu-bar icon while standing shows "Listening for 'Hey
  Vani' — click to stand down" as the first item.

### Wake flow

1. Standing enabled → VAD+KWS runs continuously on the mic tap.
2. "Hey Vani" detected → the existing HUD pill appears with a brief wake
   chime-free visual pulse (no sound — this is a dictation tool, not an
   assistant), and **recording starts immediately** via the same path as a
   hotkey press. The KWS engine pauses while recording.
3. End of dictation = the existing hands-free semantics: silence-based
   auto-stop (new: 2.0 s of VAD silence ends the utterance), or tap the PTT
   key, or Esc to discard. Then transcribe→clean→paste exactly as today,
   and KWS resumes.
4. False wake escape: saying nothing after a wake times out in 5 s with no
   paste, no history entry, HUD fades.

### Push-to-wake compromises (auto-suspend)

Standing automatically stands down — mic fully closed, orange dot off —
when any of: screen locked, display asleep, screensaver active, a
secure-input session is active (password fields), or another app is
capturing the default input device for a call (best-effort via
CoreAudio `kAudioDevicePropertyDeviceIsRunningSomewhere` heuristics; if
detection is unreliable, ship without call-detection and document it).
Resumes automatically on unlock. This bounds "always-on" to "while you're
actually at an unlocked machine" — most of the privacy exposure for a
fraction of the on-time.

### Ambient mode (explicit, separate toggle)

A different beast from wake word: continuous transcription into the
Scratchpad. Started only by explicit action — menu-bar item "Start ambient
session…" or spoken "Vani, start ambient" while standing — never by
default, never remembered across launches.

- While ambient: the HUD pill docks persistent with a red-tinted standing
  waveform and elapsed time; menu-bar icon shows the recording state; the
  Scratchpad fills in near-real-time using the existing chunked
  transcription pipeline (SpeechSegmenter chunk boundaries → per-chunk
  decode → append).
- Hard cap 2 h per session; ends on screen lock; "Vani, stop" / clicking
  the pill / Esc ends it. Transcript lands in Scratchpad + history like any
  dictation, flagged `ambient` in history.
- Audio is never written to disk — same as today, buffers are transient;
  ambient mode transcribes and drops audio chunk by chunk, so a 2 h session
  holds minutes, not hours, of PCM in memory.

### Settings

New "Standing" section: master toggle (default **off**), wake phrase picker
("Hey Vani" / "Vani" / "सुनो Vani" / custom text), sensitivity slider
(maps to KWS boosting score + threshold), auto-suspend toggles (lock/
screensaver on by default, immutable off is not offered), ambient mode
enable (its own toggle — hidden until Standing is on).

---

## Technical design

- **New `Sources/Vani/Wake/`**: `WakeWordEngine.swift` (protocol: feed
  16 kHz Float frames → `AsyncStream<WakeEvent>`), `SherpaKWSEngine.swift`
  (C-API wrapper over `sherpa-onnx.xcframework`), `WakeSupervisor.swift`
  (owns the standing lifecycle: mic tap, VAD gate, engine feed, suspend
  rules, handoff to `DictationController`).
- **Dependency**: sherpa-onnx prebuilt static xcframework pinned by version
  + sha256, added as a SwiftPM `binaryTarget` (works under CLT — no Xcode).
  KWS model (~3.3 MB) + tokens bundled in the app — no lazy download for a
  3 MB file. If the binaryTarget route fights us, `build-app.sh` links the
  static lib directly (it already assembles the bundle by hand).
- **Audio ownership**: `AudioRecorder` grows a *standing tap* mode — one
  `AVAudioEngine` instance shared between KWS feed and recording, so wake→
  record handoff is a mode flip, not an engine restart (restart costs
  ~100–300 ms and risks dropping the first word). Frames buffered in a
  short ring (1.5 s) so the utterance *includes audio from just before the
  wake fired* minus the wake phrase itself — the KWS emits the keyword's
  end timestamp; recording starts from there.
- **VAD gate**: Silero VAD is bundled with sherpa-onnx — same xcframework,
  no extra dependency. KWS inference only on speech frames.
- **Handoff**: `WakeSupervisor` calls the same entry point as the hotkey
  (`DictationController.beginDictation(source: .wakeWord)`); everything
  downstream (HUD, STT, cleanup, inject, history) is unchanged. Wake source
  recorded in history metadata.
- **Suspend rules**: `NSWorkspace`/`CGSessionCopyCurrentDictionary` for
  lock state, `NSWorkspace.screensDidSleepNotification`, existing
  secure-input detection reused.
- **Feature flag**: `FeatureFlags.standing`, off until milestone 2 lands.

## Acceptance

- Saying "Hey Vani, take a note about the deploy" from 2 m away in a quiet
  room starts recording and pastes "take a note about the deploy" — first
  word never clipped (ring buffer test).
- False accepts: ≤1 per 8-hour workday of normal office/home audio
  (measured over a 3-day dogfood log; KWS logs wake events locally).
- False rejects: ≤1 in 10 deliberate wakes at normal speaking volume.
- CPU while standing: ≤1.5% of one core sustained on M4 (Activity
  Monitor, 10-min average); battery impact ≤3%/hour incremental on a
  MacBook (measured idle-with-standing vs idle).
- Locking the screen extinguishes the orange dot within 2 s; unlock
  resumes standing without user action.
- Standing off (default) → zero audio taps exist; `lsof`/orange dot prove
  the mic is closed. Network: zero connections attributable to wake
  code paths, ever (it's all static local inference — verifiable, unlike
  Porcupine).
- Ambient: a 30-min ambient session lands in Scratchpad with chunk lag
  ≤10 s behind speech and memory growth <500 MB.

## Effort & risks

**Milestone 1 — engine + handoff (~1 week):** xcframework integration, KWS
+ VAD running on a tap, wake fires `beginDictation`, ring-buffer stitch.
Riskiest first: if "Hey Vani" accuracy on the gigaspeech model is bad after
threshold tuning, stop and pivot to the openWakeWord/CoreML fallback
(+1 week) before building any UX on top.

**Milestone 2 — standing UX (~3–4 days):** menu-bar states, onboarding
honesty sheet, settings section, suspend/resume rules, silence auto-stop,
dogfood false-accept logging. Ships behind the flag → default-off release.

**Milestone 3 — ambient mode + Hindi wake (~1 week):** ambient session
lifecycle, Scratchpad streaming append, 2 h cap; validate romanized
"सुनो Vani" tokens, else scope Hindi wake out to the openWakeWord path.

Risks: (1) short-keyword false accepts — mitigated by "Hey Vani" default,
VAD gate, sensitivity slider; (2) xcframework + CLT-only linking friction —
mitigated by the build-app.sh direct-link escape hatch; (3) the permanent
orange dot will generate "is Vani spying?" issues no matter what we write —
mitigated by default-off, the honesty sheet, auto-suspend, and the fact that
the whole pipeline is ~200 lines of readable Swift over an Apache-2.0
engine anyone can audit; (4) shared-AVAudioEngine refactor touches the
most latency-sensitive code in the app — keep the standing tap behind the
feature flag so the hotkey path is provably untouched when standing is off.

## Sources

- sherpa-onnx keyword spotting (open-vocabulary KWS, models, boosting/thresholds): https://k2-fsa.github.io/sherpa/onnx/kws/index.html
- sherpa-onnx repo (Apache-2.0, SwiftPM/swift bindings, macOS support): https://github.com/k2-fsa/sherpa-onnx
- Running sherpa-onnx from Swift without Xcode projects: https://carlosmbe.medium.com/running-speech-models-with-swift-using-sherpa-onnx-for-apple-development-d31fdbd0898f
- openWakeWord (Apache-2.0, synthetic-TTS training, RPi3 = 15–20 models/core, Silero VAD gate): https://github.com/dscripka/openWakeWord
- openWakeWord custom training notebook: https://github.com/dscripka/openWakeWord/blob/main/notebooks/training_models.ipynb
- Home Assistant wake-word architecture (VAD-gated KWS pattern): https://www.home-assistant.io/voice_control/about_wake_word/
- Porcupine docs — on-device but "internet required for licensing validation and usage reporting": https://picovoice.ai/docs/faq/general/ and https://picovoice.ai/docs/porcupine/
- Picovoice free tier = 3 active users/month: https://www.hackster.io/news/picovoice-launches-completely-free-usage-tier-for-offline-voice-recognition-for-up-to-three-users-e1eafbc97bb0 and https://picovoice.ai/pricing/
- Porcupine repo (SDK Apache-2.0, platform list, RPi3 <4% core): https://github.com/Picovoice/porcupine and https://picovoice.ai/products/voice/wake-word/
- microWakeWord (training "very difficult", ESP32-class TFLite): https://github.com/OHF-Voice/micro-wake-word
- coremltools ONNX converter deprecated (v5) and removed (v6) — why ONNX→CoreML is a dead end: https://apple.github.io/coremltools/docs-guides/source/new-features.html and https://github.com/onnx/onnx-coreml
- macOS orange mic indicator: system-wide, cannot be disabled (by design): https://notes.alinpanaitiu.com/Can-we-hide-the-orange-dot-without-disabling-SIP and https://discussions.apple.com/thread/254183393
