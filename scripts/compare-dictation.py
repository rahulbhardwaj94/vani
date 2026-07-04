#!/usr/bin/env python3
"""
Side-by-side dictation shootout: LokVaani vs Wispr Flow (or any two tools).

How it works:
  1. The script shows you a reference passage. Read it aloud ONCE per tool,
     dictating straight into this terminal (both tools paste into the
     focused window). Press Enter on an empty line to finish each capture.
  2. It scores each transcript against the reference: word error rate (WER),
     clipped last word, adjacent duplicated words, and dropped content.
  3. Results land in dictation-report.md — ready to share.

Run:  python3 scripts/compare-dictation.py
"""

import datetime
import re

TOOLS = ["LokVaani", "Wispr Flow"]

PASSAGES = [
    ("Fillers + short command",
     "Um, can you send me the report by Friday? I think, uh, we should also "
     "loop in the design team before the review.",
     "Tests filler removal and punctuation. Say the 'um' and 'uh' out loud!"),

    ("Self-correction",
     "I have a meeting tomorrow morning with a client. Let's change the "
     "meeting to Friday at 6 p.m. No, no, just change it to Friday at 6 p.m.",
     "Say the correction naturally. NOTE: a smart tool may apply the "
     "correction and score a HIGHER WER here while being MORE useful — "
     "judge this row by eye, not by number."),

    ("Long technical monologue",
     "You most likely fall into one of two camps. You either check every "
     "single command the AI runs before it runs, or you YOLO run AI with "
     "zero oversight. This either wastes your time or opens you up to huge "
     "security issues. That is why in this video I will show you how to "
     "sandbox your AI so you can save time and rest knowing your AI is "
     "unable to do anything malicious on its own.",
     "Tests long-form: tail clipping on the final word ('own'), duplicated "
     "words at chunk boundaries, dropped sentences."),

    ("Numbers and times",
     "The standup is at nine thirty a.m., the demo is at 6 p.m. on the "
     "twenty-first, and the budget is around twenty-five thousand dollars.",
     "Tests number/time formatting. Tools differ on digits vs words — "
     "compare readability, not just WER."),

    ("Technical vocabulary",
     "I'm using dev containers with node_modules mounted as a volume, "
     "running npm and pnpm commands, plus Ollama and WhisperKit on my "
     "MacBook.",
     "Tests jargon. If LokVaani mishears a term, add it in "
     "History & Vocabulary and rerun — that's the feature working."),
]


def normalize(text: str) -> list[str]:
    return re.sub(r"[^\w\s']", " ", text.lower()).split()


def wer(ref: list[str], hyp: list[str]) -> float:
    """Word error rate via Levenshtein distance."""
    d = list(range(len(hyp) + 1))
    for i in range(1, len(ref) + 1):
        prev, d[0] = d[0], i
        for j in range(1, len(hyp) + 1):
            cur = min(
                d[j] + 1,
                d[j - 1] + 1,
                prev + (ref[i - 1] != hyp[j - 1]),
            )
            prev, d[j] = d[j], cur
    return d[len(hyp)] / max(len(ref), 1)


def adjacent_dupes(words: list[str]) -> list[str]:
    return [words[i] for i in range(1, len(words))
            if words[i] == words[i - 1] and len(words[i]) >= 3]


def capture(tool: str) -> str:
    print(f"\n  ▶ Dictate with {tool} now (finish with an EMPTY line):")
    lines = []
    while True:
        try:
            line = input()
        except EOFError:
            break
        if line.strip() == "":
            if lines:
                break
            continue
        lines.append(line)
    return " ".join(lines).strip()


def main() -> None:
    print(__doc__)
    report = [
        f"# Dictation shootout — {' vs '.join(TOOLS)}",
        f"_{datetime.date.today().isoformat()}_",
        "",
        "| Passage | Tool | WER | Last word kept | Adjacent dupes |",
        "|---|---|---|---|---|",
    ]
    raw_sections = []

    for name, reference, hint in PASSAGES:
        ref_words = normalize(reference)
        print("\n" + "=" * 72)
        print(f"PASSAGE: {name}\n")
        print(f'READ ALOUD:\n  "{reference}"\n')
        print(f"  ({hint})")

        raw_sections.append(f"\n## {name}\n\n**Reference:** {reference}\n")

        for tool in TOOLS:
            hyp = capture(tool)
            hyp_words = normalize(hyp)
            rate = wer(ref_words, hyp_words)
            last_ok = "yes" if hyp_words and hyp_words[-1] == ref_words[-1] else "**NO**"
            dupes = adjacent_dupes(hyp_words)
            dupes_str = ", ".join(dupes) if dupes else "none"
            report.append(
                f"| {name} | {tool} | {rate:.1%} | {last_ok} | {dupes_str} |"
            )
            raw_sections.append(f"**{tool}:** {hyp}\n")
            print(f"    {tool}: WER {rate:.1%} · last word "
                  f"{'kept' if last_ok == 'yes' else 'MISSING'} · dupes: {dupes_str}")

    out = "\n".join(report) + "\n" + "\n".join(raw_sections)
    path = "dictation-report.md"
    with open(path, "w") as f:
        f.write(out)
    print("\n" + "=" * 72)
    print(f"Report written to {path} — share that file.")
    print("Reminder: on the self-correction row, lower verbatim WER isn't "
          "automatically better — check which output you'd actually send.")


if __name__ == "__main__":
    main()
