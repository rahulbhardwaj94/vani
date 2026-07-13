import Waveform from "./Waveform";

export default function Manifesto() {
  return (
    <section
      aria-labelledby="manifesto-heading"
      className="bg-contrast-bg px-[clamp(20px,5vw,64px)] py-[clamp(96px,13vw,180px)] text-contrast-ink"
    >
      <div className="mx-auto max-w-[1180px]">
        <Waveform count={28} maxHeight={40} animation="breathe" className="mb-12 !items-end" style={{ height: 40 }} />
        <h2
          id="manifesto-heading"
          className="m-0 max-w-[980px] font-display text-[clamp(44px,7.5vw,96px)] leading-[1.05] tracking-[-0.02em] text-balance"
          style={{ fontOpticalSizing: "auto", fontWeight: 420 }}
        >
          Your voice never leaves this machine.
        </h2>
        <p className="mt-9 mb-0 max-w-[560px] text-lg leading-[1.65] text-contrast-muted">
          Whisper and the language model run on the Apple Neural Engine, in
          your Mac&rsquo;s own silicon. There is no server to trust, because
          there is no server.
        </p>
        <p className="mt-12 mb-0 font-mono text-[13px] tracking-[0.04em] text-contrast-faint">
          no cloud · no account · no telemetry · works in airplane mode
        </p>
      </div>
    </section>
  );
}
