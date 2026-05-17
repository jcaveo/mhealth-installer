# Hidden / deferred features

Features that exist in the codebase but are disabled by default in distributed installs. Listed here so future maintainers (and reviewers) know what's dormant and why.

---

## 🔒 Time Spent tab — hidden by default (data IS collected)

**Status:** activity logger runs by default on every install (data is collected to `~/Library/Logs/mhealth-activity.csv`). The Time Spent dashboard tab is hidden unless `MHEALTH_ENABLE_TIME_SPENT=1`.

**Why this split:**
- Collecting data preserves the option to enable the feature later for any user without losing historical data
- Hiding the tab keeps the UX clean for teammates who don't need it
- Data is **100% local** — `~/Library/Logs/mhealth-activity.csv`, never transmitted (server binds to 127.0.0.1 only, no telemetry, no egress)
- Disclosed transparently in INSTALL.md §5 ("Data collection") with explicit instructions to disable the logger entirely if a user objects

**How the tab is hidden:**
1. The "Time Spent" tab `<div id="timeSpentTab">` has inline `style="display:none"`
2. Server reads `MHEALTH_ENABLE_TIME_SPENT` env var and injects `<script>window.__ENABLE_TIME_SPENT__=true|false;</script>` before `</head>`
3. Small JS on page load checks the flag and reveals the tab when true

**How to reveal the tab (per-user, opt-in):**
```bash
MHEALTH_ENABLE_TIME_SPENT=1 mhealth-setup
```
This adds the env var to the server's plist; the tab appears on next dashboard load.

**How to stop the data collection entirely** (if a user objects):
```bash
launchctl bootout "gui/$(id -u)" ~/Library/LaunchAgents/com.mhealth.activity.plist
rm ~/Library/LaunchAgents/com.mhealth.activity.plist
rm ~/Library/Logs/mhealth-activity.csv
```
Documented in INSTALL.md §5.

**Concern flagged for future revisit:**
A teammate could discover the growing CSV and feel surveilled even though the data never leaves their machine. The transparent disclosure in INSTALL.md mitigates this somewhat, but a clearer pattern would be: collect only when the tab is enabled. We chose not-quite-that to preserve historical data continuity if/when individual users opt in later. Trade-off accepted; revisit if a teammate raises it.

**Before flipping the default to ON (future revisit):**
- Document the data flow clearly in the welcome dialog
- Make the per-user disable a single click in the dashboard (not just env-var)
- Consider a "what's recorded" inspector that lets a dev see their own data without us promising anything
- Optionally encrypt the CSV at rest with a per-user key

**Code touched:** `payload/usr/local/mhealth/bin/mhealth-kill` (HTML inject + tab hide), `payload/usr/local/mhealth/bin/mhealth-setup` (job selection + env-var propagation).

---

## Pattern for future "hide by default" features

1. Server reads env var → injects `window.__FEATURE_X__=true|false` before `</head>`
2. Tab gets `id="…Tab" style="display:none"`
3. JS reveals it when the flag is true
4. Any underlying data collector (launchd job, hook, scheduler) is skipped in `mhealth-setup` unless the env var is set
5. Document the dormancy in this file
