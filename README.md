# Uvaach <sup>उवाच</sup>

**Fully local, open-source voice dictation for macOS.** Hold a key, speak, and clean text appears in whatever app you're typing in — powered entirely by on-device AI. No cloud, no account, no subscription.

An open-source alternative to Wispr Flow / SuperWhisper, built for Apple Silicon.

> *Uvaach* (Sanskrit: उवाच) means **"spoke"** — the word the epics use right before the dialogue begins: *Krishna uvaacha…* You speak; the words appear.

[![Swift 6](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)](https://swift.org)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-000000?logo=apple&logoColor=white)](#requirements)
[![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-native-333333?logo=apple&logoColor=white)](#requirements)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## Why

Cloud dictation tools send your voice — every email, password hint, and half-formed thought — to someone else's servers, for a monthly fee. A Mac with Apple Silicon can do all of it locally:

- **Whisper large-v3-turbo** running on the Neural Engine via [WhisperKit](https://github.com/argmaxinc/argmax-oss-swift) — state-of-the-art transcription, 99 languages, entirely offline.
- **A small local LLM** (via [Ollama](https://ollama.com)) that polishes the raw transcript — punctuation, capitalization, filler-word removal — in ~0.5 s.
- **System-wide injection**: the cleaned text is pasted straight into the focused text field of *any* app.

Your voice never leaves the machine. Ever.

## How it works

```
 Hold Right ⌥ (or tap ⌥⌘D)
        │
        ▼
 🎙  AVAudioEngine ──── 16 kHz mono PCM
        │
        ▼
 🧠  WhisperKit (large-v3-turbo, CoreML / Neural Engine)
        │  raw transcript
        ▼
 🧹  Rule-based cleanup (fillers, punctuation)
        │
        ▼
 ✨  Ollama LLM polish (gemma3:1b) ── optional, silent fallback
        │
        ▼
 📖  Vocabulary corrections ("rb flow" → "rbFlow")
        │
        ▼
 📋  Clipboard-safe paste into the focused app (⌘V, clipboard restored)
```

A floating HUD shows a voice-reactive waveform while you speak and fades out the moment the text lands.

## Features

- 🎙 **Push-to-talk & toggle** — hold Right Option, or tap a customizable chord (default ⌥⌘D)
- 🔒 **100% offline** — Whisper + LLM both run on-device; works in airplane mode
- 🌊 **Live waveform HUD** — voice-reactive, never steals focus
- ✨ **Two-stage cleanup** — instant regex pass, plus an optional local-LLM polish with a paraphrase guard (if the LLM rewrites instead of cleaning, its output is discarded)
- 📚 **Dictation history** — searchable, persistent, with one-click copy
- 📖 **Custom vocabulary** — teach it names it mishears; your casing always wins
- 📋 **Clipboard-safe** — saves and restores whatever you had copied
- 🔐 **Secure-input aware** — refuses to inject into password fields, by design
- 🚫 **No Xcode required** — builds with Swift Package Manager + Command Line Tools alone

## Requirements

- Apple Silicon Mac (developed on M4, 16 GB)
- macOS 14 Sonoma or later
- Xcode **Command Line Tools** (`xcode-select --install`) — full Xcode not needed
- [Ollama](https://ollama.com) *(optional — only for the LLM polish pass)*

## Quick start

```sh
git clone https://github.com/rahulbhardwaj94/uvaach.git
cd uvaach

# 1. One-time: create a local self-signed signing identity ("Uvaach Dev").
#    Signing with a stable identity makes macOS permissions persist across rebuilds.
./scripts/setup-signing.sh

# 2. Build & launch
./scripts/build-app.sh
open build/Uvaach.app

# 3. Optional: the LLM polish model (~815 MB)
ollama pull gemma3:1b
```

On first launch, Uvaach walks you through the three permissions it needs and then downloads the Whisper model (~1.6 GB, one time).

| Permission | Why |
|---|---|
| **Microphone** | recording your voice while the hotkey is held |
| **Accessibility** | pasting text into the focused app |
| **Input Monitoring** | detecting the hold-to-talk key system-wide |

## Configuration

Everything lives in the menu-bar icon:

- **Settings** — hotkeys, Whisper model (large-v3-turbo ↔ small for low memory), LLM polish on/off, Ollama model tag, launch at login
- **History & Vocabulary** — browse/search past dictations; add corrections for words it mishears

Optional environment overrides (mainly for terminal runs) — see [.env.example](.env.example):

```sh
cp .env.example .env
set -a; source .env; set +a
swift run Uvaach
```

## Project layout

```
Sources/Uvaach/
├── UvaachApp.swift          # MenuBarExtra app + status state machine
├── DictationController.swift# pipeline orchestrator
├── Audio/                   # AVAudioEngine capture → 16 kHz mono
├── STT/                     # WhisperKit wrapper (warm-loaded, actor-isolated)
├── Cleanup/                 # regex cleaner + Ollama client w/ paraphrase guard
├── Injection/               # clipboard-safe ⌘V synthesis, secure-input guard
├── Hotkey/                  # CGEventTap PTT + KeyboardShortcuts toggle
├── HUD/                     # floating voice-reactive waveform pill
├── History/                 # persistent transcript store + vocabulary rules
├── Permissions/             # TCC onboarding
└── Settings/                # preferences UI + store
```

## Design notes

- **No Xcode, on purpose.** The `.app` bundle is assembled by [`scripts/build-app.sh`](scripts/build-app.sh) and signed with a self-signed identity so TCC permissions survive rebuilds. `KeyboardShortcuts` is pinned to 1.15.0 because newer versions use `#Preview`, which needs Xcode's macro plugin.
- **The LLM is never trusted blindly.** Small models love to *answer* dictation instead of cleaning it ("testing testing testing" → "The test is being performed."). Uvaach checks that ≥60% of your spoken words survive the polish; otherwise the LLM output is discarded.
- **The audio tap is real-time.** The capture callback only converts and appends samples; transcription, cleanup, and injection all happen off the main thread.

## Roadmap

- [ ] Per-app profiles (e.g. no LLM polish in terminals)
- [ ] Spoken commands ("new line", "make a list")
- [ ] Streaming preview while speaking
- [ ] Configurable hold key (Fn/Globe support)
- [ ] Parakeet (FluidAudio) as an alternative STT engine

## License

[MIT](LICENSE) © 2026 Rahul Bhardwaj
