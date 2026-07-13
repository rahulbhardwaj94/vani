import { REPO_URL } from "@/lib/github";

export default function Footer() {
  return (
    <footer className="mx-auto flex max-w-[1180px] flex-wrap items-baseline justify-between gap-4 px-[clamp(20px,5vw,64px)] py-10">
      <div className="flex items-baseline gap-2.5">
        <span lang="hi" className="font-hindi text-xl font-medium">
          वाणी
        </span>
        <span className="font-display text-[15px]">Vani — voice, speech</span>
      </div>
      <div className="flex gap-6 font-mono text-[12.5px] text-canvas-muted">
        <a href={REPO_URL} className="text-canvas-muted transition-colors hover:text-saffron-text">
          github
        </a>
        <a
          href={`${REPO_URL}/issues`}
          className="text-canvas-muted transition-colors hover:text-saffron-text"
        >
          issues
        </a>
        <span>MIT © 2026</span>
      </div>
    </footer>
  );
}
