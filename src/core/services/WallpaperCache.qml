pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.src.core.config

// Disk-backed LRU cache for wallpaper sources that fetch over the network
// (Wallhaven and friends, added in Stage D). Local sources don't need it —
// their items are already on disk.
//
// Layout:  ${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/wallpapers/{sourceId}/{itemId}.{ext}
//
// API:
//   has(sourceId, itemId, ext) → bool        // sync, in-memory index
//   path(sourceId, itemId, ext) → string     // computes path, file may not exist
//   store(sourceId, itemId, ext, url)        // async download; emits storeComplete
//   storeComplete(sourceId, itemId, ok, path)  signal
//
// Eviction: after each successful store, scan the cache directory and
// remove the oldest files (by mtime) until total size ≤ maxBytes.
//
// Atomicity: download to `<final>.tmp`, mv to `<final>` on curl success.
// Wrapped in `bash -c` so `mkdir -p && curl && mv` is one process — URL
// is passed as positional `"$1"` so its content is never interpolated
// into the shell command.

Singleton {
    id: cache

    readonly property string _home: Quickshell.env("HOME") || ""
    readonly property string _xdgCache:
        Quickshell.env("XDG_CACHE_HOME") || (_home + "/.cache")
    readonly property string baseDir: _xdgCache + "/quickshell/wallpapers"

    readonly property int maxBytes:
        AppConfig.data.wallpaper?.cache?.maxBytes ?? 524288000   // 500 MB

    // Set of relative paths (sourceId/itemId.ext) currently on disk.
    // Populated on startup by a `find` scan, mutated on store/evict.
    property var _known: ({})

    // Active download / queue
    property var _queue: []
    property var _current: null

    signal storeComplete(string sourceId, string itemId, bool success, string localPath)

    Component.onCompleted: _initIndex()

    // ── Public API ────────────────────────────────────────────────

    function has(sourceId, itemId, ext) {
        return _known[_relPath(sourceId, itemId, ext)] === true
    }

    function path(sourceId, itemId, ext) {
        return baseDir + "/" + _sanitize(sourceId) + "/" + _sanitize(itemId) + "." + (ext || "jpg")
    }

    function store(sourceId, itemId, ext, url) {
        _queue.push({
            "sourceId": sourceId,
            "itemId":   itemId,
            "ext":      ext || "jpg",
            "url":      url
        })
        if (!_dlProc.running) _runNext()
    }

    // ── Internals ────────────────────────────────────────────────

    function _runNext() {
        if (!_queue.length) {
            _current = null
            return
        }
        _current = _queue.shift()
        const finalPath = path(_current.sourceId, _current.itemId, _current.ext)
        const tmpPath = finalPath + ".tmp"
        const dirPath = baseDir + "/" + _sanitize(_current.sourceId)
        _current.finalPath = finalPath
        _current.tmpPath = tmpPath

        // Single shell pipeline: mkdir + curl + mv. URL goes through
        // positional $1 so its content is never interpolated.
        const script = `mkdir -p ${_shQuote(dirPath)} && `
                     + `curl -fsSL --max-time 60 -o ${_shQuote(tmpPath)} "$1" && `
                     + `mv -f ${_shQuote(tmpPath)} ${_shQuote(finalPath)}`
        _dlProc.command = ["bash", "-c", script, "--", _current.url]
        _dlProc.running = true
    }

    Process {
        id: _dlProc

        stderr: StdioCollector {
            onStreamFinished: {
                const err = text.trim()
                if (err) console.warn("WallpaperCache: download stderr:", err)
            }
        }

        onExited: (exitCode) => {
            const c = cache._current
            if (!c) return
            const ok = exitCode === 0
            if (ok) cache._known[cache._relPath(c.sourceId, c.itemId, c.ext)] = true
            cache.storeComplete(c.sourceId, c.itemId, ok, ok ? c.finalPath : "")
            if (ok) cache._maybeEvict()
            cache._runNext()
        }
    }

    // ── Eviction ─────────────────────────────────────────────────
    function _maybeEvict() {
        if (_evictProc.running) return
        _evictProc.command = [
            "find", baseDir, "-type", "f",
            "-printf", "%T@ %s %p\\n"
        ]
        _evictProc.running = true
    }

    Process {
        id: _evictProc
        property string _result: ""

        stdout: StdioCollector {
            onStreamFinished: cache._handleEvictListing(text)
        }

        onExited: {}
    }

    function _handleEvictListing(rawOutput) {
        const lines = rawOutput.trim().split("\n").filter(l => l.length > 0)
        const files = []
        let total = 0
        for (const line of lines) {
            // "%T@ %s %p" → "1234567890.0000 12345 /path/to/file.jpg"
            const sp1 = line.indexOf(" ")
            if (sp1 < 0) continue
            const sp2 = line.indexOf(" ", sp1 + 1)
            if (sp2 < 0) continue
            const mtime = parseFloat(line.substring(0, sp1))
            const size = parseInt(line.substring(sp1 + 1, sp2))
            const path = line.substring(sp2 + 1)
            if (isNaN(mtime) || isNaN(size)) continue
            files.push({ mtime, size, path })
            total += size
        }
        if (total <= maxBytes) return

        files.sort((a, b) => a.mtime - b.mtime)
        const toRemove = []
        for (const f of files) {
            if (total <= maxBytes) break
            toRemove.push(f.path)
            total -= f.size
        }
        if (!toRemove.length) return
        _rmProc.command = ["rm", "-f"].concat(toRemove)
        _rmProc.running = true
    }

    Process {
        id: _rmProc
        onExited: cache._initIndex()  // re-scan, simpler than diffing
    }

    // ── Initial index scan ───────────────────────────────────────
    function _initIndex() {
        _initProc.command = ["find", baseDir, "-type", "f"]
        _initProc.running = true
    }

    Process {
        id: _initProc

        stdout: StdioCollector {
            onStreamFinished: {
                const known = {}
                const prefix = cache.baseDir + "/"
                for (const p of text.trim().split("\n")) {
                    if (p.startsWith(prefix)) known[p.substring(prefix.length)] = true
                }
                cache._known = known
            }
        }

        // Ignore exit code: directory may not exist on first run
        onExited: {}
    }

    // ── Helpers ──────────────────────────────────────────────────

    function _relPath(sourceId, itemId, ext) {
        return _sanitize(sourceId) + "/" + _sanitize(itemId) + "." + (ext || "jpg")
    }

    function _sanitize(s) {
        return String(s).replace(/[^A-Za-z0-9._-]/g, "_")
    }

    function _shQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'"
    }

    // ── Maintenance IPC ──────────────────────────────────────────
    IpcHandler {
        target: "wallpaper-cache"

        function status(): string {
            const count = Object.keys(cache._known).length
            return `Cache base: ${cache.baseDir}\n`
                 + `Max bytes: ${cache.maxBytes}\n`
                 + `Known files: ${count}\n`
                 + `Queue depth: ${cache._queue.length}`
        }

        function evict(): string {
            cache._maybeEvict()
            return "Eviction triggered"
        }
    }
}
