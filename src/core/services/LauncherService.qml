pragma Singleton
import QtQuick
import Quickshell
import qs.src.features.launcher.providers

// ProviderManager - управляет провайдерами для поиска
Singleton {
    id: root

    // Текущий поисковый запрос
    property string searchQuery: ""

    // Отфильтрованные результаты
    property var filteredApps: []

    // Провайдеры (в порядке приоритета)
    property list<QtObject> providers: [
        CalculatorProvider { id: calculatorProvider },
        ApplicationProvider { id: applicationProvider },
        FileProvider { id: fileProvider }
    ]

    // Поиск через все провайдеры
    function search(query) {
        searchQuery = query

        // Пустой запрос - очищаем результаты (чистое открытие)
        if (!query || query.trim() === "") {
            filteredApps = []
            return
        }

        let allResults = []

        // Собираем результаты от всех подходящих провайдеров
        for (let i = 0; i < providers.length; i++) {
            let provider = providers[i]

            if (provider.canHandle(query)) {
                let providerResults = provider.search(query)

                // Добавляем приоритет провайдера к score результатов
                for (let j = 0; j < providerResults.length; j++) {
                    providerResults[j].score += provider.priority
                }

                allResults = allResults.concat(providerResults)
            }
        }

        // Сортировка по score (descending)
        allResults.sort((a, b) => b.score - a.score)

        // Преобразуем результаты в формат для ListView
        filteredApps = allResults.slice(0, 10)
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
