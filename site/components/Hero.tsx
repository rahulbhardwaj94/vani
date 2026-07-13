"use client";

import { useEffect, useRef, useState } from "react";
import CopyBrewButton from "./CopyBrewButton";
import Waveform from "./Waveform";

type Phase = "hold" | "wave" | "type" | "done";

type Word = { text: string; hi: boolean };

const WORDS: Word[] = [
  { text: "Ship", hi: false },
  { text: "the", hi: false },
  { text: "build", hi: false },
  { text: "tonight,", hi: false },
  { text: "बाक़ी", hi: true },
  { text: "कल", hi: true },
  { text: "सुबह", hi: true },
  { text: "देखेंगे।", hi: true },
];

const HOLD_MS = 1400;
const WAVE_MS = 2600;
const WORD_MS = 110;
const DWELL_MS = 3400;

const HUD: Record<Phase, { label: string; dot: string; anim: string }> = {
  hold: { label: "hold ⌥ to speak", dot: "var(--canvas-muted)", anim: "vaniPulse 1.6s ease-in-out infinite" },
  wave: { label: "listening…", dot: "var(--saffron)", anim: "vaniPulse 1s ease-in-out infinite" },
  type: { label: "⌥ released · transcribing", dot: "var(--saffron)", anim: "none" },
  done: { label: "pasted · 0.9 s", dot: "var(--canvas-ink)", anim: "none" },
};

/**
 * The hero's voice → code-switched-text moment. A timer-driven loop:
 * hold 1.4s → waveform 2.6s → words typeset at 110ms each → dwell 3.4s.
 * Only opacity/transform animate (GPU-cheap). prefers-reduced-motion gets
 * the composed final frame with zero timers.
 */
export default function Hero() {
  const [phase, setPhase] = useState<Phase>("done");
  const [wordCount, setWordCount] = useState(WORDS.length);
  const timers = useRef<ReturnType<typeof setTimeout>[]>([]);

  useEffect(() => {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;

    const t = (fn: () => void, ms: number) => timers.current.push(setTimeout(fn, ms));

    const runLoop = () => {
      setPhase("hold");
      setWordCount(0);
      t(() => setPhase("wave"), HOLD_MS);
      t(() => {
        setPhase("type");
        WORDS.forEach((_, i) => t(() => setWordCount(i + 1), WORD_MS * (i + 1)));
        t(() => setPhase("done"), WORD_MS * WORDS.length + 500);
      }, HOLD_MS + WAVE_MS);
      t(runLoop, HOLD_MS + WAVE_MS + WORD_MS * WORDS.length + 500 + DWELL_MS);
    };

    runLoop();
    const scheduled = timers.current;
    return () => scheduled.forEach(clearTimeout);
  }, []);

  const speaking = phase === "wave";
  const typing = phase === "type" || phase === "done";
  const hud = HUD[phase];
  const ease = "cubic-bezier(0.22, 1, 0.36, 1)";

  return (
    <header
      id="top"
      className="mx-auto max-w-[1180px] px-[clamp(20px,5vw,64px)] pt-[clamp(64px,9vw,128px)] pb-[clamp(56px,7vw,96px)]"
    >
      <div className="max-w-[900px]">
        <h1
          className="m-0 font-display text-[clamp(52px,9.5vw,118px)] leading-[1.02] tracking-[-0.02em] text-balance"
          style={{ fontOpticalSizing: "auto", fontWeight: 420 }}
        >
          It never rewrites you.
        </h1>
        <p className="mt-7 mb-0 max-w-[560px] text-[clamp(17px,2vw,20px)] leading-[1.55] text-canvas-muted">
          Vani is local voice dictation for macOS. Hold a key, speak, and your
          exact words appear in whatever app you&rsquo;re typing in —
          transcribed on your machine, never sent off it.
        </p>
      </div>

      <div className="mt-9 flex flex-wrap items-center gap-3.5">
        <a
          href="#install"
          className="inline-flex items-center rounded-full border-[1.5px] border-canvas-ink bg-saffron px-7 py-[15px] text-[15px] leading-none font-medium text-ink transition-colors hover:bg-canvas-ink hover:text-canvas"
        >
          Download for Mac
        </a>
        <CopyBrewButton variant="hero" />
      </div>
      <p className="mt-[18px] mb-0 font-mono text-xs tracking-[0.02em] text-canvas-muted">
        100% on-device · works in airplane mode · free &amp; MIT
      </p>

      {/* The voice → text centerpiece */}
      <div className="relative mt-[clamp(48px,6vw,84px)] flex min-h-[340px] flex-col justify-center overflow-hidden rounded-[36px] border-[1.5px] border-canvas-ink bg-canvas">
        {/* वाणी watermark */}
        <div aria-hidden="true" className="pointer-events-none absolute inset-0 flex items-center justify-center">
          <span
            className="font-hindi leading-none select-none"
            style={{ fontSize: "clamp(180px, 30vw, 380px)", color: "var(--watermark)" }}
          >
            वाणी
          </span>
        </div>

        {/* HUD chip */}
        <div className="absolute top-6 left-7 inline-flex items-center gap-2.5">
          <span
            aria-hidden="true"
            className="inline-block h-[9px] w-[9px] rounded-full"
            style={{ background: hud.dot, animation: hud.anim }}
          />
          <span aria-live="polite" className="font-mono text-[12.5px] tracking-[0.03em] text-canvas-muted">
            {hud.label}
          </span>
        </div>

        {/* waveform layer */}
        <Waveform
          count={44}
          maxHeight={120}
          className="pointer-events-none absolute inset-0 justify-center"
          style={{
            opacity: speaking ? 1 : phase === "hold" ? 0.25 : 0,
            transition: "opacity 0.6s ease",
          }}
        />

        {/* typeset text layer */}
        <div
          className="relative px-[clamp(28px,6vw,72px)] py-20"
          style={{ opacity: typing ? 1 : 0, transition: "opacity 0.6s ease" }}
        >
          <p className="m-0 max-w-[880px] text-[clamp(24px,3.6vw,42px)] leading-[1.45] text-balance">
            {WORDS.map((w, i) => (
              <span
                key={i}
                lang={w.hi ? "hi" : undefined}
                className={w.hi ? "font-hindi text-saffron" : "font-display"}
                style={{
                  display: "inline-block",
                  opacity: i < wordCount ? 1 : 0,
                  transform: i < wordCount ? "translateY(0)" : "translateY(8px)",
                  transition: `opacity 0.48s ${ease}, transform 0.48s ${ease}`,
                }}
              >
                {w.text}&nbsp;
              </span>
            ))}
            <span
              aria-hidden="true"
              className="text-saffron"
              style={{
                animation: "vaniCaret 1s step-end infinite",
                opacity: phase === "type" ? 1 : 0,
                transition: "opacity 0.3s",
              }}
            >
              ▍
            </span>
          </p>
        </div>

        <div className="absolute right-7 bottom-[22px] left-7 flex flex-wrap justify-between gap-3">
          <span className="font-mono text-xs text-canvas-muted">
            en → hi · auto-detected · one breath
          </span>
          <span className="font-mono text-xs text-canvas-muted">
            {phase === "done" ? "whisper large-v3-turbo · neural engine" : "⌥ push-to-talk"}
          </span>
        </div>
      </div>
    </header>
  );
}
