pragma Singleton
import QtQuick
import QtQml
import Quickshell
import qs.src.core.config
import qs.src.core.services.launcher

// ProviderManager - manages search providers
Singleton {
    id: root

    // Current search query
    property string searchQuery: ""

    function modeFor(query) {
        const prefix = (query ?? "").trim().charAt(0)
        return prefix === "=" ? "calculator" : prefix === ">" ? "clipboard"
            : prefix === ":" ? "actions" : prefix === "@" ? "windows" : "applications"
    }
    readonly property string mode: modeFor(searchQuery)
    readonly property bool busy: mode === "calculator" && calculatorProvider.busy

    // Filtered results
    property var filteredApps: []

    // Cache of search result QML objects (key -> QtObject)
    property var _wrapperCache: ({})
    property var _cacheAccessTime: ({})
    property int _maxCacheSize: 1000

    // Providers (in priority order)
    property list<QtObject> providers: [
        CalculatorProvider { id: calculatorProvider },
        ClipboardProvider { id: clipboardProvider },
        ActionProvider {},
        WindowProvider {},
        ApplicationProvider { id: applicationProvider }
    ]

    Component {
        id: resultWrapperComponent

        QtObject {
            property string resultId: ""
            property string type: ""
            property string text: ""
            property string description: ""
            property string icon: ""
            property int score: 0
            property var data: null
            property var action: null
        }
    }

    function _evictOldestCacheEntry() {
        let keys = Object.keys(_wrapperCache)
        if (keys.length === 0) return

        // Never destroy a wrapper the live model still references —
        // delegates (including ones mid-removal-transition) bind to it.
        const live = {}
        for (const w of filteredApps) live[w.resultId] = true

        let oldestKey = ""
        let oldestTime = Infinity
        for (const key of keys) {
            if (live[key]) continue
            const time = _cacheAccessTime[key] || 0
            if (time < oldestTime) {
                oldestTime = time
                oldestKey = key
            }
        }
        if (!oldestKey) return   // everything cached is live; skip eviction

        let wrapper = _wrapperCache[oldestKey]
        if (wrapper) {
            wrapper.destroy()
        }
        delete _wrapperCache[oldestKey]
        delete _cacheAccessTime[oldestKey]
    }

    function wrapperForResult(key) {
        if (!key || typeof key !== "string") {
            return null
        }

        let existing = _wrapperCache[key]
        if (existing) {
            _cacheAccessTime[key] = Date.now()
            return existing
        }

        // Check cache size and evict if needed
        let cacheSize = Object.keys(_wrapperCache).length
        if (cacheSize >= _maxCacheSize) {
            _evictOldestCacheEntry()
        }

        let wrapper = resultWrapperComponent.createObject(root)
        if (!wrapper) {
            console.warn("LauncherService: Failed to create result wrapper for key", key)
            return null
        }

        wrapper.resultId = key
        _wrapperCache[key] = wrapper
        _cacheAccessTime[key] = Date.now()
        return wrapper
    }

    // Search across all providers
    function search(query) {
        query = (query ?? "").trim()
        searchQuery = query
        if (mode !== "calculator") calculatorProvider.cancel()

        let trimmed = query ? query.trim() : ""
        let useDefaults = trimmed.length === 0

        let collectedResults = []
        let seenKeys = Object.create(null)

        // Check if a prefix-based provider matches — if so, skip generic providers
        let hasPrefixMatch = false
        if (!useDefaults) {
            for (let i = 0; i < providers.length; i++) {
                let p = providers[i]
                if (p.prefixes && p.prefixes.length > 0 && p.canHandle(query)) {
                    hasPrefixMatch = true
                    break
                }
            }
        }

        // Collect results from matching providers
        for (let i = 0; i < providers.length; i++) {
            let provider = providers[i]
            let providerResults = []

            if (useDefaults) {
                if (typeof provider.defaultResults === "function") {
                    providerResults = provider.defaultResults()
                }
            } else if (provider.canHandle(query)) {
                // Skip generic (no-prefix) providers when a prefix provider matched
                if (hasPrefixMatch && (!provider.prefixes || provider.prefixes.length === 0))
                    continue
                providerResults = provider.search(query)
            }

            if (!Array.isArray(providerResults) || providerResults.length === 0) {
                continue
            }

            // Convert results to QML objects, reusing them across searches
            for (let j = 0; j < providerResults.length; j++) {
                let result = providerResults[j]
                if (!result || !result.id) continue

                let key = String(result.id)
                if (seenKeys[key]) {
                    // Guard against duplicates from different providers
                    continue
                }
                seenKeys[key] = true

                collectedResults.push(Object.assign({}, result, {
                    _order: collectedResults.length,
                    score: (typeof result.score === "number" ? result.score : 0) + provider.priority
                }))
            }
        }

        if (!hasPrefixMatch)
            collectedResults.sort((a, b) => (b.score || 0) - (a.score || 0) || a._order - b._order)
        const cap = hasPrefixMatch ? Math.max(AppConfig.launcherMaxResults, 50)
                                   : AppConfig.launcherMaxResults
        const selected = collectedResults.slice(0, cap)
        const wrappers = []
        for (const result of selected) {
            const wrapper = wrapperForResult(String(result.id))
            if (!wrapper) continue
            wrapper.type = result.type || ""
            wrapper.text = result.text || ""
            wrapper.description = result.description || ""
            wrapper.icon = result.icon || ""
            wrapper.score = result.score
            wrapper.data = result.hasOwnProperty("data") ? result.data : null
            wrapper.action = typeof result.action === "function" ? result.action : null
            wrappers.push(wrapper)
        }
        filteredApps = wrappers

        if (ClipboardService.debug && hasPrefixMatch) {
            console.info("[LauncherService] prefix mode results:", filteredApps.length)
            for (let k = 0; k < Math.min(filteredApps.length, 10); k++) {
                const r = filteredApps[k]
                console.info("  ", k, "type=" + r.type, "text=" +
                    (r.text || "").substring(0, 40).replace(/\n/g, "\\n"))
            }
        }
    }

    // Execute a result's action.
    function launch(result) {
        if (!result || !result.action) {
            console.warn("LauncherService: No action for result")
            return
        }

        // This singleton survives unloading a non-retained launcher. Complete
        // the handoff here so its destroyed UI context owns no follow-up work.
        GlobalStates.closePanel("launcher")
        result.action()
    }

    // Throttled/async providers report stale results; re-run the live query.
    Component.onCompleted: {
        for (let i = 0; i < providers.length; i++) {
            providers[i].resultsInvalidated.connect(() => root.search(root.searchQuery))
        }
    }
}
