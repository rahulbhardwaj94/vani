const EMAIL = "rhlbhrdwj3@gmail.com";

const featureMailto = `mailto:${EMAIL}?subject=${encodeURIComponent(
  "Vani feature request",
)}&body=${encodeURIComponent(
  "What I wish Vani could do:\n\nHow I'd use it:\n",
)}`;

const praiseMailto = `mailto:${EMAIL}?subject=${encodeURIComponent(
  "Vani made me smile",
)}`;

export default function Contact() {
  return (
    <section
      aria-labelledby="contact-heading"
      className="mx-auto max-w-[1180px] border-t-[1.5px] border-canvas-ink px-[clamp(20px,5vw,64px)] py-[clamp(72px,9vw,130px)]"
    >
      <p className="m-0 mb-5 font-mono text-[12.5px] tracking-[0.08em] text-canvas-muted">
        08 · Write back
      </p>
      <h2
        id="contact-heading"
        className="m-0 max-w-[760px] font-display text-[clamp(38px,5.5vw,68px)] leading-[1.05] tracking-[-0.015em] text-balance"
        style={{ fontOpticalSizing: "auto", fontWeight: 420 }}
      >
        Tell me what it should hear next.
      </h2>
      <p className="mt-6 mb-0 max-w-[620px] text-[17px] leading-[1.6] text-canvas-muted">
        Vani ships a new feature every week, and the queue is built from
        mail like yours. Missing something? Loving something? Both land in
        the same inbox — mine.
      </p>

      <div className="mt-10 flex flex-wrap items-center gap-3.5">
        <a
          href={featureMailto}
          className="inline-flex items-center rounded-full border-[1.5px] border-canvas-ink bg-saffron px-6 py-3.5 text-[15px] leading-none font-medium text-ink transition-colors hover:bg-canvas-ink hover:text-canvas"
        >
          Request a feature
        </a>
        <a
          href={praiseMailto}
          className="inline-flex items-center rounded-full border-[1.5px] border-canvas-ink px-6 py-3.5 text-[15px] leading-none font-medium transition-colors hover:bg-canvas-ink hover:text-canvas"
        >
          Send some praise
        </a>
        <a
          href={`mailto:${EMAIL}`}
          className="font-mono text-[13.5px] text-canvas-muted transition-colors hover:text-saffron-text"
        >
          {EMAIL}
        </a>
      </div>

      <p className="m-0 mt-7 font-mono text-[13px] leading-[1.8] text-canvas-muted">
        replies come from a human · bugs → github issues get fixed fastest
      </p>
    </section>
  );
}
