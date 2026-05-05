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
    // /api/v1/search parameters per Wallhaven API docs:
    // https://wallhaven.cc/help/api
    property string query:        ""           // q=
    property string categories:   "111"        // bitmask 100 anime / 010 anime / 001 people
    property string purity:       "100"        // bitmask sfw/sketchy/nsfw (default: SFW only)
    property string sorting:      "date_added" // date_added|relevance|random|views|favorites|toplist|hot
    property string order:        "desc"       // desc|asc
    property string topRange:     "1M"         // 1d|3d|1w|1M|3M|6M|1y — used when sorting=toplist
    property string atleast:      ""           // minimum resolution, e.g. "1920x1080"
    property string resolutions:  ""           // exact resolutions list, e.g. "1920x1080,2560x1440"
    property string ratios:       ""           // aspect ratios list, e.g. "16x9,16x10"
    property string colors:       ""           // hex (6 chars, no #), e.g. "660000"
    property string seed:         ""           // random seed (when sorting=random)
    property string apiKeyEnvVar: "WALLHAVEN_API_KEY"
    property int    maxItems:     24           // page size (Wallhaven returns 24 per page)

    // Pagination state (not user-config — driven by loadMore())
    property int    _page:                1
    property bool   _appendOnNextRefresh: false

    // Any user-config change resets pagination and re-runs the search.
    onQueryChanged:       _onConfigChanged()
    onCategoriesChanged:  _onConfigChanged()
    onPurityChanged:      _onConfigChanged()
    onSortingChanged:     _onConfigChanged()
    onOrderChanged:       _onConfigChanged()
    onTopRangeChanged:    _onConfigChanged()
    onAtleastChanged:     _onConfigChanged()
    onResolutionsChanged: _onConfigChanged()
    onRatiosChanged:      _onConfigChanged()
    onColorsChanged:      _onConfigChanged()
    onSeedChanged:        _onConfigChanged()

    function _onConfigChanged() {
        _page = 1
        _appendOnNextRefresh = false
        _scheduleRefresh()
    }

    // Debounce — multiple property setters during init would otherwise
    // fire several refreshes back-to-back.
    property Timer _refreshTimer: Timer {
        interval: 100
        repeat: false
        onTriggered: source.refresh()
    }
    function _scheduleRefresh() { _refreshTimer.restart() }

    // Append the next page to existing items. Useful when the user
    // exhausted a query's first page during long auto-rotation.
    function loadMore() {
        if (loading) return
        _appendOnNextRefresh = true
        _page = _page + 1
        refresh()
    }

    // ── Refresh: GET /api/v1/search → populate items ──────────────
    function refresh() {
        if (loading) return
        loading = true
        const apiKey = Quickshell.env(apiKeyEnvVar) || ""
        const params = []
        if (query.length > 0)       params.push("q=" + encodeURIComponent(query))
        if (categories.length > 0)  params.push("categories=" + categories)
        if (purity.length > 0)      params.push("purity=" + purity)
        if (sorting.length > 0)     params.push("sorting=" + sorting)
        if (order.length > 0)       params.push("order=" + order)
        if (sorting === "toplist" && topRange.length > 0)
            params.push("topRange=" + topRange)
        if (atleast.length > 0)     params.push("atleast=" + atleast)
        if (resolutions.length > 0) params.push("resolutions=" + encodeURIComponent(resolutions))
        if (ratios.length > 0)      params.push("ratios=" + encodeURIComponent(ratios))
        if (colors.length > 0)      params.push("colors=" + colors)
        if (sorting === "random" && seed.length > 0)
            params.push("seed=" + encodeURIComponent(seed))
        if (_page > 1)              params.push("page=" + _page)
        if (apiKey.length > 0)      params.push("apikey=" + apiKey)
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
        const fresh = data.slice(0, maxItems).map(w => ({
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

        if (_appendOnNextRefresh) {
            // Dedupe by id while concatenating
            const seen = {}
            for (const it of items) seen[it.id] = true
            const merged = items.slice()
            for (const it of fresh) if (!seen[it.id]) merged.push(it)
            items = merged
            _appendOnNextRefresh = false
        } else {
            items = fresh
        }
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
