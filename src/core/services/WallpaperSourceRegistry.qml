pragma Singleton

import QtQuick
import Quickshell
import qs.src.core.config
import qs.src.core.services.wallpaper

// Registry of wallpaper sources. Reads `wallpaper.sources[]` from config
// and instantiates a per-source object (LocalDirectorySource for now;
// WallhavenSource added in Stage D). Reacts to config changes by
// diffing the source list and creating/destroying instances accordingly.
//
// Sources are keyed by `id` (config-supplied). Manager looks them up by
// id when binding monitors.

Singleton {
    id: registry

    // sourceId → source instance (BaseWallpaperSource)
    property var _sources: ({})
    readonly property var sourceIds: Object.keys(_sources)

    signal sourcesChanged()

    Component { id: localComp; LocalDirectorySource {} }
    // Stage D adds: Component { id: wallhavenComp; WallhavenSource {} }

    Component.onCompleted: {
        if (AppConfig.ready) registry._rebuild()
    }

    Connections {
        target: AppConfig
        function onReadyChanged() { if (AppConfig.ready) registry._rebuild() }
        function onDataChanged()  { if (AppConfig.ready) registry._rebuild() }
    }

    function getSource(id) {
        return _sources[id] || null
    }

    function _rebuild() {
        const cfgList = AppConfig.data.wallpaper?.sources || []
        const next = {}
        const seen = {}

        for (const cfg of cfgList) {
            if (!cfg.id) continue
            seen[cfg.id] = true

            const existing = _sources[cfg.id]
            if (existing && _typeMatches(existing, cfg.type)) {
                _updateSource(existing, cfg)
                next[cfg.id] = existing
                continue
            }
            // Type changed or new source — recreate.
            if (existing && existing.destroy) existing.destroy()
            const made = _instantiate(cfg)
            if (made) next[cfg.id] = made
        }

        // Destroy removed sources.
        for (const oldId in _sources) {
            if (!seen[oldId] && _sources[oldId]?.destroy) {
                _sources[oldId].destroy()
            }
        }

        _sources = next
        sourcesChanged()
    }

    function _typeMatches(source, type) {
        // Heuristic: detect by object property presence (LocalDirectorySource has directoryPath).
        if (type === "local") return ("directoryPath" in source)
        // Stage D will add wallhaven check
        return false
    }

    function _instantiate(cfg) {
        switch (cfg.type) {
            case "local":
                return localComp.createObject(registry, {
                    "sourceId": cfg.id,
                    "name":     cfg.name || cfg.id,
                    "directoryPath": cfg.path || ""
                })
            // Stage D:
            // case "wallhaven":
            //     return wallhavenComp.createObject(registry, { ... })
        }
        console.warn("WallpaperSourceRegistry: unknown source type", cfg.type, "for id", cfg.id)
        return null
    }

    function _updateSource(source, cfg) {
        if (cfg.type === "local") {
            const path = cfg.path || ""
            if (source.directoryPath !== path) source.directoryPath = path
        }
        // Stage D adds wallhaven param updates
    }
}
