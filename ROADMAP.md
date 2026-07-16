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

## Active — root-cause refactor (phases F0–F9)

Principle: fix causes, not symptoms. Each phase is one branch/commit series; ordering matters (later phases build on earlier primitives). F7 (C++) can run in parallel any time after F0.

### F0 — make the rules checkable *(small)*
`.qmllint.ini` with import paths (the "qmllint clean" rule is currently unverifiable — 2772 false unqualified warnings without it); fix real core warnings. `tools/check.sh` grep invariants for the AGENTS bans: layer edges (services↛features, ui↛services, config↛services), bare easing literals in features, StackLayout, `sh -c` concatenation, `console.log`, hardcoded `/home/`.
**Done when:** check.sh output is the live progress bar of the refactor — green for held rules, red exactly on known debt.

### F1 — layer graph + dead code *(small)*
Invert Theme↔Wallpaper (Theme gets `seed` property, WallpaperManager pushes into it — removes the config↔services cycle). Move ownership: launcher providers → `core/services/launcher/`; `NotifData` → `core/services/`; `TrayMenu` → `popouts` (its only consumer). Delete dead: `features/GlobalState.qml`, entire control-panel surface (props, shortcut, 3 IPC fns, schema enum, `dashboard-system` alias), `updateConfig()`/save timer/suppress flag, dead GlobalStates props, `maintab_elements/TrayMenu.qml` dup, VolumeWidget dead filters, `mcu-qml/plugin.cpp`, WallpaperCache IPC `test()` probe. Add missing qmldirs (`core/config`, `core/services`, `maintab_elements`).
**Done when:** layer grep invariants green; shell runs; zero orphan files.

### F2 — state & coordination *(medium)*
`GlobalStates.activePanel` state machine (derived readonly booleans keep the API; kills the n² mutual-exclusion handlers). Popouts as data: `PopoutsState.request` descriptor consumed by the Popouts window; instance handle + broken TrayWidget fallback deleted. Readiness gates: `updateState()` queues until `stateReady`; consumers apply persisted state on the signal (WallpaperManager loses the `_stateApplied` heuristic; also fix its source rewire-on-rebuild bug). Dashboard: declarative bindings only (tab index lives in GlobalStates; height binding not hijacked). lock-session: gdbus monitor without alias-path filter (anchored Lock/Unlock parse), restart on exit.
**Done when:** restart restores dock pins/wallpaper/DND; `openDashboardTab` works after manual tab switching; `loginctl lock-session` locks; disabling popouts module doesn't break tray.

### F3 — UI kit foundation + motion *(medium)*
Motion presets in `ui/base` (emphasized/standard with `easing.type` + `*Points` fused, cannot diverge) → sweep the ~25 broken easing sites; bare `easing.*` in features becomes a checked ban. New primitives: `LinearProgress`, `Scrim`, `MonoText` + mono token, `Surface` tint prop (replaces 6 magic-opacity elevation tints). Remove shadowed properties (`enabled` ×10 → built-in, `BarElement.children` → `content`, `TooltipItem.data`, `Wallpaper.smooth`). Explicit wheel API on `BarElement` (root cause of the dead workspace scroll). Re-run greeter `sync-ui.sh`.
**Done when:** qmllint has no property-override warnings; no easing literals in features.

### F4 — root feature fixes + QML performance *(medium)*
Notifications: declarative popup lifecycle — one animation drives progress bar and auto-dismiss with pause (replaces Date.now math + 30 Hz timer); `timestamp` int→real; gate-queue cap; eviction loop; shared now-tick for relative dates; wire history actions. EventDialog reworked on `MaterialTextField` (kills the inputMask "until" validation bug). All 3 StackLayouts → single Loader tab pattern. Perf roots: DockService `class → DesktopEntry` memoization; DockPreview on `ScriptModel`; StatusBar widget model stable across unrelated config reloads; ApplicationProvider corpus cached (rebuild on app-list change, not per keystroke); calculator throttle trailing edge; wallpaper `asynchronous` + `sourceSize`.
**Done when:** hovered popups always dismiss; history shows sane dates; unrelated config edits don't flash the bar; wallpaper change doesn't freeze the shell.

### F5 — network + bluetooth, event-driven *(medium/large)*
One `NetworkService`: native Wi-Fi (fixing the dead `.values` bug inside the rewrite), a single long-lived `nmcli monitor` for eth/VPN instead of 2 processes / 5 s, VPN polling gated by config, password via stdin (`--ask`), `!running` guards, iface-name regex guard. `BluetoothService`: **delete the auto-yes agent daemon** (auto-confirms any pairing — the audit's critical C1), subscribe to `adapter.devices` signals instead of 2 s rebuild polling, pairing = explicit per-action confirmation. (Native BlueZ D-Bus remains the ideal endgame; `nmcli monitor` / signals get 90% of the win now.)
**Done when:** idle `ps` shows no periodic nmcli/bluetoothctl; Wi-Fi panel actually scans/connects; no pairing without confirmation.

### F6 — OSD rewrite *(medium)*
`OsdSurface` shared base: per-screen (`screen: modelData` — multi-monitor OSD is currently broken), token-driven geometry/type/motion, bounded queue, English strings. Volume/Brightness/Toast become thin parameterizations.
**Done when:** OSD appears on the right monitor; zero hardcoded literals in the module; toast storms don't grow memory.

### F7 — C++ plugins *(large, parallel track)*
Calendar — identity model: event address = `(uid, recurrenceId)`, expose `recurrenceId` to QML, delete/edit understand overrides (audit critical C2 — deleting a moved occurrence currently deletes the whole series); floating times not coerced to UTC; `editAllInPlace` preserves authoring TZID and touches only passed fields; `icalrecur_iterator_set_start()`; FSW recursive depth + deferred (not dropped) external changes in the self-write window; `wait(3000)`. Qalculate: async eval on a worker + signal; init off the UI thread. SystemMonitor: sensors truly optional in CMake, CPU-sensor selection by label, deltas by actual elapsed time, baseline reset on iface re-detect, diskstats buffer. Mcu: emit `validChanged`, wait all futures in dtor, `readDownscaled` fallback. All plugins: absolute install paths, single install per target, `-Wall -Wextra`. Calendar unit tests for override scenarios (delete/edit moved occurrence, floating TZ, DST transition).
**Done when:** calendar tests green; heavy launcher expressions don't freeze UI.

### F8 — config contract + single IPC reference *(small/medium)*
Remove dead schema keys (`launcher.providers`/`hiddenApps`, `powerMenu.actions`, `hyprland` section); implement `weather.refreshMinutes`/`enabled` (cheap); unify defaults — `default.json` canonical, getters and schema must match; personal data (weather coords, `.face` path) out of code into config. One data source renders the cheatsheet IPC reference; README IPC section aligned (both currently lie, differently).
**Done when:** every schema key is read by code; three default sources agree; cheatsheet lists exactly the real handlers.

### F9 — final polish *(medium, background)*
MD3 sweep of remaining features (NotificationPopupItem root → Surface, worst raw Rectangle/Text offenders, scrims, icon-size tokens); comments → English (~245 lines), Russian UI strings → English; remaining Low audit findings; full check.sh + qmllint pass; README/ROADMAP refresh.

Deliberately untouched: dock architecture (audit: strongest module — only the two F4 perf items), notifications architecture (only F4 point fixes), greeter (sync-ui.sh verified byte-identical), wallpaper source architecture (only F2 lifecycle fixes).

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
