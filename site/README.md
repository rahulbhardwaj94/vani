# Vani landing site

The marketing site for [Vani](https://github.com/rahulbhardwaj94/vani) —
Next.js (App Router) + TypeScript + Tailwind CSS, built from the approved
Claude Design output ("Vani Landing"). Design system: five locked colors
(paper / ink / signal saffron / night / muted), 1.5px ink borders, no
box-shadows, Fraunces display + Geist UI + Geist Mono + Noto Serif
Devanagari, paper/night section rhythm. Dark mode swaps the paper/night
roles; saffron is constant.

## Run

```sh
cd site
npm install
npm run dev        # http://localhost:3000
npm run build      # production build (also the CI check)
```

GitHub stars and the latest release tag are fetched server-side with ISR
(revalidated hourly) and degrade to nothing if the API is unreachable —
they never block render.

## Deploy to Vercel (recommended)

One-time setup:

1. `npm i -g vercel && vercel login`
2. From the **repo root**: `vercel link` → create project `vani-site`.
3. In the Vercel dashboard → Project → Settings → General, set
   **Root Directory** to `site` (framework auto-detects Next.js).
4. `vercel --prod` (or connect the GitHub repo for deploy-on-push to main).

### Wire up vani.rahulbhardwaj.dev

1. Vercel dashboard → Project → Settings → Domains → Add
   `vani.rahulbhardwaj.dev`.
2. At your DNS provider for `rahulbhardwaj.dev`, add:
   `CNAME  vani  cname.vercel-dns.com`
3. Wait for DNS to propagate (minutes); Vercel provisions TLS
   automatically. That's it.

If `rahulbhardwaj.dev` isn't registered yet, buy it first (Cloudflare
Registrar / Namecheap / Porkbun), then do step 2 wherever its DNS lives.

## Deploy to AWS (alternative)

Two sane options, in order of preference:

- **AWS Amplify Hosting** — closest to the Vercel experience. Amplify
  console → Host web app → connect the GitHub repo → set app root to
  `site` → it detects Next.js and builds on push. Custom domain: Amplify →
  Domain management → add `vani.rahulbhardwaj.dev` (if the domain's DNS is
  in Route 53 it wires itself; otherwise add the CNAME it shows you).
  ISR works natively.
- **S3 + CloudFront** — only if you want static-only hosting. Requires
  `output: "export"` in `next.config.ts`, which disables ISR (star count
  then freezes at build time and updates only when you rebuild). Not
  recommended unless you already run everything through CloudFront.

Vercel's free tier covers this site comfortably; use AWS only if you want
everything under one roof.

## Structure

```
app/layout.tsx        fonts (next/font, self-hosted) + metadata
app/page.tsx          section composition + GitHub data (ISR)
app/globals.css       design tokens, keyframes, dark mode, reduced motion
lib/github.ts         stars + latest release tag, best-effort
components/
  Nav, Hero,          Hero owns the waveform → code-switched-text loop
  Fidelity, Manifesto, Languages, MadeForWork,
  LaminarFlow,        turbulence-in / laminar-out diagram (04 · Signal)
  HowItWorks, UnderTheHood, WhyLocal, Install, Footer,
  CopyBrewButton,     copy-to-clipboard with confirmation
  Waveform            shared deterministic bar row
```

All motion is transform/opacity only and fully disabled under
`prefers-reduced-motion` (the hero renders its composed final frame; the
laminar diagram freezes into a legible still).
