export const REPO = "rahulbhardwaj94/vani";
export const REPO_URL = `https://github.com/${REPO}`;
export const BREW_COMMAND = "brew install --cask rahulbhardwaj94/tap/vani";

export type GitHubMeta = {
  /** Formatted star count ("1,842") or null if the API was unreachable. */
  stars: string | null;
  /** Latest release tag ("v0.2.0") or null. */
  releaseTag: string | null;
};

/**
 * Fetched at build time and revalidated hourly (ISR). Both requests are
 * best-effort: any failure returns nulls and the page renders without the
 * numbers — the API must never block or break the render.
 */
export async function getGitHubMeta(): Promise<GitHubMeta> {
  const headers = { Accept: "application/vnd.github+json" };
  const revalidate = 3600;

  const [stars, releaseTag] = await Promise.all([
    fetch(`https://api.github.com/repos/${REPO}`, {
      headers,
      next: { revalidate },
    })
      .then((r) => (r.ok ? r.json() : null))
      .then((j) =>
        // A zero renders as an anti-endorsement — show the plain GitHub
        // pill until there's a number worth showing.
        typeof j?.stargazers_count === "number" && j.stargazers_count > 0
          ? j.stargazers_count.toLocaleString("en-US")
          : null,
      )
      .catch(() => null),
    fetch(`https://api.github.com/repos/${REPO}/releases/latest`, {
      headers,
      next: { revalidate },
    })
      .then((r) => (r.ok ? r.json() : null))
      .then((j) => (typeof j?.tag_name === "string" ? j.tag_name : null))
      .catch(() => null),
  ]);

  return { stars, releaseTag };
}
