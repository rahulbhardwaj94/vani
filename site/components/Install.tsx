import CopyBrewButton from "./CopyBrewButton";
import { REPO_URL } from "@/lib/github";

type InstallProps = {
  stars: string | null;
};

export default function Install({ stars }: InstallProps) {
  return (
    <section
      id="install"
      aria-labelledby="install-heading"
      className="bg-contrast-bg px-[clamp(20px,5vw,64px)] py-[clamp(88px,11vw,150px)] text-contrast-ink"
    >
      <div className="mx-auto flex max-w-[1180px] flex-col items-start gap-9">
        <h2
          id="install-heading"
          className="m-0 font-display text-[clamp(38px,6vw,76px)] leading-[1.05] tracking-[-0.015em] text-balance"
          style={{ fontOpticalSizing: "auto", fontWeight: 420 }}
        >
          Start speaking in a minute.
        </h2>
        <CopyBrewButton variant="install" />
        <div className="flex flex-wrap gap-3.5">
          <a
            href={REPO_URL}
            className="inline-flex items-center gap-2.5 rounded-full border-[1.5px] border-contrast-ink px-6 py-3.5 font-mono text-sm leading-none text-contrast-ink transition-colors hover:bg-contrast-ink hover:text-contrast-bg"
          >
            ★ Star on GitHub{stars ? ` · ${stars}` : ""}
          </a>
          <a
            href={`${REPO_URL}/releases/latest`}
            className="inline-flex items-center rounded-full border-[1.5px] border-saffron bg-saffron px-[26px] py-3.5 text-[15px] leading-none font-medium text-ink transition-colors hover:border-contrast-ink hover:bg-contrast-ink hover:text-contrast-bg"
          >
            Download for Mac
          </a>
        </div>
        <p className="m-0 mt-3 max-w-[480px] text-[15px] leading-[1.6] text-contrast-muted">
          Built by Rahul Bhardwaj. MIT licensed. No account, no subscription,
          no analytics — just an app on your Mac.
        </p>
      </div>
    </section>
  );
}
