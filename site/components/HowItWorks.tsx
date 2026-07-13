const STEPS = [
  {
    n: "1",
    title: (
      <>
        Hold{" "}
        <span className="rounded-[10px] border-[1.5px] border-canvas-ink px-3 py-0.5 font-mono text-[0.8em]">
          ⌥
        </span>
      </>
    ),
    body: "Push-to-talk from anywhere. Double-tap for hands-free.",
  },
  {
    n: "2",
    title: <>Speak</>,
    body: "In any language, at any length. The waveform breathes while you talk.",
  },
  {
    n: "3",
    title: <>It appears</>,
    body: "Clean text lands in whatever field your cursor is in. Clipboard-safe paste.",
  },
];

export default function HowItWorks() {
  return (
    <section
      aria-labelledby="how-heading"
      className="mx-auto max-w-[1180px] border-t-[1.5px] border-canvas-ink px-[clamp(20px,5vw,64px)] py-[clamp(72px,9vw,130px)]"
    >
      <p className="m-0 mb-5 font-mono text-[12.5px] tracking-[0.08em] text-canvas-muted">
        05 · How it works
      </p>
      <h2 id="how-heading" className="sr-only">
        How it works
      </h2>
      <div className="mt-6 grid grid-cols-[repeat(auto-fit,minmax(240px,1fr))] gap-[clamp(24px,4vw,56px)]">
        {STEPS.map((s) => (
          <div key={s.n} className="flex flex-col gap-3.5">
            <p className="m-0 font-mono text-[12.5px] text-canvas-muted">{s.n}</p>
            <p className="m-0 font-display text-[clamp(28px,3vw,38px)] leading-[1.1]">
              {s.title}
            </p>
            <p className="m-0 text-[15px] leading-[1.6] text-canvas-muted">{s.body}</p>
          </div>
        ))}
      </div>
      <p className="m-0 mt-14 border-t-[1.5px] border-canvas-ink pt-6 font-mono text-[13px] tracking-[0.03em] text-canvas-muted">
        mic → whisperkit → cleanup → paste &nbsp;·&nbsp; esc to discard
      </p>
    </section>
  );
}
