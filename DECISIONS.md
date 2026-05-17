# Decisions log

Append-only per CLAUDE.md. New entries on top.

---

## 2026-05-17 — One-click server restart (no more Terminal commands)

**Status:** completed
**Changes:**
- New endpoint `POST /system/restart` — responds 200 OK first, then exits 300 ms later via `SHUTDOWN.set()`. Launchd's KeepAlive=true + ThrottleInterval=10 brings it back automatically in ~3-8 seconds.
- `restartServerAndRescan()` rewritten:
  - Fixed the `\n\n` literal-string bug (was using `\\n\\n` which rendered as escape codes in the alert)
  - Replaces the alert dialog with a full-screen blocking overlay showing "Restarting server… ⏳"
  - POSTs `/system/restart`, then polls `/ping` every 500 ms (with a 20s deadline) until the server is back
  - Live countdown in the overlay: "Waiting for server… (12s left)"
  - On success: overlay flashes "Server restored. Rescanning…" then auto-rescans the original path
  - No Terminal commands, no manual steps

**Why:**
- User screenshot showed an alert with literal `\n\n` text AND asked "is there an easier way?" — both legit complaints. Self-restart via launchd is the right pattern; we already had the infrastructure (KeepAlive=true on the plist) but never wired the trigger.

**Verified:** end-to-end test — POST /system/restart returned `{"ok":true}`; server came back at the 8-second poll mark. Client-side overlay + auto-rescan flow exercised via the TCC help card.

---

## 2026-05-17 — TCC help: reveal-python + drag-and-drop flow

**Status:** completed
**Changes:**
- Symlinked python path can be misleading — added `python_real_path` (os.path.realpath of sys.executable) alongside the symlink in `/system/open-privacy-settings`. On JC's Mac: symlink `/Library/Developer/CommandLineTools/usr/bin/python3` → real `/Library/Developer/CommandLineTools/Library/Frameworks/Python3.framework/Versions/3.9/bin/python3.9`.
- New endpoint `GET /system/reveal-python` runs `open -R <real_path>` to highlight python3 in Finder.
- TCC help card restructured:
  - **Primary path (easy way)**: Show python3 in Finder → Open Privacy Settings → drag python3 from Finder into Full Disk Access list. No typing, no Cmd+Shift+G.
  - **Fallback (collapsed details)**: Cmd+Shift+G manual path entry with BOTH the symlink and resolved real paths (in case TCC needs one or the other), each with a Copy button.
- `open-privacy-settings` now tries 3 URL schemes in sequence (legacy `Privacy_AllFiles`, modern `PrivacySecurity.extension`, generic `-b com.apple.systempreferences`) for cross-macOS-version compatibility.
- Stopped auto-firing Privacy Settings on help-card render — annoying. Now user clicks the button when ready.

**Why:**
- User reported Cmd+Shift+G "doesn't work" and couldn't find the Developer folder in the file picker
- The symlinked path may not be what TCC actually validates against (some macOS versions resolve symlinks)
- Drag-and-drop is the actual idiomatic macOS UX for granting Full Disk Access — typing paths is a power-user fallback

---

## 2026-05-17 — Revert: keep activity logger ON by default (tab still hidden)

**Status:** completed
**Changes:**
- `mhealth-setup` reverted to always install all 3 launchd jobs (watcher + **activity** + server) — activity logger DOES run by default on every install, collecting `~/Library/Logs/mhealth-activity.csv` every 60 s
- Time Spent tab still hidden by default (unchanged from previous decision); revealed only when `MHEALTH_ENABLE_TIME_SPENT=1` is set
- INSTALL.md §5 — new "Data collection (transparent disclosure)" section: explains exactly what's recorded, where, the retention, and how to disable the logger entirely. Lists both log files with their auto-prune (15 days) and explicit `launchctl bootout` / `rm` commands.
- TODO_HIDDEN_FEATURES.md updated to reflect "data collected, UI hidden" model + flagged the optics trade-off explicitly

**Why (user's call):**
- User explicitly asked: keep collecting data on teammate Macs, just hide the tab. Rationale: future-proof so the feature can be enabled per-user later without losing historical data.

**Concern raised in chat + recorded here:** A teammate could find `mhealth-activity.csv` growing and feel surveilled even though the data never leaves their machine. Transparent disclosure in INSTALL.md is the mitigation. Revisit if a teammate ever flags it.

---

## 2026-05-17 — Time Spent disabled by default + per-site minutes + layout reflow

**Status:** completed
**Changes:**

**1. Privacy default: Time Spent OFF in distributed pkg.**
- Even though data is 100% local (server binds to 127.0.0.1; no telemetry/egress), the optics of a boss-distributed tool tracking app/browser/shell usage are bad.
- New env-var gate: `MHEALTH_ENABLE_TIME_SPENT=1`. Default = unset = feature OFF.
- `mhealth-setup` skips `com.mhealth.activity.plist` unless flag set → **activity logger never loaded for teammates → data never collected**.
- Server reads env var at request time and injects `<script>window.__ENABLE_TIME_SPENT__=true|false;</script>` into the served HTML.
- Time Spent tab has `style="display:none"`; small JS reveals it only when flag is true.
- JC's local plist gets `EnvironmentVariables → MHEALTH_ENABLE_TIME_SPENT=1` so JC keeps the feature for personal use.
- New `TODO_HIDDEN_FEATURES.md` documents the deferral + how to re-enable + criteria for flipping default in the future.
- README updated: Time Spent struck through with link to the TODO doc.

**2. Per-site time spent (only visible when feature enabled).**
- New `_browser_time_by_host(activity_rows)` counts activity-log rows per browser host (1 row ≈ 1 minute frontmost when not idle). Idle threshold = 60 s.
- `time_spent_summary()` merges minutes into each `top_sites` entry alongside the existing browser-history visit count.
- UI adds a `Time` column (Host · Browser · Time · Visits). Shows `1h 23m` formatted or `—` if no activity-log data for that host.

**3. Time Spent pane layout reflow.**
- Was: 2-column grid `[App time | Sites + Shell stacked]`.
- Now: 2x2 grid `[App time | Sites] / [Shell | (empty)]`. Shell commands moved to bottom-left as requested.

**Why:**
- User flagged that shipping Time Spent to devs feels surveillance-y even with local-only data
- User asked Top Sites to show time spent per site, not just visit count
- User asked shell commands to move from bottom-right to bottom-left

**Verified:** JC's plist now has the env var; served HTML reports `window.__ENABLE_TIME_SPENT__=true` for JC. Distributed pkg ships with the var unset → tab hidden + activity logger not installed.

---

## 2026-05-17 — Folder drill-down with breadcrumbs (Archive tab)

**Status:** completed
**Changes:**
- New `navigationStack` JS state — array of `{path, resolved, label}` entries; last entry = current location
- Folder rows in scan results are now clickable (blue underline) → `drillIntoFolder(path)` pushes onto stack and re-scans
- Breadcrumb bar above the scan table: `📍 [↑] ~ / Documents / projects / aveo-finance-hub`. Each non-last segment is a clickable link → `navigateToBreadcrumb(i)` truncates stack to that level
- `↑` button (up arrow) pops one level when stack > 1
- Right side of breadcrumb shows the full home-relative path as muted text for context
- New `pathDisplayName` / `pathDisplayFull` helpers normalize `/Users/jc/…` → `~/…`
- `/cloud` endpoint now includes `home` field → page stashes it in `window.__HOME__` so path-prettification works everywhere
- Each row has a tiny `↗` button next to the name → reveals that exact path in Finder (separate from drill-down)
- Fresh scans (from the input box) RESET the stack; drill-downs append. Multi-path scans (comma-separated) hide breadcrumbs entirely.

**Why:**
- User wanted to expand folders inline and "see content inside" without leaving the web UI
- Drilling into project folders from a parent like `~/Documents/projects` reveals per-subfolder size + classification

**UX note:** Breadcrumb segments use the basename for compact display, but the full path always shows on the right of the bar — no ambiguity about where you are.

---

## 2026-05-17 — Cloud Setup: always-visible providers grid + TCC help card

**Status:** completed
**Changes:**

**1. Providers to-do grid (Cloud Setup tab):**
- `PROVIDER_CATALOG` lists 8 well-known free-tier providers: R2, Mega, Drive, Box, Dropbox, OneDrive, pCloud, Storj
- Always-visible card grid; each card shows free-tier size + tagline + blurb
- Configured providers: green border, "✓ CONFIGURED" badge, usage bar with `Used / Free / Total`
- Unconfigured: amber "TO DO" badge, "Set up →" button that expands recipe inline
- Overview row above grid: "Configured: 1 of 8 · Total free capacity: X · Total used: Y"
- New OAuth recipes (Box / Dropbox / OneDrive / pCloud) via shared `oauthRecipe()` helper
- Storj recipe (access-grant based, different from OAuth)

**2. TCC error help card (Archive tab):**
- When scan fails with permission-denied, replace the old text error with a step-by-step orange card
- Auto-opens System Settings → Privacy & Security → Full Disk Access via `x-apple.systempreferences:` URL scheme
- Shows the exact `sys.executable` path with a Copy button (pasted via Cmd+Shift+G in the file picker)
- New endpoint `GET /system/open-privacy-settings` triggers the macOS settings URL + returns python path
- "Restart server & rescan" button shows the exact `launchctl kickstart` command and auto-retries

**Why:**
- User noted Mega-only Cloud Setup hid all other options after first setup — wanted ALL free providers visible as a to-do list so devs see backup options
- User hit TCC blocking ~/Desktop scan and wanted clear remediation steps

**Pending (deferred to next pass):**
- Folder drill-down with breadcrumbs in Archive tab (clicking a folder navigates into it)

---

## 2026-05-17 — Inactive project detection + iOS/Android cache categories

**Status:** completed
**Changes:**
- `classify_folder`: for git-repo subfolders, runs `git log -1 --format=%ct` (3s timeout) and classifies by age:
  - ≥ 180d: 🟢 ARCHIVE with reason "inactive — last commit Nd ago (>6 months). Likely safe to archive."
  - ≥ 90d: 🟢 ARCHIVE "cold — last commit Nd ago (>3 months). Consider archiving."
  - ≥ 30d: 🟡 CHECK "recent — last commit Nd ago. Confirm no untracked work first."
  - < 30d: 🟡 CHECK "active — last commit Nd ago. Probably still in use."
  - git missing/unreadable: CHECK "couldn't read history. Verify before archiving."
- Added 8 new mobile-dev cache categories to DISK_CANDIDATES:
  - `~/.gradle/caches` (Android/Kotlin/Java) — 🟢 SAFE
  - `~/.gradle/wrapper` — 🟢 SAFE
  - `~/Library/Caches/CocoaPods` — 🟢 SAFE
  - `~/Library/Developer/Xcode/iOS DeviceSupport` — 🟡 CAUTION (debug symbols)
  - `~/Library/Developer/Xcode/watchOS DeviceSupport` — 🟡 CAUTION
  - `~/Library/Developer/CoreSimulator/Caches` — 🟢 SAFE
  - `~/.android/build-cache` — 🟢 SAFE
  - `~/.android/cache` — 🟢 SAFE
- Each entry has `what_breaks` and `regen` text so iOS/Android devs see exactly what they're deleting before they click.

**Why:**
- User asked for older/untouched projects to surface as ARCHIVE candidates (not just CHECK like recent repos)
- User flagged that iOS devs have specific pain with Gradle / SDKs / Xcode — now covered

**Verified:** scanning `~/Documents/projects/` correctly tags aveo-finance-hub and mhealth-installer as "active — last commit 0d ago" (CHECK); inactive projects (when present) will tag as ARCHIVE.

**Not added (intentionally):**
- `~/Library/Developer/Xcode/Archives` — deployable artifacts, NOT cache. Never auto-suggest deletion.
- `~/Library/Android/sdk` — actively-used SDK, NOT cache.
- `~/Library/Developer/CoreSimulator/Devices` — user simulator state (installed apps, data). Don't bulk-delete; use `xcrun simctl delete unavailable` instead. May add as a separate special-case button later.

---

## 2026-05-17 — Caches table: status text + filter chips + per-item progress

**Status:** completed
**Changes:**
- Caches table now has an explicit `<colgroup>` with widths — risk badge text ("🟢 SAFE" / "🟡 CAUTION" / "🔴 DANGER") is no longer clipped to icon-only
- Filter chips above the table: All / 🟢 Safe / 🟡 Caution / 🔴 Danger. Active chip highlighted with accent color
- Filter counter: "X of Y shown · 🟢 N · 🟡 N · 🔴 N"
- `cleanOne`/`cleanSelectedDisk` switched from index-based to path-based lookups (filtering broke index assumptions)
- `doCleanRequest` now sends one HTTP request per item instead of batching → shows real progress: "Cleaning 3/8: …" with a progress bar that fills as items complete

**Why:**
- User flagged that the icon-only status badge wasn't readable
- User asked for filter by status + visible progress during cleanup

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
