import { REPO_URL } from "@/lib/github";
import ThemeToggle from "./ThemeToggle";

type NavProps = {
  stars: string | null;
};

export default function Nav({ stars }: NavProps) {
  return (
    <nav
      aria-label="Main"
      className="sticky top-0 z-50 flex items-center justify-between gap-4 border-b-[1.5px] border-canvas-ink px-[clamp(20px,5vw,64px)] py-4 backdrop-blur-[8px]"
      style={{ background: "var(--nav-bg)" }}
    >
      <a href="#top" className="flex items-baseline gap-2.5">
        <span lang="hi" className="font-hindi text-[26px] leading-none font-medium">
          वाणी
        </span>
        <span className="font-display text-[19px] tracking-[0.01em]">Vani</span>
      </a>
      <div className="flex items-center gap-3">
        <ThemeToggle />
        <a
          href={REPO_URL}
          className="inline-flex items-center gap-2 rounded-full border-[1.5px] border-canvas-ink px-4 py-[9px] font-mono text-[13px] leading-none transition-colors hover:bg-canvas-ink hover:text-canvas"
          aria-label={`Vani on GitHub${stars ? `, ${stars} stars` : ""}`}
        >
          <span aria-hidden="true">★</span>
          {stars && <span>{stars}</span>}
          {!stars && <span>GitHub</span>}
        </a>
        <a
          href="#install"
          className="rounded-full border-[1.5px] border-canvas-ink bg-saffron px-5 py-2.5 text-sm leading-none font-medium text-ink transition-colors hover:bg-canvas-ink hover:text-canvas"
        >
          Install
        </a>
      </div>
    </nav>
  );
}
