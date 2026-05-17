# Decisions log

Append-only per CLAUDE.md. New entries on top.

---

## 2026-05-17 — Git init + GitHub remote

**Status:** completed
**Changes:**
- Initialized `~/Documents/projects/mhealth-installer/` as a git repo
- Added `.gitignore` (excludes `build/` and `payload/usr/local/mhealth/VERSION`)
- Created `README.md` and this `DECISIONS.md`
- Pushed initial commit to GitHub `jcaveo/mhealth-installer` (private)

**Why:**
- CLAUDE.md mandates DECISIONS.md + git for every active project — was operating without either since 2026-05-11. Fixing.

**Attempted but reverted:** Tried replacing `~/bin/mhealth-kill` etc. with symlinks into the payload to eliminate the cp-after-edit dance. **It broke the running server** — launchd-spawned Python can't follow symlinks into `~/Documents/` because of macOS TCC restrictions (Errno 1 "Operation not permitted"). Reverted to real files. The cp dance stays for THIS dev machine. **The .pkg itself is unaffected** — when teammates install it, scripts go to `/usr/local/mhealth/bin/` which is outside the TCC-protected paths.

**Future option:** If we want a clean source-of-truth, the repo would need to live OUTSIDE `~/Documents/` (e.g., `~/Code/` or `~/Workspace/`). Not changing now — too disruptive.

**Pending:**
- Apple Developer ID signing + notarization (user has it, deferred per "warning is fine for now")

---

## 2026-05-17 — Split Space tab into Caches + Archive, reorder + rename tabs

**Status:** completed
**Changes:**
- Split `pane-space` into `pane-caches` (system caches only) + `pane-archive` (project folder scanner + archived items)
- Renamed: "Browser Tabs" → **Tabs**, "Space" → split into **Caches** + **Archive**
- Reordered tab bar by usage frequency: Tabs · Processes · Read Later · Caches · Archive · Projects · Time Spent · Cloud Setup
- `switchTab()` back-compat: old `space`/`disk` → `caches`; `cloud` → `cloudsetup`

**Why:**
- Side-by-side system caches and project folders felt like one concept; user wanted them as separate concerns
- "Space" was too vague — "Caches" and "Archive" describe the actual job

---

## 2026-05-17 — Snooze notifications

**Status:** completed
**Changes:**
- New file `~/Library/Application Support/mac-health-watcher/snoozed-until` stores epoch deadline
- `mac-health-watcher` checks `[ "$now" -ge "$snoozed_until" ]` before sending notification
- `GET /snooze` returns `{snoozed, until, remaining_seconds}`; `POST /snooze {seconds}` sets it (0 cancels)
- UI: top-right chip always visible, dropdown with 15m / 1h / 2h / Until 9 AM tomorrow / Resume now
- Auto-refreshes every 30 s so the countdown stays current

**Why:**
- During heavy builds RAM intentionally spikes; user wanted a way to silence alerts for an hour without disabling the watcher

---

## 2026-05-17 — Cache safety: risk levels + Docker special-case + better descriptions

**Status:** completed
**Changes:**
- Each cache candidate now has `risk` (safe/caution/danger), `what_breaks`, `regen` fields
- Docker VM specifically: `risk=danger`, `action=docker-prune`. Replaced "Clean" with "Prune (safe)" button that runs `docker system prune -f` (preserves named volumes). Bulk-delete checkbox disabled for Docker.
- New endpoint `POST /disk/docker-prune {deep: bool}` wraps `docker system prune -f [-a]`
- Chrome cache + Playwright marked `risk=caution`
- UI shows color-coded risk badges (🟢 SAFE / 🟡 CAUTION / 🔴 DANGER) and three-line descriptions including what breaks + regen time

**Why:**
- User flagged discomfort with the cavalier "Safe to delete" labeling
- Docker VM is NOT just cache — it contains named volumes (Postgres/Redis data). The old labeling could cause real data loss.

---

## 2026-05-17 — Folder scanner: Browse + multi-path + Scan home

**Status:** completed
**Changes:**
- `📂 Browse…` button → osascript `choose folder` picker → returns POSIX path
- Multi-path: comma-separated paths in scan input → backend merges classifications
- 🏠 Scan home preset: lists top-level `$HOME` dirs with sizes (overview before deep-scan)
- Path presets: `~/Documents/projects`, `~/Desktop`, `~/Downloads`, `~/Movies`
- New endpoints: `GET /cloud/pick-folder`, `GET /cloud/home-overview`; updated `/cloud/scan` to accept comma-separated paths

**Why:**
- User has projects at multiple paths; single-input scanning was too restrictive
- "Where is my disk space going?" needs a quick overview before drilling in

---

## 2026-05-17 — Cloud Archive: BYO recipes (R2 / Drive / Mega) + provider picker wizard

**Status:** completed
**Changes:**
- Cloud Archive feature shipped using `rclone` under the hood (no managed endpoint built)
- Setup wizard in Cloud Setup tab: 3 provider cards (R2 / Drive / Mega) with inline numbered recipes
- Every code block has a one-click Copy button
- `INSTALL.md` Section 3 expanded with full step-by-step recipes for all three providers
- Atomic archive flow: rclone copy → rclone check --one-way → registry write → rm local. Rollback on check failure.
- Restore refuses to overwrite existing path; default `keep_remote: true`

**Why:**
- Initially scoped a managed token-minting endpoint (Cloudflare Worker + Zero Trust + R2). Rolled back to BYO after honest cost/usage analysis — YAGNI until 3+ devs ask for managed
- BYO means zero ongoing cost + zero infra to maintain; devs pay their own R2/Drive/Mega bills if any

**Pending:**
- Managed endpoint if/when 3+ devs ask for it
- Progress UI for big archive uploads (currently the HTTP request blocks until done)

---

## 2026-05-15 — Project tracker seeded with 11 projects

**Status:** completed
**Changes:**
- Bulk-wrote `~/Library/Application Support/mac-health-watcher/projects.json` with 11 entries (in_progress 8 / finished 3)
- Sourced from project_*.md memory files + on-disk `~/Documents/projects/` + CLAUDE.md live-projects section
- Seeded: aveo-finance-hub, credit-to-cash, lead-opener, Pilotdeck, Stayntra Live, Aveo AI Site, B2B SaaS Marketing Platform, mhealth ecosystem (in progress); Aveosoft Leave Manager, invoice-automation, session-auto-rename (finished)

**Why:**
- "Track all projects built with Claude" — explicit user ask

---

## 2026-05-15 — Projects tab added

**Status:** completed
**Changes:**
- New `pane-projects` with table: Name / Description / State / Last work / Path / Pending / Actions
- Add/Edit modal with form fields
- CRUD endpoints: `GET /projects`, `POST /projects {op:add|update}`, `DELETE /projects?id=…`
- Storage at `~/Library/Application Support/mac-health-watcher/projects.json`
- Path tilde-expansion fix in `/reveal` so `~/`-prefixed paths from project entries open in Finder

**Why:**
- User wanted a central place to track Claude-built projects with state + path + pending tasks

---

## 2026-05-12 — Initial .pkg installer built

**Status:** completed
**Changes:**
- Created `~/Documents/projects/mhealth-installer/` with pkgbuild/productbuild pipeline
- Audited + parameterized `mac-health-watcher` (removed hardcoded `/Users/jc/` paths; auto-detect terminal-notifier across Apple Silicon + Intel)
- Created plist templates with `__HOME__` placeholder, rendered by `mhealth-setup` at install time
- New scripts: `mhealth-setup` (per-user launchd registration), `mhealth-uninstall`
- `postinstall` runs as root: creates `/usr/local/bin` symlinks, then `launchctl asuser` runs setup as the console user
- Unsigned; Gatekeeper workaround documented (right-click → Open)
- Built `dist/mhealth-installer.pkg` (~140 KB after all features)

**Why:**
- User wanted to distribute mhealth to teammates without sharing repo access — the .pkg is a single double-clickable artifact
