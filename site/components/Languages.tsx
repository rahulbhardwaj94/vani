export default function Languages() {
  return (
    <section
      aria-labelledby="languages-heading"
      className="mx-auto max-w-[1180px] px-[clamp(20px,5vw,64px)] py-[clamp(72px,9vw,130px)]"
    >
      <p className="m-0 mb-5 font-mono text-[12.5px] tracking-[0.08em] text-canvas-muted">
        02 · Languages
      </p>
      <h2
        id="languages-heading"
        className="m-0 max-w-[760px] font-display text-[clamp(38px,5.5vw,68px)] leading-[1.05] tracking-[-0.015em] text-balance"
        style={{ fontOpticalSizing: "auto", fontWeight: 420 }}
      >
        Hindi is a first-class citizen.
      </h2>
      <p className="mt-6 mb-0 max-w-[620px] text-[17px] leading-[1.6] text-canvas-muted">
        Auto-detection across 99 languages. Speak English, then Hindi, in one
        breath — each part lands in its own script. No menu, no mode switch,
        no transliteration mush.
      </p>

      <div className="mt-12 rounded-[32px] border-[1.5px] border-canvas-ink bg-canvas-card p-[clamp(32px,5vw,64px)]">
        <p className="m-0 mb-6 font-mono text-xs text-canvas-muted">
          one utterance, two scripts
        </p>
        <p className="m-0 text-[clamp(26px,4vw,46px)] leading-[1.5] text-balance">
          <span className="font-display">Ship the build tonight, </span>
          <span lang="hi" className="font-hindi text-saffron">
            बाक़ी कल सुबह देखेंगे।
          </span>
        </p>
        <div className="mt-10 flex flex-wrap gap-3">
          <span className="rounded-full border-[1.5px] border-canvas-ink px-[18px] py-[9px] font-mono text-[13px]">
            &ldquo;new line&rdquo; ↵
          </span>
          <span className="rounded-full border-[1.5px] border-canvas-ink px-[18px] py-2 font-hindi text-[15px]">
            <span lang="hi">&ldquo;नई लाइन&rdquo;</span>{" "}
            <span className="font-mono text-[13px]">↵</span>
          </span>
          <span className="rounded-full border-[1.5px] border-canvas-muted px-[18px] py-[9px] font-mono text-[13px] text-canvas-muted">
            spoken commands work in both
          </span>
        </div>
      </div>
    </section>
  );
}
