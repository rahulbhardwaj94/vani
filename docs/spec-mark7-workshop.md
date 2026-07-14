# Vani Mark VII — The Workshop

Voice-driven **editing** of already-typed text, not just forward dictation:
"select the last sentence", "change Tuesday to Thursday", "delete from
however onward", "make that camelCase" — operating on text Vani itself typed
into the focused app during this session.

Build order: **1. The Ledger → 2. AX edit engine + grammar core →
3. Fallback strategies + transforms → 4. LLM fallback + Hindi + polish.**
Each milestone ships independently; the app is releasable after any of them.

---

## The one big scoping decision

Reading arbitrary app text state is an unsolvable general problem (Electron
apps lie, terminals have no text model, web views expose stale AX trees).
Vani dodges it: **v1 edits only text Vani itself pasted, this session.** We
know those strings byte-for-byte because we put them there. Everything below
follows from that constraint — the session ledger is the source of truth, and
every edit is verified against it before a single key is synthesized.

## Session model — the Paste Ledger

A new `PasteLedger` (VaniCore, pure + testable; fed from `TextInjector`):

- Every successful `TextInjector.insert` appends an entry:
  `{ bundleID, pid, exactText, insertedAt, orderIndex }`. A clipboard-only
  outcome records nothing — we never confirmed it landed.
- Entries are grouped per app into a **tail block**: the concatenation of
  consecutive pastes into the same app with nothing observed in between.
  Edits target the tail block of the *frontmost* app only.
- In-memory only, capped at 50 entries / 20 kB per app, cleared on quit.
  Nothing persists — this is a working memory, not surveillance.
- Vani cannot see the user's own typing between pastes (no keylogging, on
  purpose). So the ledger is a *claim*, and every edit begins with a
  **verification step** that either confirms the claim or aborts.
- An edit that succeeds updates the ledger (the tail block now contains the
  corrected text), so edits compose: "change Tuesday to Thursday" then
  "make that camelCase" both work.

## Edit strategies, per app class

Tried in order; each step re-verifies the frontmost bundle ID before posting
any event, and aborts loudly if it changed.

**(a) AX path — apps with real `AXUIElement` text access** (native AppKit,
Catalyst, most well-behaved Electron apps):
- Read `kAXFocusedUIElementAttribute` → `kAXValueAttribute` and
  `kAXSelectedTextRangeAttribute`.
- **Verify:** the tail block's `exactText` must appear in `AXValue` ending at
  (or containing) the caret region. No match → the app or user changed the
  text since we pasted → abort to the clipboard fallback (corrected text on
  clipboard + notification), never a blind edit.
- Compute the target range in **UTF-16 offsets** (AX ranges are CFRange over
  the AX string — not grapheme clusters; Devanagari makes this distinction
  real), set `kAXSelectedTextRangeAttribute`, then reuse the existing
  clipboard-safe ⌘V to paste the replacement over the selection.
- Selection + one paste ⇒ the host app records **one undo step**. That's why
  we paste rather than setting `kAXValueAttribute` directly — writing AXValue
  bypasses most apps' undo stacks entirely.

**(b) Keyboard-navigation fallback** — AX read fails or lies (terminals,
some Electron builds, Java apps):
- We know the exact tail text and assume the caret sits at its end (the only
  safe assumption we can make). Compute the selection with synthetic keys:
  `⇧←` per grapheme, `⌥⇧←` per word, `⌘⇧←` per line — chosen to minimize
  event count — then paste the replacement.
- Grapheme clusters, not UTF-16, for arrow-key math (arrow keys move by
  grapheme; "क्या" is two presses, four UTF-16 units).
- Gated hard: only within the tail block, only if the last paste was < 120 s
  ago and the frontmost app hasn't changed since. Stale ⇒ abort to clipboard.

**(c) Whole-block re-paste — last resort:**
- Select the entire tail block (`⇧←` × grapheme count, batched CGEvents,
  capped at 2,000 graphemes — beyond that, clipboard fallback), then paste
  the fully corrected block in one go. One selection + one paste = still one
  undo step. Ugly but bombproof for "make that camelCase" on a short tail.

Secure input (`IsSecureEventInputEnabled()`): editing is **refused
outright**, same policy as dictation — corrected text goes to the clipboard
with a notification.

## Command grammar — how edits coexist with dictation

Three candidates, one winner:

| Option | Verdict |
|---|---|
| Address prefix "Vani, …" | ✗ Whisper hears "Bani/Vaani/honey"; every dictation pays an intent-detection tax; false triggers when the user says the app's name. |
| Trailing commands in dictation | ✗ Worst ambiguity — every utterance must be scanned for edit intent; "change Tuesday to Thursday" is a perfectly normal sentence to *dictate*. |
| **Dedicated edit hotkey** | ✓ **Recommended.** A second push-to-talk (default: hold **Right ⌘**, configurable via KeyboardShortcuts like the others). |

Reasoning: a mode key makes intent unambiguous *before* a word is spoken —
zero false positives, zero added latency on the dictation path, and
on-brand: dictation stays pure ("never rewrites you") because edit parsing
never touches it. The HUD pill renders in a distinct **edit style** (pencil
glyph, inverted outline) so the mode is always visible. `HotkeyManager`
already owns a CGEventTap; adding a second PTT key is incremental.

Flow: hold Right ⌘ → speak "change Tuesday to Thursday" → release →
transcribe (same pipeline, code-mode-style cleanup: no auto-caps/period) →
parse intent → verify → apply → pill flashes the interpretation
(`Tuesday → Thursday`) for ~1.2 s, then fades. Esc during the flash =
synthesize ⌘Z and revert the ledger.

## Intent parsing — deterministic first, LLM never silently

`EditCommandParser` (VaniCore, pure functions, unit-tested like
`CommandProcessor`). Grammar, EN first (HI in milestone 4):

```
command     := select | change | delete | transform | undo
select      := "select" target
change      := ("change"|"replace") anchor ("to"|"with") replacement
delete      := "delete" (target | "from" anchor ["onward" | "to" anchor])
transform   := ("make that"|"make it") style | ("capitalize"|"uppercase"|"lowercase") target
undo        := "undo that" | "scratch that"
target      := ["the"] ["last"|"first"] ("word"|"sentence"|"paragraph"|"line") | "that" | "everything"
style       := "camel case"|"snake case"|"kebab case"|"title case"|"uppercase"|"lowercase"
```

- **Anchors are literal**, matched against the tail block only, nearest to
  the caret wins (Whisper emits no quotes; "delete from however onward"
  binds `however` to its *last* occurrence in the tail).
- **"that"** = the most recent ledger entry, or the current voice-made
  selection if one exists (so "select the last sentence" → "make that
  camelCase" chains).
- Replacements pass through the existing cleanup chain minus auto-caps
  (vocabulary corrections still apply — "change waani to Vani" works).
- **LLM fallback** (off by default, setting "LLM edit fallback"): only when
  the deterministic parse fails *and* Ollama is up. The model is forced into
  the same intent schema (JSON, validated); any anchor it invents that isn't
  a substring of the tail block ⇒ reject. Never silent: the flash chip is
  badged `✨ LLM` and requires the same visible interpretation before/while
  applying. Deterministic parses stay LLM-free forever — on-brand.
- Unparseable + no fallback ⇒ pill shows "didn't catch an edit command",
  nothing is touched. An edit command never falls through to being *typed*.

## Risk register

| Risk | Mitigation |
|---|---|
| Focus changes mid-edit | Re-check frontmost bundle ID before every CGEvent batch; mismatch ⇒ abort, nothing typed into the wrong app, notification. |
| App/user modified text since paste | AX path: exact-string verification against `AXValue`, abort on mismatch. Non-AX path: 120 s freshness gate + same-app gate; beyond that, clipboard fallback only. |
| Secure fields | `IsSecureEventInputEnabled()` ⇒ refuse, clipboard + notification (existing policy, reused). |
| Undo integrity | Every edit = one selection + one ⌘V ⇒ one undo step in AppKit/most apps. Known exception: some Electron apps split paste-over-selection into delete+insert (two ⌘Z) — documented, acceptable. Never mutate `AXValue` directly (kills undo). |
| Wrong-target edits (anchor ambiguity) | Nearest-to-caret binding + interpretation flash + Esc-to-⌘Z window; ledger reverted on undo. |
| Clipboard races | Reuse `TextInjector`'s save/restore; edits serialize behind the same MainActor path as dictation. |
| Grapheme vs UTF-16 offsets | AX ranges in UTF-16; arrow-key math in grapheme clusters. Fixture tests with Devanagari + emoji. |
| IME/marked text active in target | AX `kAXSelectedTextRange` set fails or misplaces ⇒ verification of the post-edit value catches it; abort + ⌘Z if the readback doesn't match expectation (AX path can self-check; fallback paths cannot — hence their tighter gates). |

---

## Milestone 1 — The Ledger & retroactive scratch

### Problem
"Scratch that" today only discards the in-flight dictation. The most common
edit — *undo what you just pasted* — requires hands. And nothing downstream
can exist without the session model.

### UX
- Hold Right ⌘, say "scratch that" (or "delete that") → the last Vani paste
  disappears from the target app, one ⌘Z-able step.
- Invisible otherwise: the ledger has no UI in this milestone.

### Technical design
- `PasteLedger` in VaniCore + wiring in `TextInjector.insert` (record on
  confirmed injection only). Tail-block grouping, caps, per-app keying.
- Second PTT key in `HotkeyManager` (default Right ⌘) + edit-mode HUD style.
- Delete-last-paste via strategy (a) with (c)'s selection math as fallback;
  verification + abort paths as specced.
- First `PasteLedgerTests` + `EditCommandParser` skeleton (only
  `undo`/`scratch that` productions).

### Acceptance
- Dictate into TextEdit, "scratch that" → text gone; one ⌘Z restores it.
- Same in iTerm (no AX text model) within 120 s.
- Switch apps between paste and command → refused with notification, target
  app untouched.

### Effort & risks
~3 days. Risk: Right ⌘ collides with user muscle memory in some apps —
mitigated by making it configurable and chord-based like existing hotkeys.

## Milestone 2 — AX edit engine + grammar core

### Problem
Fixing one word today means hands on keyboard. This is the headline
capability: "change Tuesday to Thursday."

### UX
- Edit-key commands: `select …`, `change X to Y`, `delete X`,
  `delete the last word/sentence/paragraph`.
- Interpretation flash (`Tuesday → Thursday`, 1.2 s) with Esc-to-undo.
- Scope: AX-capable apps only (TextEdit, Notes, Mail, Xcode, Slack…); others
  get "this app needs Milestone 3" — honest clipboard fallback meanwhile.

### Technical design
- `AXTextEditor` (Vani target): focused-element read, exact-string verify,
  UTF-16 range set, paste-over-selection via existing injector.
- Full deterministic `EditCommandParser` for select/change/delete; sentence
  and paragraph segmentation over the tail block.
- Ledger mutation on success; `TranscriptStore` logs edits with an
  `edit` engine tag so the dashboard counts them.

### Acceptance
- In Notes: dictate two sentences; "select the last sentence" highlights it;
  "change Tuesday to Thursday" replaces the right occurrence; each edit is
  one ⌘Z.
- Externally-modified text (type a char manually mid-block) ⇒ edit refused,
  clipboard fallback fires.

### Effort & risks
~5 days. Risk: Electron AX trees report stale `AXValue` — verification turns
that into a clean refusal rather than a wrong edit; those apps wait for M3.

## Milestone 3 — Fallbacks + transforms

### Problem
Terminals and AX-hostile apps cover half of real usage (code mode exists for
a reason), and casing transforms are the killer edit there.

### UX
- Everything from M2 works in iTerm/VS Code/Cursor via keyboard-nav or
  whole-block re-paste — same commands, same one-undo behavior.
- New transforms: "make that camelCase / snake case / kebab case / title
  case", "uppercase/lowercase that", reusing `CasingCommands` machinery.
- New range grammar: "delete from 'however' onward", "delete from X to Y".

### Technical design
- `KeyboardNavigator` (grapheme-aware arrow-key selection builder, batched
  CGEvents) + whole-block strategy with the 2,000-grapheme cap.
- Strategy selector: try (a); on read/verify failure within gates, (b); else
  (c); else clipboard. Every hop logged via `VaniLog`.
- Transform implementations in VaniCore next to `CasingCommands`.

### Acceptance
- In iTerm: dictate `get user name`, "make that camelCase" → `getUserName`,
  one ⌘Z.
- "delete from however onward" in TextEdit and iTerm both trim correctly.
- Devanagari tail block edits select correct grapheme ranges.

### Effort & risks
~4 days. Risk: caret-position assumption in fallback apps — the freshness
gate plus loud aborts keep failures safe, not silent.

## Milestone 4 — LLM fallback, Hindi, polish

### Problem
The deterministic grammar can't cover free-form phrasings ("swap those two
words", "get rid of the bit about pricing"), and Hindi speakers get no edit
commands at all.

### UX
- Hindi grammar: "बदलो X को Y" / "X ko Y kar do", "हटाओ …" / "hatao …",
  "पिछला वाक्य" (last sentence) — Devanagari and romanized, like
  `CommandProcessor`.
- "LLM edit fallback" setting (default **off**). When it fires, the
  interpretation chip is badged `✨` — the user always knows.
- Dashboard: edit history alongside dictations; settings for edit hotkey.

### Technical design
- Ollama intent extraction constrained to the parser's intent enum (JSON
  schema in prompt, strict validation, anchor-must-be-substring rule).
- Hindi productions in `EditCommandParser`; fixture tests mirroring the
  existing Hindi test style.
- Hardening: multi-app ledger juggling, docs/README section, lexicon sheet
  in the Dashboard reference.

### Acceptance
- With fallback off, unparsed commands refuse cleanly (no LLM call, verified
  by log).
- With it on: "get rid of the last bit about pricing" produces a visible
  ✨-badged interpretation before text changes; invalid LLM anchors are
  rejected.
- "Tuesday ko Thursday kar do" works end-to-end.

### Effort & risks
~3–4 days. Risk: a 1B model hallucinating intents — contained by schema
validation, substring-anchor rule, visible badging, and default-off.
