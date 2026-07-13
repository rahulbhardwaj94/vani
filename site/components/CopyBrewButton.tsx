"use client";

import { useEffect, useRef, useState } from "react";
import { BREW_COMMAND } from "@/lib/github";

type CopyBrewButtonProps = {
  /** "hero" = pill on paper; "install" = large block on night. */
  variant: "hero" | "install";
};

/** Copy-to-clipboard for the brew command, with a "copied" confirmation. */
export default function CopyBrewButton({ variant }: CopyBrewButtonProps) {
  const [copied, setCopied] = useState(false);
  const timer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);

  useEffect(() => () => clearTimeout(timer.current), []);

  async function copy() {
    try {
      await navigator.clipboard.writeText(BREW_COMMAND);
    } catch {
      // Clipboard API unavailable (e.g. non-secure context) — still show
      // the state flip so the user knows the button did something; the
      // command itself is selectable text.
    }
    setCopied(true);
    clearTimeout(timer.current);
    timer.current = setTimeout(() => setCopied(false), 1800);
  }

  const hint = copied ? "copied" : "copy";

  if (variant === "install") {
    return (
      <button
        type="button"
        onClick={copy}
        aria-label={`Copy install command: ${BREW_COMMAND}`}
        className="group inline-flex max-w-full cursor-pointer items-center gap-4 rounded-[20px] border-[1.5px] border-[color:var(--contrast-faint)] bg-transparent px-7 py-5 text-left font-mono text-[clamp(14px,1.8vw,17px)] text-[color:var(--contrast-ink)] transition-colors hover:border-saffron hover:text-saffron"
        style={{ overflowWrap: "anywhere" }}
      >
        <span aria-hidden="true" className="text-[color:var(--contrast-faint)]">
          $
        </span>
        <span>{BREW_COMMAND}</span>
        <span aria-live="polite" className="text-[0.85em] opacity-50">
          {hint}
        </span>
      </button>
    );
  }

  return (
    <button
      type="button"
      onClick={copy}
      aria-label={`Copy install command: ${BREW_COMMAND}`}
      className="inline-flex cursor-pointer items-center gap-2.5 rounded-full border-[1.5px] border-canvas-ink bg-transparent px-4 py-3.5 font-mono text-[13.5px] leading-none text-canvas-ink transition-colors hover:bg-canvas-ink hover:text-canvas sm:px-5"
    >
      <span className="max-w-[60vw] truncate sm:max-w-none">{BREW_COMMAND}</span>
      <span aria-live="polite" className="opacity-55">
        {hint}
      </span>
    </button>
  );
}
