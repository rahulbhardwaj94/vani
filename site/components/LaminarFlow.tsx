/**
 * New section (not in the original design file, same design language):
 * spoken audio arrives as turbulence — fillers, restarts, crosstalk — and
 * leaves Vani as one laminar line of text. Pure SVG + CSS; only
 * stroke-dashoffset/opacity/transform animate, and the reduced-motion rule
 * in globals.css freezes it into a legible still diagram.
 */

const TURBULENT_PATHS = [
  "M0,42  C70,10 120,88 190,52 S310,6 400,118",
  "M0,86  C60,120 130,30 210,86 S330,140 400,132",
  "M0,140 C80,100 150,190 230,140 S330,96 400,140",
  "M0,196 C70,240 140,150 220,200 S330,150 400,150",
  "M0,238 C90,200 150,262 240,220 S330,250 400,160",
];

const NOISE_WORDS: { x: number; y: number; text: string; hi?: boolean; delay: number }[] = [
  { x: 40, y: 26, text: "umm", delay: 0 },
  { x: 150, y: 64, text: "so, uh", delay: 0.7 },
  { x: 60, y: 118, text: "you know", delay: 1.3 },
  { x: 210, y: 30, text: "मतलब", hi: true, delay: 0.4 },
  { x: 260, y: 178, text: "wait, no —", delay: 1.9 },
  { x: 90, y: 226, text: "basically", delay: 1.1 },
  { x: 230, y: 254, text: "(keyboard clatter)", delay: 2.3 },
];

export default function LaminarFlow() {
  return (
    <section
      aria-labelledby="laminar-heading"
      className="mx-auto max-w-[1180px] border-t-[1.5px] border-canvas-ink px-[clamp(20px,5vw,64px)] py-[clamp(72px,9vw,130px)]"
    >
      <p className="m-0 mb-5 font-mono text-[12.5px] tracking-[0.08em] text-canvas-muted">
        04 · Signal
      </p>
      <h2
        id="laminar-heading"
        className="m-0 max-w-[760px] font-display text-[clamp(38px,5.5vw,68px)] leading-[1.05] tracking-[-0.015em] text-balance"
        style={{ fontOpticalSizing: "auto", fontWeight: 420 }}
      >
        Turbulence in. Laminar out.
      </h2>
      <p className="mt-6 mb-0 max-w-[620px] text-[17px] leading-[1.6] text-canvas-muted">
        Real speech is messy — fillers, restarts, a fan humming, two languages
        in one breath. Vani&rsquo;s voice detector and filler rules strip the
        turbulence and let one structured line through: the thing you meant to
        type.
      </p>

      <div className="mt-12 overflow-hidden rounded-[32px] border-[1.5px] border-canvas-ink bg-canvas-card">
        <svg
          viewBox="0 0 960 280"
          role="img"
          aria-label="Diagram: five turbulent, noisy lines flow into Vani and emerge as a single straight line carrying the sentence “Ship the build tonight.”"
          className="block h-auto w-full"
        >
          {/* turbulent inflow */}
          <g fill="none" stroke="var(--canvas-muted)" strokeWidth="1.5" opacity="0.75">
            {TURBULENT_PATHS.map((d, i) => (
              <path
                key={i}
                d={d}
                strokeDasharray="10 7"
                style={{
                  animation: `vaniFlow ${(4.5 + i * 0.9).toFixed(1)}s linear infinite`,
                }}
              />
            ))}
          </g>

          {/* noise words drifting in the turbulence */}
          <g className="font-mono" fill="var(--canvas-muted)" fontSize="13">
            {NOISE_WORDS.map((w, i) => (
              <text
                key={i}
                x={w.x}
                y={w.y}
                lang={w.hi ? "hi" : undefined}
                className={w.hi ? "font-hindi" : "font-mono"}
                style={{ animation: `vaniNoiseWord 3.6s ease-in-out ${w.delay}s infinite` }}
              >
                {w.text}
              </text>
            ))}
          </g>

          {/* the Vani filter */}
          <rect
            x="418"
            y="102"
            width="124"
            height="76"
            rx="38"
            fill="var(--canvas)"
            stroke="var(--canvas-ink)"
            strokeWidth="1.5"
          />
          <text
            x="480"
            y="143"
            lang="hi"
            textAnchor="middle"
            dominantBaseline="middle"
            className="font-hindi"
            fill="var(--canvas-ink)"
            fontSize="30"
          >
            वाणी
          </text>

          {/* laminar outflow: one straight saffron line */}
          <line
            x1="542"
            y1="140"
            x2="960"
            y2="140"
            stroke="var(--saffron)"
            strokeWidth="3"
            strokeLinecap="round"
          />
          <line
            x1="542"
            y1="140"
            x2="960"
            y2="140"
            stroke="var(--canvas-card)"
            strokeWidth="3"
            strokeLinecap="round"
            strokeDasharray="4 56"
            opacity="0.55"
            style={{ animation: "vaniFlow 2.4s linear infinite" }}
          />
          <text
            x="748"
            y="118"
            textAnchor="middle"
            className="font-display"
            fill="var(--canvas-ink)"
            fontSize="22"
          >
            Ship the build tonight.
          </text>
          <text
            x="748"
            y="170"
            textAnchor="middle"
            className="font-mono"
            fill="var(--canvas-muted)"
            fontSize="12"
          >
            one structured line · nothing else
          </text>
        </svg>

        <div className="flex flex-wrap justify-between gap-3 border-t-[1.5px] border-canvas-ink px-7 py-4">
          <span className="font-mono text-xs text-canvas-muted">
            turbulent in — everything the mic hears
          </span>
          <span className="font-mono text-xs text-canvas-muted">
            laminar out — only what you said
          </span>
        </div>
      </div>
    </section>
  );
}
