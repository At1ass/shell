# Dock Overhaul — Design & Implementation Plan

Scope: **maximum** (functional gaps + visual polish + advanced UX) with **component
decomposition** of the current 575-line monolith `src/features/dock/Dock.qml`.

This plan is grounded in three verified sources: the current code, the Quickshell 0.3.0 API,
and Material Design 3 guidelines. Citations inline.

---

## 0. Implementation status (delivered)

Done, with these deviations from the original plan:

- **Components**: `DockService` (singleton) + `Dock` (recreating wrapper) → `DockPanel`,
  `DockBar`, `DockIcon`, `DockPreview`, `DockContextMenu`, `DockTooltip`.
- **Identity**: `DesktopEntries.heuristicLookup` + `startupClass` + dotted-id fallback; stable
  QtObject entry pool consumed via `ScriptModel` (delegates reused, no churn).
- **Context menu = app-level only** (New window / Pin-Unpin / Close all). Per-window actions
  (focus, close `×`) live on the **preview** thumbnails instead — no duplication. Menu/preview/
  tooltip render in-window; the input mask is a union of their precise rects; menu dismissal via
  `HyprlandFocusGrab`.
- **Pins persist to `state.json`** (`updateState`), never to config; conflict policy =
  *config edit wins* (baseline snapshot in `dock._configSeed`). Fixed a latent `updateState`
  reactivity bug (it reused the object reference → no change signal).
- **Position**: `bottom | top | left | right` via `dock.position`; the window is **recreated**
  on change (a layer surface doesn't reliably reconfigure anchors/size live). Preview/menu/
  tooltip and indicators are orientation-aware; preview scrolls (Flickable) and is clamped to
  the screen so it never overflows.
- **MD3**: `Surface` elevation (bar 2 / preview & menu 3), emphasized motion, in-window tooltip.
- **Phase 5 delivered**: MD3 tooltip, launch bounce (all launch sources via
  `DockService.appLaunched`), urgency pulse (`HyprlandToplevel.urgent`), drag-to-reorder pinned.
- **Not done** (out of chosen scope / infeasible cleanly): magnification, keyboard navigation,
  icon enter/move transitions (GridLayout has no move transitions).

---

## 1. Context & rationale

Current `Dock.qml` does the hard Wayland parts well (input mask, anti-feedback-loop reveal,
scale/opacity animation, live `ScreencopyView` previews) but has correctness gaps and misses
MD3 polish:

- **App-identity matching is broken** across three namespaces (Hyprland `class`, Wayland
  `appId`, DesktopEntry `id`) → duplicate icons, empty previews, missing icons.
- No right-click context menu; `contextMenuOpen` (`Dock.qml:28`) is dead.
- No runtime pin/unpin (config supports it; UI doesn't).
- Raw `Rectangle`s with no elevation/shadow → flat against wallpaper (violates MD3 + project
  design direction).
- Hardcoded easings instead of MD3 emphasized motion; Qt.Controls tooltip instead of MD3.

### Key API facts (Quickshell v0.3.0, verified)

- `DesktopEntries.heuristicLookup(name)` — fuzzy class→entry lookup; **already the canonical
  pattern** in repo (`IconCategoryResolver.qml:73`, `AudioService.qml:138`).
- `DesktopEntry.startupClass` — *"Initial class or app id the app intends to use. May be useful
  for matching running apps to desktop entries."* **This is the linchpin** for identity matching
  (an earlier analysis wrongly claimed it didn't exist).
- `Toplevel.activate()` / `close()` / `setRectangle(window, rect)` — focus, close, minimize-hint.
- `PopupWindow { anchor.window; anchor.rect; grabFocus }` — anchored popup with click-outside
  dismiss; `HyprlandFocusGrab` for advanced dismiss (pattern in `TooltipManager.qml`).
- `Hyprland.dispatch(req)` — already used for `focuswindow`.

### Key MD3 facts

- Elevation levels: 0,1,3,6,8,12 dp. **Menus = level 2; floating/dialog = level 3.** Prefer
  tonal elevation; **use shadow for elements needing focus / to avoid blending** — a floating
  dock over wallpaper qualifies. ([m3 elevation](https://m3.material.io/styles/elevation/overview))
- Menus: container at level 2, ~48dp items, width ~112–280dp, leading icon + label, dividers for
  sections, disabled = reduced opacity. ([m3 menus](https://m3.material.io/components/menus/specs))
- `MaterialMenu.qml` already matches this (48px items, width 220, `{label,icon,enabled,separator}`,
  StateLayer) — only nit: it sets `elevation:3`; MD3 menu = level 2.

---

## 2. Target architecture (decomposition)

Identity/model logic is **global** (derived from global config + global Hyprland state, identical
across monitors), so it becomes a singleton service. Presentation stays per-screen in
`features/dock/`. This matches the project's "services extracted from god objects" convention.

```
src/core/services/
  DockService.qml          (NEW, Singleton) — model + pin/unpin actions + identity matching
  qmldir                    (+ DockService)

src/features/dock/
  Dock.qml                 (SLIM) — PanelWindow: window cfg, input mask, reveal state machine,
                                     local TooltipManager; hosts DockBar + DockPreview + DockContextMenu
  DockBar.qml              (NEW) — Surface(elevation 2) + RowLayout of DockIcon; add/remove
                                     transitions; magnification driver
  DockIcon.qml             (NEW) — one app: icon, running badge/dots, hover/magnify scale,
                                     StateLayer, mouse (L/M/R), urgency, drag handle, tooltip
  DockPreview.qml          (NEW) — Surface(elevation 3) + ScreencopyView thumbnails
  DockContextMenu.qml      (NEW) — PopupWindow + MaterialMenu + HyprlandFocusGrab
  qmldir                    (+ new components)
```

`Dock.qml` renders `DockService.model`; all monitors share one computed model.

---

## 3. The core fix — unified app identity (`DockService`)

Replace the inline `findDesktopEntry` + ad-hoc class keying with one normalization layer.

```
// pure helpers
normalize(s)        -> (s||"").toLowerCase().replace(/\.desktop$/, "").trim()
entryForClass(cls)  -> DesktopEntries.heuristicLookup(cls)          // may be null
keyForEntry(entry)  -> normalize(entry.startupClass || entry.id)

// running windows: group by a STABLE key derived from the entry, not the raw class
for each Hyprland toplevel tl:
    cls   = tl.lastIpcObject?.class ?? ""
    entry = entryForClass(cls)
    key   = entry ? keyForEntry(entry) : normalize(cls)
    groups[key].push({ tl, entry, cls })

// model: pinned first (pinned ids resolved THROUGH heuristicLookup), then running-only
for each pinnedId in dock.pinnedApps:
    entry = DesktopEntries.heuristicLookup(pinnedId)
    key   = entry ? keyForEntry(entry) : normalize(pinnedId)
    item  = { key, appId: pinnedId, entry, windows: groups[key]?.map(g=>g.tl) ?? [], pinned: true }
for each remaining group key not already emitted:
    item  = { key, appId: group.cls, entry: group.entry, windows, pinned: false }

// preview window matching (DockPreview): match BOTH ways
toplevelsFor(item) = ToplevelManager.toplevels.values.filter(t =>
     normalize(t.appId) === item.key || normalize(t.appId) === normalize(item.cls))
```

This eliminates duplicate icons (pin and running collapse to the same `key`) and empty previews
(appId matched via the entry key + class fallback).

**Pin/unpin actions** (persist via existing `AppConfig.updateConfig`, `AppConfig.qml:228`, which
replaces the whole `dock` section safely and round-trips other keys):

```
function pin(appId):   write dock.pinnedApps = [...current, appId]
function unpin(appId): write dock.pinnedApps = current.filter(x => x !== appId)
function reorder(from,to): splice pinnedApps, persist   // for drag-to-reorder
```

---

## 4. Feature work (maximum scope)

### Phase 1 — Correctness (no visual change)
1. `DockService` singleton with the identity model + pin/unpin/reorder. `Dock.qml`/`DockBar`
   consume `DockService.model`.
2. Remove dead `contextMenuOpen`.

### Phase 2 — Context menu + runtime pin/unpin
3. `DockContextMenu.qml`: `PopupWindow { anchor.window: dock; anchor.rect: <icon rect> }` hosting
   `MaterialMenu`, dismissed via `HyprlandFocusGrab` (mirror `TooltipManager.qml`). Model built
   per app:
   - `Pin to dock` / `Unpin` (toggles `DockService.pin/unpin`)
   - `New window` (`entry.execute()`) — makes the middle-click action discoverable
   - separator
   - per-window entries → `Toplevel.activate()`
   - `Close window` / `Close all` → `Toplevel.close()`
4. Wire `Qt.RightButton` in `DockIcon` mouse handler to open the menu.

### Phase 3 — MD3 visual polish
5. `DockBar` background → `Surface { elevation: 2 }`, `DockPreview` → `Surface { elevation: 3 }`.
   Keep translucency: verify Surface tonal color composites with the existing
   `Qt.alpha(surfaceContainer, 0.9)` look (may pass a custom `color` to Surface).
6. Motion → `Tokens.motion.easing.emphasized` family for dock reveal, preview, menu in/out.
7. MD3 tooltip: instantiate a **dock-local** `TooltipManager` inside `Dock.qml` (the dock is a
   per-screen PanelWindow like the bar) and use `TooltipItem` instead of `QtQuick.Controls.ToolTip`.
   *Verify* TooltipManager anchors to an arbitrary PanelWindow, not hard-wired to the bar.
8. Launch feedback: short bounce on `DockIcon` when a pinned app is clicked and not yet running
   (emphasized easing), cleared when its window appears.
9. Icon add/remove transitions in `DockBar`'s layout (populate/add/displaced) so windows
   open/close smoothly instead of popping.

### Phase 4 — Advanced UX
10. **Magnification** (opt-in `dock.magnification`): each `DockIcon` scales by cursor distance to
    the hovered icon center along the row (macOS-style falloff). Driven from `DockBar`.
11. **Urgency/attention**: highlight icon when a window demands attention. *Verify* how Hyprland
    exposes urgency (likely `lastIpcObject` flag or a Hyprland event) — known-unknown; degrade
    gracefully if unavailable.
12. **Drag-to-reorder** pinned icons: `DragHandler` on `DockIcon` (pinned only), reorder via
    `DockService.reorder`, persist.
13. **Keyboard navigation** (opt-in): requires keyboard focus on a layer-shell — gated behind a
    focus grab while the dock is revealed. *Risk:* heaviest item; may be deferred if it fights the
    auto-hide/mask model. Scoped last.

### Phase 5 — Config + docs
14. Schema (`config/config.schema.json`) + `default.json` + `AppConfig` accessors for new keys:
    `magnification` (bool), and any tunables (e.g. `magnificationScale`). Keep under the existing
    `dock` section (no `enabled` — that lives in the `modules` map now).
15. Update `docs/` / per-feature notes; document context-menu actions and new config keys.

---

## 5. Risks / known-unknowns (verify during implementation)

- **TooltipManager reuse**: confirm it can anchor to the dock window (not bar-specific). If
  coupled, either parameterize it or keep a trimmed dock tooltip.
- **Surface + translucency**: `Surface` tonal elevation color may not equal the current
  `alpha(surfaceContainer, 0.9)`. Pass explicit `color` + ensure `MultiEffect` shadow doesn't clip
  inside the PanelWindow (the existing scale/opacity-not-translate constraint still applies).
- **Hyprland urgency**: exposure unverified — implement defensively.
- **Keyboard nav vs layer-shell/auto-hide**: focus grab interaction with the input mask is
  non-trivial; defer if it destabilizes reveal.
- **Magnification perf**: many simultaneous scale bindings + a live `ScreencopyView` — profile;
  disable magnify while a preview is open if needed.
- **`heuristicLookup` correctness**: it "may guess incorrectly" per docs — validate against the
  user's real pinned apps (Telegram, vesktop, firefox, bottles, steam, AmneziaVPN) which span
  tricky cases (Steam games, Electron apps).

## 6. Verification

- Run `qs` and confirm: no duplicate icons for pinned+running apps; previews populate for all
  pinned apps incl. Steam/Electron; right-click menu opens anchored, dismisses on click-outside;
  pin/unpin round-trips to `~/.config/quickshell/config.json` and survives reload; shadows render;
  motion uses emphasized curves; magnification toggles via config hot-reload.
- `qmllint` clean on all new/changed QML.
- Multi-monitor: model identical across screens; menu/preview anchor to the correct screen.
```
