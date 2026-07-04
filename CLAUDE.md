# Uvaach

Fully local, offline dictation app for macOS (Apple Silicon): hold Right Option
(or ⌥⌘D toggle) → speak → on-device Whisper transcription → optional local LLM
cleanup → text pasted into the focused app.

## Stack

- Swift 6 / SwiftUI menu-bar app (`MenuBarExtra`, `LSUIElement`), built with
  **SwiftPM only — no Xcode** (Command Line Tools suffice).
- STT: WhisperKit (`argmaxinc/argmax-oss-swift`), default model
  `openai_whisper-large-v3-v20240930` (large-v3-turbo), lazy-downloaded on first use.
- Cleanup: regex filler strip (always) + optional Ollama pass (`gemma3:1b`).
- Injection: NSPasteboard + synthetic Cmd+V with clipboard save/restore.

## Build & run

```sh
./scripts/setup-signing.sh   # one-time: creates the "Uvaach Dev" signing identity
./scripts/build-app.sh       # release build → build/Uvaach.app (signed)
open build/Uvaach.app
```

`swift build` works for compile checks. Always launch via the signed .app —
TCC permissions (Microphone / Accessibility / Input Monitoring) are tied to the
"Uvaach Dev" signing identity and persist across rebuilds only when signed.
Deleting/recreating that identity resets all granted permissions.

## Gotchas

- **KeyboardShortcuts is pinned to exactly 1.15.0**: 1.16.0+ uses `#Preview`,
  which requires Xcode's PreviewsMacros plugin and fails under CLT-only builds.
  Don't bump it unless full Xcode is installed.
- The target compiles in Swift language mode v5 (`Package.swift` swiftSettings).
- `setup-signing.sh` uses `openssl pkcs12 -legacy` — OpenSSL 3's default PKCS12
  encoding is rejected by `security import`.
- The hold-to-talk tap is listen-only CGEventTap on `flagsChanged` (Right
  Option, keycode 61) — needs Input Monitoring, not Accessibility.
- Ollama cleanup must never block dictation: any failure falls back to the
  rule-based output silently.
- Ollama URL/timeout are overridable via UVAACH_OLLAMA_URL / UVAACH_OLLAMA_TIMEOUT
  env vars (see .env.example); defaults are localhost:11434 / 6 s.
