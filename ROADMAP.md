# ROADMAP

Open work, grouped by area and tier (severity × frequency × ROI).

Recent history that informs the items below:
- `feat(config): unify per-feature enabled flags into modules on/off map` — every top-level UI element is now toggled via `modules.*`
- `fix(calendar): adopt libical 4.0 refcounted rrule; fix all-day overlap` — calendar plugin migrated to libical's new refcounted recurrence API
- `chore: remove feed feature entirely` — feed module dropped
- MD3 overhaul (`md3-overhaul` branch): elevation, pixelSize typography, pill buttons, MaterialSwitch/MaterialText adoption, greeter UI kit unified via `sync-ui.sh`
- `feat(calendar): replace khal CLI with libical C++ plugin` — calendar fully native
- Notifications subsystem split into 4 focused singletons with declarative lifecycle
- Wallpaper subsystem with pluggable provider model + Wallhaven (full `/search` API)
- `docs/`: added `AGENTS.md` + `CLAUDE.md` (conventions, hard rules, project vectors); removed the frozen `docs/` archive and stale root-level working notes
- Decision: **config-first, no GUI** — settings only via `config.json` + IPC; GUI settings are a non-goal (see `AGENTS.md` §0/§10)

---

## Tier 1 — security / hygiene quick fixes (~30 min total)

Small, low-risk, single-file edits.

### `ScreenshotService.qml` — template injection
Lines `19, 28`:
```qml
command: ["sh", "-c", `sleep 0.2 && grim -g "${root._grimGeometry}" - | wl-copy`]
```
`_grimGeometry` comes from `ScreenshotOverlay` (internal source, exploitation unlikely), but `bash -c` with a template literal is bad form. Replace with an argv chain across two `Process`es (grim + pipe → wl-copy/swappy).

### `ClipboardService.qml:208` — shell concatenation
```qml
thumbDecodeProc.command = ["sh", "-c", "mkdir -p '" + root._thumbnailDir + "' && " + root.cliphistBinary + " decode > '" + thumbDecodeProc._outPath + "'"]
```
`item.id` from cliphist is numeric, exploitation unlikely, but the pattern mirrors the calendar `deleteEvent` bug (already fixed). Replace with `QDir().mkpath(...)` for the directory + a `Process` with argv for cliphist and stdin/stdout redirection.

### `EthernetService.qml:77` — defense-in-depth
```qml
speedProc.command = ["cat", "/sys/class/net/" + root.interfaceName + "/speed"]
```
`interfaceName` from nmcli is realistically safe. Add a `^[a-zA-Z0-9_-]+$` regex guard for hygiene.

### `GlobalStates.qml:140` — DBus parse precision
```qml
data.includes("Lock")
```
Also matches "UnLock". Replace with `data.includes(".Lock ")` or a regex anchor.

---

## Tier 2 — subprocess → DBus (3–4 hours)

### `BluetoothService.qml:20` — bluetoothctl infinite loop
```qml
command: ["sh", "-c", "{ echo 'agent KeyboardDisplay'; ... while true; do sleep 0.5; echo 'yes'; done; } | bluetoothctl"]
```
- Infinite loop with no exit handler
- If bluetoothctl dies, the process hangs waiting for I/O
- 2-second polling for device list

**Correct path**: native D-Bus via `Quickshell.Io.DBus` against `org.bluez`. The pattern already lives in `MprisController.qml`; reuse as the template for future subprocess→DBus migrations. The subsystem is the cleanest candidate for swapping subprocess for a native API.

---

## Tier 3 — dead code cleanup

### `controlPanel` IPC + GlobalShortcut + state are dead
- `GlobalStates.controlPanelOpen` is set/toggled in 9 places
- `IpcHandler.toggleControlPanel/openControlPanel/closeControlPanel` exposed
- `GlobalShortcut "controlPanelToggle"` registered
- `clickAction: "control-panel"` accepted
- The cheatsheet content still lists `openControlPanelLeft` / `closeControlPanelLeft`

**Nothing renders against any of it.** Either delete the entire surface or actually implement the control panel feature. Currently misleading in cheatsheet, README (already removed in latest revision) and any user binding.

---

## Wallpaper — deferred extensions

### Stage E — wallpaper picker UI (~3–5 hours)
Bottom-panel browser of source items with thumbnails. Architecturally straightforward — `WallpaperSourceRegistry.getSource(id).items` already supplies everything. UI:
- Bottom panel (cheatsheet-style layer)
- Tabs per source id
- Grid of thumbnail `Image` with lazy loading
- Click thumbnail → `WallpaperManager.setMonitorSource + setItem`
- Per-source actions: refresh, loadMore; for Wallhaven — a search bar with `onAccepted → query`

### Wallhaven — endpoints beyond `/search`
- **`/w/{id}`** — single-wallpaper details (used when the user pinned a specific wallpaper id)
- **`/tag/{id}`** — tag info
- **`/collections/{username}/{id}`** — collection contents (important: "use my Wallhaven collection as a source")
- Setup: either a new `wallhaven-collection` source type, or optional `collectionId + username` on the existing one

### Other remote sources
Following the Wallhaven pattern (~250 LOC each):
- **Unsplash** — `/photos/random` or `/search/photos`, needs an Access Key (env var)
- **Reddit** — `/r/wallpapers/.json`, no auth, easiest
- **Bing wallpaper** — `/HPImageArchive.aspx`, no auth

### Wallpaper migration helper
Programmatic converter from the old config (`wallpaper.global.directory + monitors[].directory`) to the new (`sources[] + monitors[].sourceId`). The Stage B decision was "user fixes it by hand". Could matter for other users if this ever becomes a public project.

### Per-monitor query overrides for Wallhaven
In Stage D a source has one `query`, and every monitor shares it. To give each monitor its own query/categories — either spawn multiple Wallhaven sources or add `monitors[].sourceQueryOverride`. Worked around today by using multiple sources.

---

## Notifications — deferred

### Tests (Qt Test framework)
Mirror the calendar tests (`src/plugins/src/calendar-qml/test/`). Logic-only singletons are testable:
- `NotificationRateLimiter` — token-bucket math, queue behavior
- `NotificationHistory` — TTL pruning, grouping, persistence roundtrip

UI popup tests are hard (require a scene) — out of scope.

### `services.notifications.dnd.suppressOnFullscreen` config
Currently hardcoded `true` in `NotificationDND.qml`. If it needs to be toggleable, add:
- AppConfig reader
- Schema entry
- Read in NotificationDND with `?? true`

~15 lines of work.

### Inline reply support
Quickshell supports `notification.sendInlineReply(text)`. Requires a UI text input in the popup. Useful for notifications that declare `inlineReplyPlaceholder` (Slack, Discord, Telegram, etc.).

### Action icons
The `actionIconsSupported` capability is currently not advertised and the UI does not show icons on actions. If we advertise it, clients will start sending `iconName` per action and expect an icon next to the text.

### Persistent notifications via `keepOnReload: true`
Today: `keepOnReload: false` + a JSON file for history. Alternative: Quickshell-managed retention. Not obvious which is better; the current setup works.

---

## Calendar — deferred

### Stage E UI polish (low priority)
Suggestions from the audit that did not make it into the refactor:
- Localized weekday names (`Qt.locale().dayName(i, Locale.ShortFormat)`)
- "Today" button in the header
- Multi-day events in the timeline view (currently filtered by `!ev.allDay && ev.start === selectedDate.date`)
- Drag-to-reschedule in the day timeline
- Confirm-on-close in `EventDialog` for unsaved changes (exists; could be broader)
- Event search

All QML-only, nothing blocks.

---

## Out of scope

- **Wholesale replacement of subprocess-based services with DBus/native** — large project; tackled one at a time (`BluetoothService` first)
- **Cross-shell pattern sharing** — patterns from these refactors (BaseProvider, NotifData wrapper, source registry) could be extracted as reusable building blocks if this ever forks / ships as a public project
- **CI / unit tests for everything** — selectively for mission-critical components; not everywhere
