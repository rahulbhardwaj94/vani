export default function WhyLocal() {
  return (
    <section
      aria-labelledby="why-heading"
      className="mx-auto max-w-[1180px] border-t-[1.5px] border-canvas-ink px-[clamp(20px,5vw,64px)] py-[clamp(72px,9vw,130px)]"
    >
      <p className="m-0 mb-8 font-mono text-[12.5px] tracking-[0.08em] text-canvas-muted">
        07 · Why local
      </p>
      <h2 id="why-heading" className="sr-only">
        Why local
      </h2>
      <div className="flex max-w-[880px] flex-col gap-[clamp(20px,3vw,32px)]">
        <p className="m-0 font-display text-[clamp(26px,3.6vw,44px)] leading-[1.25]">
          Private, because it never phones home.
        </p>
        <p className="m-0 font-display text-[clamp(26px,3.6vw,44px)] leading-[1.25]">
          Faithful, because nothing paraphrases you.
        </p>
        <p className="m-0 font-display text-[clamp(26px,3.6vw,44px)] leading-[1.25]">
          Free, because it&rsquo;s your silicon doing the work.
        </p>
        <p className="m-0 font-display text-[clamp(26px,3.6vw,44px)] leading-[1.25] text-saffron-text">
          Yours, because it&rsquo;s 1,500 lines you can read.
        </p>
      </div>
    </section>
  );
}
