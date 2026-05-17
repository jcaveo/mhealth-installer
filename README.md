# mhealth

Mac monitoring + activity + cloud archive dashboard, packaged as a one-click `.pkg` installer for internal team distribution.

**Dashboard:** `http://127.0.0.1:8765/` (after install)

## Tabs

| Tab | Purpose |
|-----|---------|
| **Tabs** | Chrome/Brave tab manager with duplicate detection + Save & Close to Read Later |
| **Processes** | Process list with safe kill (critical processes protected) |
| **Read Later** | URLs you saved from the Tabs tab |
| **Caches** | System cache cleanup (npm/Docker/Homebrew/Chrome/etc.) with risk levels |
| **Archive** | Folder scanner + cloud upload/restore via rclone (BYO Drive/Mega/R2/etc.) |
| **Projects** | Tracker for projects built with Claude |
| **Cloud Setup** | Configure rclone remotes (one-time per dev) |
| ~~Time Spent~~ | **Hidden by default** for privacy. See [TODO_HIDDEN_FEATURES.md](TODO_HIDDEN_FEATURES.md) — opt-in via `MHEALTH_ENABLE_TIME_SPENT=1 mhealth-setup` |

Plus a snooze widget in the top-right to silence health-watcher notifications for 15min / 1hr / 2hr / until tomorrow.

## For end users

See [INSTALL.md](INSTALL.md) for full install + permissions + rclone setup walkthrough.

Quick version:
1. Right-click → Open `dist/mhealth-installer.pkg` (it's unsigned; right-click bypasses Gatekeeper)
2. Grant Full Disk Access to `/usr/bin/python3` when prompted
3. Open `http://127.0.0.1:8765/`
4. (Optional) Set up Cloud Archive via the Cloud Setup tab

To uninstall: `mhealth-uninstall` in Terminal.

## For developers (this repo)

### Build the .pkg

```bash
./build.sh                                              # unsigned
DEVELOPER_ID="Developer ID Installer: …" ./build.sh    # signed
```

Output: `dist/mhealth-installer.pkg`.

### Repo layout

```
mhealth-installer/
├── build.sh                   # pkgbuild + productbuild driver
├── distribution.xml           # productbuild config
├── INSTALL.md                 # end-user install walkthrough
├── DECISIONS.md               # session log (per CLAUDE.md rules)
├── README.md                  # this file
├── Resources/                 # welcome.html + conclusion.html (shown in installer)
├── scripts/                   # postinstall (runs as root)
├── payload/                   # files installed by the pkg
│   └── usr/local/mhealth/
│       ├── bin/               # the four tools + setup/uninstall
│       └── templates/         # com.mhealth.*.plist with __HOME__ placeholders
├── build/                     # gitignored — pkgbuild intermediate
└── dist/                      # committed — the .pkg goes here
```

### Source of truth

The dev's running install at `~/bin/mhealth-kill` etc. is a **symlink** into `payload/usr/local/mhealth/bin/`. Edits to the payload are immediately live (after `launchctl kickstart` for the server).

### After every set of edits

```bash
./build.sh                                              # rebuild pkg
launchctl kickstart -k "gui/$(id -u)/com.jc.mhealth-server"  # restart server on dev machine
git add -A && git commit -m "…" && git push             # ship to repo
```
