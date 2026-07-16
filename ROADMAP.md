# ROADMAP

Open work. The active stream is the root-cause refactor below; feature extensions are deferred behind it.

Recent history that informs the items below:
- 2026-07: **full-project audit** (all QML + all 5 C++ plugins, architecture, config contract, MD3, security). ~120 verified findings distilled into the phased refactor plan below. Former Tier 1–3 quick-fix lists were folded into the phases.
- `feat(config): unify per-feature enabled flags into modules on/off map` — every top-level UI element is now toggled via `modules.*`
- `fix(calendar): adopt libical 4.0 refcounted rrule; fix all-day overlap`
- MD3 overhaul (`md3-overhaul` branch): elevation, pixelSize typography, pill buttons, MaterialSwitch/MaterialText adoption, greeter UI kit unified via `sync-ui.sh`
- Notifications subsystem split into 4 focused singletons; wallpaper subsystem with pluggable provider model + Wallhaven
- Decision: **config-first, no GUI** — settings only via `config.json` + IPC (see `AGENTS.md` §0/§10)

---

## Done — root-cause refactor F0–F9 (2026-07)

All ten phases executed on branch `dock-overhaul` (one commit per phase, F0–F9).
Highlights: mechanically-checked invariants (`tools/check.sh` ratchet +
`tools/lint.sh` qmllint wrapper); layer graph now matches AGENTS §3 exactly;
`GlobalStates.activePanel` state machine; popouts coordinated as data;
startup readiness gates (state.json can no longer be clobbered); motion
tokens normalized (~45 broken/raw easing sites) + `MotionAnimation`
primitive; notifications lifecycle declarative; EventDialog on Material
inputs (inputMask 'until' bug root-fixed); network/bluetooth event-driven
(no polling, no auto-pair agent); OSD rewritten per-screen on `OsdSurface`;
calendar plugin addresses events by (uid, recurrenceId) with regression
tests (25 passing); Qalculate async; config contract honest (dead keys
removed, honored keys implemented, defaults reconciled); IPC reference
single-sourced (`IpcReferenceData.qml`).

**Reinstall plugins after pulling this branch:**
`cd src/plugins && cmake --build build && sudo cmake --install build`

### Follow-ups (small, non-blocking)
- Adopt `ScrollableList` where stock `ScrollView`/`ScrollBar` remain
  (cheatsheet tabs, CalendarTab, LauncherContent, NotificationCenter).
- Remaining raw `Rectangle`/`Text` in features (screenshot overlay chrome,
  cheatsheet keycaps → `Chip`, DeviceSelectionDialog radio →
  `MaterialRadioButton`, hand-rolled progress bars → `ProgressIndicator`).
- Native BlueZ / NetworkManager D-Bus endgame (replaces `nmcli monitor`).
- Notification inline reply / action icons (see Notifications — deferred).
- qmllint ratchet burn-down (≈258 warnings, mostly upstream qmltypes gaps
  and pre-existing unqualified access in feature files).

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

### Per-monitor query overrides for Wallhaven
In Stage D a source has one `query`, and every monitor shares it. Either spawn multiple Wallhaven sources or add `monitors[].sourceQueryOverride`. Worked around today by using multiple sources.

---

## Notifications — deferred

### Tests (Qt Test framework)
Mirror the calendar tests. Logic-only singletons are testable:
- `NotificationRateLimiter` — token-bucket math, queue behavior
- `NotificationHistory` — TTL pruning, grouping, persistence roundtrip

### `services.notifications.dnd.suppressOnFullscreen` config
Currently hardcoded `true` in `NotificationDND.qml`. AppConfig reader + schema entry + `?? true` read (~15 lines).

### Inline reply support
Quickshell supports `notification.sendInlineReply(text)`. Requires a text input in the popup; useful for clients that declare `inlineReplyPlaceholder`.

### Action icons
`actionIconsSupported` is not advertised and the UI doesn't show per-action icons. Advertising it means clients will send `iconName` per action and expect rendering.

---

## Calendar — deferred UI polish
- Localized weekday names (`Qt.locale().dayName(i, Locale.ShortFormat)`)
- "Today" button in the header
- Multi-day events in the timeline view
- Drag-to-reschedule in the day timeline
- Event search

---

## Out of scope
- **Full subprocess→DBus migration** — F5 gets the event-driven win; native BlueZ/NM D-Bus remains a later, separate project
- **Cross-shell pattern sharing / public packaging**
- **CI / unit tests for everything** — selectively for mission-critical components only
