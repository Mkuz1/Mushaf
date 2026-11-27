# Mushaf (Mus'haf): project status

_Source of truth for this app's claude.ai chat. As of 2026-11-27._

صدقة جارية. Madinah Mus'haf reader (King Fahd, Hafs, 604 pages).

## Current state

| | |
|---|---|
| Version | **1.10.13** (build 32; `flutter_app/pubspec.yaml`) |
| Platforms | Android (Flutter), iPhone/iPad, Windows, macOS (`MushafMac/`), **Apple TV** (`MushafTV/`), web reader |
| App Store | **Apple TV only is live**: id6835142974. iPhone/iPad/Mac are "coming soon" (direct downloads on the site, no App Store badge) |
| Google Play | **Live**: `com.mushaf.myapp` (the only MK app on Play) |
| Downloads | Public repo **Mkuz1/Mushaf-releases** (`v1.10.13`, 2026-11-20) |
| Website | **https://www.mushafapp.com** (`website/`, auto-deploys via `website.yml` to Pages project `mushafapp`) |

## Recent changes

- 2026-11-27: **Website security headers** (MK Apps security review): CSP, HSTS, X-Frame-Options DENY, nosniff, Referrer-Policy and Permissions-Policy for every page, in `website/_headers`. The CSP lists exactly the hosts the site uses (Google Fonts, GitHub API, Cloudflare Web Analytics); if you add a new script, font, embed or API host, add it to the CSP or it will be blocked.
- 2026-11-26: Website shows the live Apple TV App Store listing (PR #41); iPhone/iPad/Mac rows changed from App Store badges to direct downloads; koussa.net invite (PR #40); SEO/share previews, small icons instead of the 377 KB favicon (PR #42).
- 2026-11-26: Redesigned landing page (English default, emerald/gold dedication style); iPhone Duo simulator screenshot tooling.

## Open items

- iPhone/iPad and Mac App Store approval. When approved, switch the rows on the site and in `MK-APPS/build.py` to App Store badges.

## Rules for every MK app (decided in the MK APPS project)

- **This file is the hand-off to the app's own Claude chat.** That chat reads it from GitHub through Project knowledge. Every change to this app (code, release, store, website, decision) must also update this file in the same PR or commit.
- **Nothing local-only.** Every asset, store file and site file lives in the app's GitHub repo. Signing keys and passwords are the only exception and are never committed (they stay in `~/keys` on the Mac).
- **Websites deploy themselves** to Cloudflare Pages from GitHub Actions on push (secrets `CLOUDFLARE_API_TOKEN` / `CLOUDFLARE_ACCOUNT_ID` are set on the repo). No manual or terminal deploys.
- **Every app site invites visitors to https://www.koussa.net** (the MK Apps showcase, source in `Mkuz1/MK-APPS`, served by Cloudflare project `mkuzapps`). Keep that card when editing the site, and update the app's row in `MK-APPS/build.py` when platforms, versions or store links change.
- **SEO and share previews (done 2026-11-26):** keep the OG + Twitter tags with an absolute 1200x630 image under 300 KB, canonical, favicon.ico + 192/512 icons + 180 px touch icon, web manifest, robots.txt, sitemap.xml and SoftwareApplication JSON-LD. When replacing a share image, give it a new file name so WhatsApp refreshes its cache.
- **Store badges only for what is really live.** Re-check the App Store / Play page before adding a badge.
- **Mohamad merges pull requests himself** (Claude Code's auto mode on the Mac blocks `gh pr merge`).

---
_Last updated 2026-11-27. Update this file with every change to the app._
