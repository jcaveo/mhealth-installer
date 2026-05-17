# Hidden / deferred features

Features that exist in the codebase but are disabled by default in distributed installs. Listed here so future maintainers (and reviewers) know what's dormant and why.

---

## 🔒 Time Spent — disabled by default

**Status:** code in place, tab hidden, activity logger not loaded.

**What it does** (when enabled): tracks per-app foreground time, top browser hosts with visit count + active minutes, and top zsh commands. Data is **100% local** — written to `~/Library/Logs/mhealth-activity.csv`, never transmitted (server binds to 127.0.0.1 only).

**Why disabled by default:**
- Even though data never leaves the machine, a boss-distributed tool that tracks app/website/shell usage *looks like* surveillance to devs.
- Optics override technical correctness here. Defaulting OFF means we never have to explain why we're tracking and devs never have to wonder.

**How it's hidden:**
1. `mhealth-setup` skips `com.mhealth.activity.plist` unless `MHEALTH_ENABLE_TIME_SPENT=1` is set in its environment → activity logger not loaded → CSV never grows.
2. The "Time Spent" tab in the dashboard has `style="display:none"` and only reveals when the server sees `MHEALTH_ENABLE_TIME_SPENT=1`.

**How to re-enable (per-user, opt-in):**
```bash
MHEALTH_ENABLE_TIME_SPENT=1 mhealth-setup
```
This loads the activity launchd job AND adds the env var to the server's plist so the tab appears in the dashboard.

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
