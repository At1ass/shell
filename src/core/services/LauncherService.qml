pragma Singleton
import QtQuick
import QtQml
import Quickshell
import qs.src.features.launcher.providers

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

        // Собираем результаты от всех подходящих провайдеров
        for (let i = 0; i < providers.length; i++) {
            let provider = providers[i]
            let providerResults = []

            if (useDefaults) {
                if (typeof provider.defaultResults === "function") {
                    providerResults = provider.defaultResults()
                }
            } else if (provider.canHandle(query)) {
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

        // Сортировка по score (descending)
        collectedResults.sort((a, b) => (b.score || 0) - (a.score || 0))

        // Преобразуем результаты в формат для ListView (ограничиваем top-10)
        filteredApps = collectedResults.slice(0, 10)
    }

    // Выполнение action результата
    function launch(result) {
        if (!result || !result.action) {
            console.warn("LauncherService: No action for result")
            return
        }

        console.log("LauncherService: Executing action for", result.text)
        result.action()
    }

    // НЕ инициализируем при старте - только при первом поиске
    // Component.onCompleted не нужен
}
