import Waveform from "./Waveform";

export default function MadeForWork() {
  return (
    <section
      aria-labelledby="craft-heading"
      className="mx-auto max-w-[1180px] border-t-[1.5px] border-canvas-ink px-[clamp(20px,5vw,64px)] py-[clamp(72px,9vw,130px)]"
    >
      <p className="m-0 mb-5 font-mono text-[12.5px] tracking-[0.08em] text-canvas-muted">
        03 · Craft
      </p>
      <h2
        id="craft-heading"
        className="m-0 max-w-[760px] font-display text-[clamp(38px,5.5vw,68px)] leading-[1.05] tracking-[-0.015em] text-balance"
        style={{ fontOpticalSizing: "auto", fontWeight: 420 }}
      >
        Made for how you actually talk &amp; work.
      </h2>

      <div className="mt-12 grid grid-cols-[repeat(auto-fit,minmax(300px,1fr))] gap-5">
        <div className="flex flex-col gap-[18px] rounded-[28px] border-[1.5px] border-canvas-ink p-8">
          <p className="m-0 text-[17px] font-medium">Code mode</p>
          <p className="m-0 text-[15px] leading-[1.6] text-canvas-muted">
            In terminals and editors, spoken casing and symbols become real
            syntax.
          </p>
          <div className="border-t-[1.5px] border-canvas-ink pt-4 font-mono text-[13.5px] leading-[2.1]">
            <p className="m-0">
              <span className="text-canvas-muted">&ldquo;camel case get user name&rdquo;</span>
              <br />→ getUserName
            </p>
            <p className="m-0 mt-3">
              <span className="text-canvas-muted">&ldquo;git commit dash m&rdquo;</span>
              <br />→ git commit -m
            </p>
          </div>
        </div>
        <div className="flex flex-col gap-[18px] rounded-[28px] border-[1.5px] border-canvas-ink p-8">
          <p className="m-0 text-[17px] font-medium">Fast at any length</p>
          <p className="m-0 text-[15px] leading-[1.6] text-canvas-muted">
            Chunks are transcribed while you&rsquo;re still speaking, so a
            two-minute ramble lands as fast as a sentence.
          </p>
          <p className="m-0 mt-auto font-display text-[56px] leading-none">
            ~1<span className="text-[28px]"> s</span>
          </p>
          <p className="m-0 font-mono text-xs text-canvas-muted">
            stop-to-text, any length
          </p>
        </div>
        <div className="flex flex-col gap-[18px] rounded-[28px] border-[1.5px] border-canvas-ink p-8">
          <p className="m-0 text-[17px] font-medium">A quiet HUD</p>
          <p className="m-0 text-[15px] leading-[1.6] text-canvas-muted">
            A live waveform floats while you hold the key — then gets out of
            the way. Esc discards, no questions asked.
          </p>
          <Waveform count={16} maxHeight={44} gap={4} className="mt-auto" style={{ height: 44 }} />
        </div>
      </div>

      <p className="m-0 mt-8 font-mono text-[13px] leading-8 text-canvas-muted">
        also: stats dashboard (time saved vs typing) · scratchpad · voice
        snippets · custom vocabulary
      </p>
    </section>
  );
}
