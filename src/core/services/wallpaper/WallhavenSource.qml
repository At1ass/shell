import QtQuick
import Quickshell
import qs.src.core.services

// Wallhaven (https://wallhaven.cc) wallpaper source.
//
// Per-source config (from wallpaper.sources[]):
//   {
//     "id": "wh-anime", "type": "wallhaven",
//     "query":      "anime",        // free-text query (optional)
//     "categories": "010",          // bitmask: 100=general 010=anime 001=people
//     "purity":     "100",          // bitmask: 100=sfw 010=sketchy 001=nsfw
//     "apiKeyEnvVar": "WALLHAVEN_API_KEY"   // env var name; empty for unauth (SFW only)
//   }
//
// API key is resolved at refresh time via Quickshell.env(apiKeyEnvVar).
// Never read from config files directly.
//
// Items are populated from /api/v1/search response; full-resolution
// images live at item.path (URL). resolveItem() asks WallpaperCache to
// download on-demand and returns "" — Manager waits for the
// itemResolved signal once cache.storeComplete fires.

BaseWallpaperSource {
    id: source

    iconName: "image"

    // ── Config (set by Registry from per-source object) ───────────
    property string query:        ""
    property string categories:   "111"   // default: all three
    property string purity:       "100"   // default: SFW only
    property string apiKeyEnvVar: "WALLHAVEN_API_KEY"
    property int    maxItems:     24

    onQueryChanged:      _scheduleRefresh()
    onCategoriesChanged: _scheduleRefresh()
    onPurityChanged:     _scheduleRefresh()

    // Debounce config changes — multiple property setters during init
    // would otherwise fire several refreshes back-to-back.
    property Timer _refreshTimer: Timer {
        interval: 100
        repeat: false
        onTriggered: source.refresh()
    }
    function _scheduleRefresh() { _refreshTimer.restart() }

    // ── Refresh: GET /api/v1/search → populate items ──────────────
    function refresh() {
        if (loading) return
        loading = true
        const apiKey = Quickshell.env(apiKeyEnvVar) || ""
        const params = []
        if (query.length > 0)      params.push("q=" + encodeURIComponent(query))
        if (categories.length > 0) params.push("categories=" + categories)
        if (purity.length > 0)     params.push("purity=" + purity)
        if (apiKey.length > 0)     params.push("apikey=" + apiKey)
        const url = "https://wallhaven.cc/api/v1/search?" + params.join("&")

        const xhr = new XMLHttpRequest()
        xhr.open("GET", url, true)
        xhr.timeout = 30000
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status === 0) {
                source._setError("Wallhaven: network error")
                return
            }
            if (xhr.status !== 200) {
                source._setError("Wallhaven HTTP " + xhr.status)
                return
            }
            try {
                source._populate(JSON.parse(xhr.responseText))
            } catch (e) {
                source._setError("Wallhaven parse: " + e.message)
            }
        }
        xhr.ontimeout = function() {
            source._setError("Wallhaven: request timed out")
        }
        xhr.send()
    }

    function _populate(json) {
        const data = json.data || []
        const newItems = data.slice(0, maxItems).map(w => ({
            "id":        String(w.id),
            "name":      String(w.id),
            "url":       w.path,
            "thumbnail": w.thumbs?.small ?? "",
            "metadata": {
                "resolution":  w.resolution || "",
                "ratio":       w.ratio || "",
                "fileSize":    w.file_size || 0,
                "fileType":    w.file_type || "",
                "purity":      w.purity || "",
                "category":    w.category || "",
                "shortUrl":    w.short_url || "",
                "url":         w.url || ""
            }
        }))
        items = newItems
        ready = true
        loading = false
        lastError = ""
        itemsRefreshed()
    }

    // ── Resolve: lookup in WallpaperCache, queue download if missing ─
    function resolveItem(itemId) {
        const it = findItem(itemId)
        if (!it) return ""
        const ext = _extFromUrl(it.url)
        if (WallpaperCache.has(sourceId, itemId, ext)) {
            return WallpaperCache.path(sourceId, itemId, ext)
        }
        // Async download — Manager will receive itemResolved when done.
        WallpaperCache.store(sourceId, itemId, ext, it.url)
        return ""
    }

    function _extFromUrl(url) {
        const m = String(url).match(/\.([a-zA-Z0-9]+)(?:\?.*)?$/)
        return m ? m[1].toLowerCase() : "jpg"
    }

    // QtObject lacks default-children list; attach Connections via
    // an explicit property so ComponentBehavior auto-disconnects on
    // source destruction.
    property Connections _cacheConn: Connections {
        target: WallpaperCache
        function onStoreComplete(sId, iId, success, localPath) {
            if (sId === source.sourceId && success) {
                source.itemResolved(iId, localPath)
            }
        }
    }
}
