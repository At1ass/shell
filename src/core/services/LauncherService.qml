pragma Singleton
import QtQuick
import QtQml
import Quickshell
import qs.src.core.config
import qs.src.core.services.launcher

// ProviderManager - управляет провайдерами для поиска
Singleton {
    id: root

    // Текущий поисковый запрос
    property string searchQuery: ""

    // Отфильтрованные результаты
    property var filteredApps: []

    // Кэш QML-объектов результатов поиска (ключ -> QtObject)
    property var _wrapperCache: ({})
    property var _cacheAccessTime: ({})
    property int _maxCacheSize: 1000

    // Провайдеры (в порядке приоритета)
    property list<QtObject> providers: [
        CalculatorProvider { id: calculatorProvider },
        ClipboardProvider { id: clipboardProvider },
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

        let oldestKey = keys[0]
        let oldestTime = _cacheAccessTime[oldestKey] || 0

        for (let i = 1; i < keys.length; i++) {
            let key = keys[i]
            let time = _cacheAccessTime[key] || 0
            if (time < oldestTime) {
                oldestTime = time
                oldestKey = key
            }
        }

        // Удаляем старейший элемент
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

        // Проверяем размер кэша и evict если нужно
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

    // Поиск через все провайдеры
    function search(query) {
        searchQuery = query

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

            // Преобразуем результаты в QML-объекты, переиспользуя их между поисками
            for (let j = 0; j < providerResults.length; j++) {
                let result = providerResults[j]
                if (!result || !result.id) continue

                let key = String(result.id)
                if (seenKeys[key]) {
                    // Защита от дублей из разных провайдеров
                    continue
                }
                seenKeys[key] = true

                let wrapper = wrapperForResult(key)
                if (!wrapper) continue

                wrapper.type = result.type || ""
                wrapper.text = result.text || ""
                wrapper.description = result.description || ""
                wrapper.icon = result.icon || ""
                wrapper.score = (typeof result.score === "number" ? result.score : 0) + provider.priority
                wrapper.data = result.hasOwnProperty("data") ? result.data : null
                wrapper.action = typeof result.action === "function" ? result.action : null

                collectedResults.push(wrapper)
            }
        }

        // In prefix-match mode, preserve the provider's natural order
        // (e.g. cliphist recency for ">"). Otherwise sort by score desc.
        if (!hasPrefixMatch)
            collectedResults.sort((a, b) => (b.score || 0) - (a.score || 0))

        // Prefix-matched provider implies a focused mode (e.g. ">" for
        // clipboard). Don't cap to the generic launcherMaxResults — the
        // user needs enough room to scroll through screenshots/history.
        const cap = hasPrefixMatch ? Math.max(AppConfig.launcherMaxResults, 50)
                                   : AppConfig.launcherMaxResults
        filteredApps = collectedResults.slice(0, cap)

        if (ClipboardService.debug && hasPrefixMatch) {
            console.log("[LauncherService] prefix mode results:", filteredApps.length)
            for (let k = 0; k < Math.min(filteredApps.length, 10); k++) {
                const r = filteredApps[k]
                console.log("  ", k, "type=" + r.type, "text=" +
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

        result.action()
    }

    // Throttled/async providers report stale results; re-run the live query.
    Component.onCompleted: {
        for (let i = 0; i < providers.length; i++) {
            providers[i].resultsInvalidated.connect(() => root.search(root.searchQuery))
        }
    }
}
