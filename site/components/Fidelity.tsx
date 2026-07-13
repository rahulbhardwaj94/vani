export default function Fidelity() {
  return (
    <section
      aria-labelledby="fidelity-heading"
      className="mx-auto max-w-[1180px] border-t-[1.5px] border-canvas-ink px-[clamp(20px,5vw,64px)] py-[clamp(72px,9vw,130px)]"
    >
      <p className="m-0 mb-5 font-mono text-[12.5px] tracking-[0.08em] text-canvas-muted">
        01 · Fidelity
      </p>
      <h2
        id="fidelity-heading"
        className="m-0 max-w-[720px] font-display text-[clamp(38px,5.5vw,68px)] leading-[1.05] tracking-[-0.015em] text-balance"
        style={{ fontOpticalSizing: "auto", fontWeight: 420 }}
      >
        Faithful, not &ldquo;improved.&rdquo;
      </h2>
      <p className="mt-6 mb-0 max-w-[620px] text-[17px] leading-[1.6] text-canvas-muted">
        Cloud dictation passes your speech through a large model that
        paraphrases you — it drops your hedges, flattens your rhythm, and
        occasionally invents. Vani writes down what you actually said.
      </p>

      <div className="mt-12 grid grid-cols-[repeat(auto-fit,minmax(300px,1fr))] gap-5">
        {/* Cloud card */}
        <div className="flex flex-col gap-5 rounded-[28px] border-[1.5px] border-canvas-muted p-8">
          <div className="flex items-baseline justify-between gap-3">
            <span className="font-mono text-[12.5px] tracking-[0.05em] text-canvas-muted">
              a leading cloud tool
            </span>
            <span className="font-mono text-[12.5px] text-canvas-muted">rewritten</span>
          </div>
          <p className="m-0 font-display text-[clamp(18px,2vw,22px)] leading-[1.6] text-canvas-muted">
            &ldquo;The race condition occurs because the mutex is not
            reacquired after awaiting. Guard the callback with a
            semaphore.&rdquo;
          </p>
          <p className="m-0 font-mono text-xs leading-[1.8] text-canvas-muted">
            hedges deleted · two sentences merged · &ldquo;I think&rdquo; gone ·
            your voice, someone else&rsquo;s words
          </p>
        </div>
        {/* Vani card */}
        <div className="flex flex-col gap-5 rounded-[28px] border-[1.5px] border-canvas-ink bg-canvas-card p-8">
          <div className="flex items-baseline justify-between gap-3">
            <span className="font-mono text-[12.5px] tracking-[0.05em]">vani</span>
            <span className="font-mono text-[12.5px] font-medium text-saffron-text">
              0.0% WER
            </span>
          </div>
          <p className="m-0 font-display text-[clamp(18px,2vw,22px)] leading-[1.6]">
            &ldquo;So the race condition happens when the mutex isn&rsquo;t
            re-acquired after the await — I think — so we should, uh, probably
            guard the callback with a semaphore instead.&rdquo;
          </p>
          <p className="m-0 font-mono text-xs leading-[1.8] text-canvas-muted">
            every word yours · technical terms intact · verbatim
          </p>
        </div>
      </div>

      <div className="mt-9 flex flex-wrap items-baseline gap-8">
        <p className="m-0 max-w-[520px] text-sm leading-[1.6] text-canvas-muted">
          From our A/B test on a 70-word technical monologue — in our tests,
          not a universal claim. Your mileage is exactly why the raw transcript
          is the default.
        </p>
        <p className="m-0 max-w-[420px] text-sm leading-[1.6] text-canvas-muted">
          Optional LLM polish exists, off by default — and guarded: if polish
          changes your words, its output is discarded.
        </p>
      </div>
    </section>
  );
}
