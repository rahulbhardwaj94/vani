import type { CSSProperties } from "react";

/**
 * Deterministic bar heights (same formula as the design source) so server
 * and client render identically — no Math.random, no hydration drift.
 */
export function barHeights(count: number, maxH: number): number[] {
  const heights: number[] = [];
  for (let i = 0; i < count; i++) {
    const h = maxH * (0.35 + 0.65 * Math.abs(Math.sin(i * 1.7 + 0.8) * Math.cos(i * 0.6)));
    heights.push(Math.max(6, Math.round(h)));
  }
  return heights;
}

type WaveformProps = {
  count: number;
  maxHeight: number;
  gap?: number;
  /** vaniBar (speech) or vaniBreathe (idle presence) */
  animation?: "bar" | "breathe";
  className?: string;
  style?: CSSProperties;
};

/** A row of hairline saffron bars — the voice motif. Decorative only. */
export default function Waveform({
  count,
  maxHeight,
  gap = 5,
  animation = "bar",
  className,
  style,
}: WaveformProps) {
  return (
    <div
      aria-hidden="true"
      className={className}
      style={{ display: "flex", alignItems: "center", gap, ...style }}
    >
      {barHeights(count, maxHeight).map((h, i) => {
        const dur = 0.9 + ((i * 37) % 50) / 100;
        const anim =
          animation === "bar"
            ? `vaniBar ${dur.toFixed(2)}s ease-in-out ${(i * 0.045).toFixed(2)}s infinite`
            : `vaniBreathe ${(1.2 + (i % 5) * 0.18).toFixed(2)}s ease-in-out ${(i * 0.07).toFixed(2)}s infinite`;
        return (
          <span
            key={i}
            style={{
              display: "inline-block",
              width: 4,
              borderRadius: 4,
              background: "var(--saffron)",
              height: h,
              transformOrigin: "center",
              animation: anim,
            }}
          />
        );
      })}
    </div>
  );
}
