# mhealth — Install & Setup

Mac monitoring + activity + disk + cloud-archive dashboard.
Single-machine local web UI at `http://127.0.0.1:8765/`.

---

## 1. Install the .pkg

1. Download `mhealth-installer.pkg` (ask JC for the latest link).
2. **Right-click → Open** in Finder. Don't double-click — the pkg is unsigned, so Gatekeeper blocks double-click but allows the right-click route.
3. Click **Open** in the Gatekeeper prompt → enter your admin password → install.
4. After install, the dashboard auto-launches at `http://127.0.0.1:8765/`.

**To uninstall later:**
```bash
mhealth-uninstall
```

---

## 2. Grant macOS permissions (one-time per machine)

mhealth needs a few permissions to collect data. Without them it still works, but some columns are blank.

Open **System Settings → Privacy & Security** and add `/usr/bin/python3` to:

| Permission              | What it enables                                          |
|-------------------------|----------------------------------------------------------|
| **Full Disk Access**    | Folder scans under Documents/Desktop/Downloads (one grant covers everything) |
| **Screen Recording**    | Window titles in the activity log                        |
| **Automation → Chrome** | Browser tab listing in the Browser Tabs tab              |
| **Automation → Brave**  | Same, for Brave users                                    |
| **Accessibility**       | Frontmost-window detection                               |

If "Full Disk Access" feels too broad, you can grant just **Files and Folders → Documents / Desktop / Downloads** instead — narrower but you'll need each folder separately.

After granting, restart the server:
```bash
launchctl kickstart -k "gui/$(id -u)/com.mhealth.server"
```

---

## 3. (Optional) Set up Cloud Archive

Cloud Archive sends cold/inactive project files to cloud storage (Google Drive, Mega, Dropbox, OneDrive, Box, S3, R2, Zoho, …) so you can free up disk without losing data. Restore with one click.

It uses `rclone` under the hood — a single tool that bridges 30+ cloud providers.

### a. Install rclone

```bash
brew install rclone
```

(Don't have Homebrew? Install it first: <https://brew.sh>)

### b. Pick a provider and configure it

mhealth supports any provider rclone supports (30+). Below are recipes for the three most useful — pick **one** based on your priorities, then run `rclone config`.

| Provider | Free tier | Setup time | Best for |
|----------|-----------|------------|----------|
| **Cloudflare R2** | 10 GB | ~10 min | Heavy archive users — **zero egress fees, free restores** at any size |
| **Google Drive** | 15 GB | ~3 min | Casual users — fastest setup, just an OAuth click |
| **Mega** | 20 GB | ~3 min | Max free space — but slower (encryption-first) |

You can add multiple remotes (e.g. Drive AND R2) by re-running `rclone config`.

---

#### Recipe: Cloudflare R2 (recommended for heavy use)

R2 is the technical sweet spot for an archive use case — zero egress means restores cost nothing no matter how big. After the 10 GB free tier, storage is $0.015/GB/month (e.g. 100 GB = $1.50/mo, billed to your own Cloudflare account).

**One-time setup:**
1. Sign up free at <https://dash.cloudflare.com/sign-up> (skip if you already have a Cloudflare account)
2. Dashboard → **R2 Object Storage** → **Create bucket**. Name it `mhealth-archive`. Location: leave automatic. Click Create.
3. Still in R2 → **Manage R2 API Tokens** → **Create API Token**. Settings:
   - Token name: `mhealth-archive-token`
   - Permissions: **Object Read & Write**
   - Specify bucket: **Apply to specific buckets only** → `mhealth-archive`
   - TTL: Forever (or set whatever you want)
   - Click **Create API Token**
4. **Copy three values** that appear (you only see them once):
   - Access Key ID
   - Secret Access Key
   - The **Account ID** (find it on the R2 page sidebar — looks like `a1b2c3d4e5f6...`)

**Configure rclone:**
```
rclone config

n/s/q>  n
name>   r2
Storage> 4                  ← 4 is Amazon S3 (which Cloudflare R2 is compatible with)
provider> Cloudflare        ← scroll to find it, type the name
env_auth> 1                 ← 1 = "Enter AWS credentials in the next step"
access_key_id> <paste yours>
secret_access_key> <paste yours>
region>                     ← press Enter (leave blank)
endpoint> https://<account-id>.r2.cloudflarestorage.com
location_constraint>        ← press Enter
acl> 1                      ← 1 = private
Edit advanced config? n
Keep this "r2" remote? y
n/s/q> q
```

---

#### Recipe: Google Drive (easiest setup)

Drive is the fastest to set up because OAuth handles auth in a browser click. The free tier is 15 GB; after that you pay Google's storage tier prices.

**Configure rclone:**
```
rclone config

n/s/q>  n
name>   gdrive
Storage> 24                       ← 24 is Google Drive
client_id>                        ← press Enter (use rclone's default app)
client_secret>                    ← press Enter
scope> 1                          ← 1 = Full access
service_account_file>             ← press Enter
Edit advanced config? n
Use auto config? y                ← browser opens → sign in → grant access → "Success!"
Configure as Shared Drive? n      ← unless you actually want a Workspace shared drive
Keep this "gdrive" remote? y
n/s/q> q
```

That's it — no token-pasting, no bucket creation. The OAuth flow handles everything.

---

#### Recipe: Mega (max free space)

Mega gives 20 GB free per account. Encryption-first design means uploads/downloads are slower than R2 or Drive, but the free quota is the biggest.

Sign up free at <https://mega.io> first if you don't have an account. **You don't need the MEGA desktop app** — close/skip its setup wizard if it pops up. rclone talks to Mega's API directly.

**Configure rclone:**
```
rclone config

n/s/q>  n
name>   mega
Storage> 39                  ← 39 is Mega
user>   your-email@example.com
y/g/n>  y                    ← yes, type the password now
password: ********           ← Mega account password
Confirm password: ********
Edit advanced config? n
Keep this "mega" remote? y
n/s/q> q
```

The password is stored encrypted in `~/.config/rclone/rclone.conf`.

### c. Use it from the dashboard

Open `http://127.0.0.1:8765/` → **Cloud Archive** tab → click **Re-check**. Your remotes should show with free/used/total bytes (where the backend supports it — Mega's free tier doesn't report quota).

Then:
1. Type a folder path in **Scan folder** (start with something small like `~/bin`)
2. Click **Scan** — items get classified into 🗑 Delete / ☁️ Archive / ⚠️ Check / 🔒 Keep
3. Select rows + use the bulk action buttons

---

## 4. What each tab does

| Tab            | Purpose                                                              |
|----------------|----------------------------------------------------------------------|
| Browser Tabs   | Open Chrome/Brave tabs with duplicate detection + Save & Close       |
| Processes      | Process list with safe kill (critical processes protected)           |
| Read Later     | Tabs you've saved for later                                          |
| Disk Cleanup   | System cache scan (npm, Docker, Homebrew, Trash, etc.) — quick clean |
| Time Spent     | Activity-log-based app + browser + shell usage analysis              |
| Projects       | Tracker for projects you're building (state, path, pending tasks)    |
| Cloud Archive  | Folder classifier + cloud upload/restore for cold project assets     |

---

## 5. Troubleshooting

**"refused to connect" at 8765**
The launchd service may not be loaded. Re-load it:
```bash
launchctl bootstrap "gui/$(id -u)" ~/Library/LaunchAgents/com.mhealth.server.plist
```

**Scan returns "permission denied" with TCC hint**
See **Section 2** — grant Full Disk Access (or Files and Folders) to `/usr/bin/python3`, then restart the server with `launchctl kickstart`.

**Cloud Archive shows "rclone not installed" after `brew install rclone`**
Refresh the page. If still wrong: confirm `which rclone` returns `/opt/homebrew/bin/rclone` (Apple Silicon) or `/usr/local/bin/rclone` (Intel). Those are the paths mhealth checks.

**Cloud Archive shows "No remotes configured"**
Run `rclone config` and add at least one remote (see Section 3b). Click Re-check.

**Big archive uploads appear to hang**
The browser request blocks until upload completes. A 5 GB upload to Mega can take 30+ min. The upload still runs to completion server-side — just don't close the browser tab. For very large folders, run `rclone copy` directly in Terminal instead.

**`launchctl bootout` / `bootstrap` errors**
Try the older form: `launchctl unload` / `launchctl load`. macOS 12+ should accept either.

---

## 6. Where everything lives

- Scripts: `/usr/local/mhealth/bin/`
- CLI symlinks: `/usr/local/bin/{mhealth,mhealth-kill,mhealth-activity,mac-health-watcher,mhealth-setup,mhealth-uninstall}`
- LaunchAgents (per-user): `~/Library/LaunchAgents/com.mhealth.{watcher,activity,server}.plist`
- Logs: `~/Library/Logs/mac-health-watcher.log` (5-min health), `mhealth-activity.csv` (1-min activity)
- Storage: `~/Library/Application Support/mac-health-watcher/`
  - `read-later.json`
  - `projects.json`
  - `archives.json`

All user data is local. The only network egress is rclone uploads to whichever remotes *you* configure.

---

## 7. Questions / problems

Ping JC. Common sticking points are Gatekeeper (use right-click → Open), TCC permissions (grant Full Disk Access to python3), and the rclone OAuth dance (auto-config opens a browser — if that fails, pick "n" at "Use auto config?" and follow the manual URL flow).
