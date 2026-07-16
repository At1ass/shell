import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.src.core.config

pragma Singleton
pragma ComponentBehavior: Bound

// Dock data model + pin actions, shared across all monitors.
//
// Unifies three app-identity namespaces that the dock must bridge:
//   - Hyprland window `class`        (tl.lastIpcObject.class)         — running windows
//   - Wayland Toplevel `appId`       (ToplevelManager)                — ScreencopyView previews
//   - DesktopEntry `id`/`startupClass`                                — icon, name, launch
// Running windows are grouped by a STABLE key derived from the desktop entry
// (via DesktopEntries.heuristicLookup + startupClass), so a pinned app and its
// running windows collapse into one icon instead of duplicating.
Singleton {
    id: root

    readonly property var toplevels: Hyprland.toplevels ? Hyprland.toplevels.values : []

    // Pinned apps live in runtime state (state.json) — the shell never mutates the user's
    // hand-authored config.json. `config.dock.pinnedApps` stays the declarative source:
    // editing it wins (re-seeds state). Between config edits, UI pin/unpin persists to
    // state. We track the last-applied config list as `dock._configSeed` to detect edits.
    readonly property var pinnedApps: {
        const st = AppConfig.stateData?.dock?.pinnedApps
        return (st !== undefined && st !== null) ? st : (AppConfig.dockPinnedApps || [])
    }

    function _arraysEqual(a, b) {
        if (!a || !b || a.length !== b.length) return false
        for (let i = 0; i < a.length; i++) if (a[i] !== b[i]) return false
        return true
    }

    // Reconcile config → state. Config edits win; UI pins persist between edits.
    function _syncFromConfig() {
        if (!AppConfig.ready || !AppConfig.stateReady) return
        const cfg = (AppConfig.dockPinnedApps || []).slice()
        const dock = AppConfig.stateData?.dock || ({})
        const hasState = dock.pinnedApps !== undefined && dock.pinnedApps !== null
        const seed = dock._configSeed

        if (!hasState) {
            // First run: adopt config as both the live list and the baseline.
            AppConfig.updateState("dock", { pinnedApps: cfg, _configSeed: cfg })
        } else if (seed === undefined) {
            // Upgrade from older state without a baseline: keep existing pins, record baseline.
            AppConfig.updateState("dock", { _configSeed: cfg })
        } else if (!_arraysEqual(cfg, seed)) {
            // Config edited since last sync → config wins.
            AppConfig.updateState("dock", { pinnedApps: cfg, _configSeed: cfg })
        }
    }

    Connections {
        target: AppConfig
        function onReadyChanged() { root._syncFromConfig() }
        function onStateReadyChanged() { root._syncFromConfig() }
        function onDockPinnedAppsChanged() { root._syncFromConfig() }
    }

    function normalize(s) {
        return (s || "").toString().toLowerCase().replace(/\.desktop$/, "").trim()
    }

    // class/pin → DesktopEntry memo. desiredModel re-evaluates on every
    // window IPC event (title changes fire on each browser navigation!), and
    // heuristicLookup plus two linear scans over all desktop entries per
    // toplevel is far too heavy for that. Negative results are cached too.
    property var _entryCache: ({})

    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() { root._entryCache = ({}) }
    }

    // Resolve a desktop entry from a window class, desktop id, or display name.
    // Forgiving on purpose so a user can pin by any of "Telegram", "telegram", or
    // "org.telegram.desktop" and still collapse with the running window (class
    // "org.telegram.desktop"). Strategy, most-specific first:
    //   1. Quickshell's own heuristic (handles real window classes well)
    //   2. exact match on id / name / startupClass (case-insensitive)
    //   3. dotted-id segment match, e.g. "telegram" ∈ "org.telegram.desktop"
    function resolveEntry(s) {
        if (!s) return null
        const n = normalize(s)
        if (!n) return null
        if (_entryCache[n] !== undefined) return _entryCache[n]

        let found = DesktopEntries.heuristicLookup(s)
        if (!found) {
            const apps = DesktopEntries.applications?.values ?? []
            for (let i = 0; i < apps.length && !found; i++) {
                const a = apps[i]
                if (normalize(a.id) === n || normalize(a.name) === n
                    || (a.startupClass && normalize(a.startupClass) === n))
                    found = a
            }
            for (let i = 0; i < apps.length && !found; i++) {
                const segments = normalize(apps[i].id).split(".")
                if (segments.indexOf(n) !== -1) found = apps[i]
            }
        }
        _entryCache[n] = found ?? null
        return found ?? null
    }

    function keyForEntry(entry) {
        return entry ? normalize(entry.startupClass || entry.id) : ""
    }

    // Desired entries as plain dicts. Reconciled into a stable QtObject pool (below) so
    // ScriptModel in DockBar reuses delegates across window events.
    // [{ key, appId, cls, entry, windows: [HyprlandToplevel], pinned }]
    readonly property var desiredModel: {
        const pinned = root.pinnedApps
        const tls = toplevels

        // Group running windows by stable entry-derived key.
        let groups = ({})
        for (let i = 0; i < tls.length; i++) {
            const tl = tls[i]
            const cls = tl.lastIpcObject?.class ?? ""
            if (!cls) continue
            const entry = resolveEntry(cls)
            const key = entry ? keyForEntry(entry) : normalize(cls)
            if (!key) continue
            if (!groups[key])
                groups[key] = { key: key, cls: cls, entry: entry, windows: [] }
            groups[key].windows.push(tl)
        }

        let items = []
        let used = ({})

        // Pinned first, in config order.
        for (let i = 0; i < pinned.length; i++) {
            const pid = pinned[i]
            const entry = resolveEntry(pid)
            const key = entry ? keyForEntry(entry) : normalize(pid)
            const g = groups[key]
            used[key] = true
            items.push({
                key: key,
                appId: pid,
                cls: g ? g.cls : (entry ? (entry.startupClass || entry.id || pid) : pid),
                entry: entry,
                windows: g ? g.windows : [],
                pinned: true
            })
        }

        // Then running-only apps.
        for (const key in groups) {
            if (used[key]) continue
            const g = groups[key]
            items.push({
                key: key,
                appId: g.cls,
                cls: g.cls,
                entry: g.entry,
                windows: g.windows,
                pinned: false
            })
        }

        return items
    }

    // === Stable entry pool ===
    // Each app gets ONE persistent QtObject keyed by `key`; reconciliation updates its
    // (reactive) properties instead of recreating it. With ScriptModel in DockBar this
    // preserves delegates across window events, so per-icon state/animations survive.
    // Focus/title changes propagate via the Hyprland toplevels held in `windows` (their
    // own notifiable properties) — no rebuild needed.
    Component {
        id: dockEntryComponent
        QtObject {
            property string key
            property string appId
            property var entry: null
            property var windows: []
            property bool pinned: false
            property string cls: ""
        }
    }

    property var _entries: ({})       // key -> entry QtObject
    property var model: []            // array of entry QtObjects, stable references

    function _reconcile() {
        const desired = desiredModel
        let seen = ({})
        let out = []
        for (let i = 0; i < desired.length; i++) {
            const d = desired[i]
            seen[d.key] = true
            let obj = _entries[d.key]
            if (!obj) {
                obj = dockEntryComponent.createObject(root, d)
                _entries[d.key] = obj
            } else {
                obj.appId = d.appId
                obj.entry = d.entry
                obj.windows = d.windows
                obj.pinned = d.pinned
                obj.cls = d.cls
            }
            out.push(obj)
        }
        // Destroy entries whose key disappeared.
        for (const k in _entries) {
            if (!seen[k]) {
                _entries[k].destroy()
                delete _entries[k]
            }
        }
        model = out
    }

    onDesiredModelChanged: _reconcile()
    Component.onCompleted: {
        _syncFromConfig()
        _reconcile()
    }

    // Wayland toplevels for a model item, for ScreencopyView previews.
    // Match by the stable key, with a raw-class fallback.
    function toplevelsFor(item) {
        if (!item) return []
        const all = ToplevelManager.toplevels?.values ?? []
        const k = item.key
        const c = normalize(item.cls)
        let matched = []
        for (let i = 0; i < all.length; i++) {
            const aid = normalize(all[i].appId)
            if (aid === k || (c && aid === c)) matched.push(all[i])
        }
        return matched
    }

    // === Window actions ===

    // Emitted whenever an app is launched (any source: left-click, middle-click, menu)
    // so the dock icon can show launch feedback regardless of where the launch came from.
    signal appLaunched(string key)

    function launch(app) {
        if (app && app.entry) {
            app.entry.execute()
            appLaunched(app.key)
        }
    }

    function _focusAddress(addr) {
        if (addr) Hyprland.dispatch("focuswindow address:" + addr)
    }

    // Left-click behavior: launch if not running, focus the single window, or
    // cycle focus through the app's windows.
    function activateOrCycle(app) {
        if (!app) return
        const w = app.windows
        if (!w || w.length === 0) { launch(app); return }
        if (w.length === 1) { _focusAddress(w[0].lastIpcObject?.address ?? ""); return }
        let cur = -1
        for (let i = 0; i < w.length; i++) {
            if (w[i].activated) { cur = i; break }
        }
        const next = (cur + 1) % w.length
        _focusAddress(w[next].lastIpcObject?.address ?? "")
    }

    // Close one window, or all of an app's windows.
    function closeWindow(win) {
        const addr = win?.lastIpcObject?.address ?? ""
        if (addr) Hyprland.dispatch("closewindow address:" + addr)
    }

    function closeApp(app) {
        if (!app || !app.windows) return
        for (let i = 0; i < app.windows.length; i++) closeWindow(app.windows[i])
    }

    // === Pin actions (persist to runtime state.json, not the user's config) ===

    function isPinned(appId) {
        return (root.pinnedApps || []).indexOf(appId) >= 0
    }

    function _writePinned(pinnedApps) {
        AppConfig.updateState("dock", { pinnedApps: pinnedApps })
    }

    function pin(appId) {
        const cur = (root.pinnedApps || []).slice()
        if (!appId || cur.indexOf(appId) >= 0) return
        cur.push(appId)
        _writePinned(cur)
    }

    function unpin(appId) {
        const cur = (root.pinnedApps || []).filter(x => x !== appId)
        _writePinned(cur)
    }

    function reorder(from, to) {
        const cur = (root.pinnedApps || []).slice()
        if (from < 0 || from >= cur.length || to < 0 || to >= cur.length || from === to) return
        const moved = cur.splice(from, 1)[0]
        cur.splice(to, 0, moved)
        _writePinned(cur)
    }
}
