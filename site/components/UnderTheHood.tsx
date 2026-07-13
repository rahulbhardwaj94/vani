type UnderTheHoodProps = {
  releaseTag: string | null;
};

export default function UnderTheHood({ releaseTag }: UnderTheHoodProps) {
  const specs: { k: string; v: string }[] = [
    { k: "model", v: "whisper large-v3-turbo · apple neural engine via whisperkit" },
    { k: "polish", v: "ollama gemma3:1b · optional, off by default, guarded" },
    { k: "language", v: "swift 6 · macos 14+ · apple-silicon native" },
    { k: "size", v: "~1,500 lines · no xcode project" },
    { k: "license", v: "mit · free forever" },
    ...(releaseTag ? [{ k: "latest", v: releaseTag }] : []),
  ];

  return (
    <section
      aria-labelledby="hood-heading"
      className="mx-auto max-w-[1180px] border-t-[1.5px] border-canvas-ink px-[clamp(20px,5vw,64px)] py-[clamp(72px,9vw,130px)]"
    >
      <p className="m-0 mb-5 font-mono text-[12.5px] tracking-[0.08em] text-canvas-muted">
        06 · Under the hood
      </p>
      <h2
        id="hood-heading"
        className="m-0 max-w-[760px] font-display text-[clamp(38px,5.5vw,68px)] leading-[1.05] tracking-[-0.015em] text-balance"
        style={{ fontOpticalSizing: "auto", fontWeight: 420 }}
      >
        Built to be forked and understood.
      </h2>
      <dl className="mt-12 border-t-[1.5px] border-canvas-ink font-mono text-sm">
        {specs.map((s) => (
          <div
            key={s.k}
            className="flex flex-wrap justify-between gap-x-8 gap-y-2 border-b-[1.5px] border-canvas-ink px-1 py-[18px]"
          >
            <dt className="text-canvas-muted">{s.k}</dt>
            <dd className="m-0 text-right">{s.v}</dd>
          </div>
        ))}
      </dl>
    </section>
  );
}
