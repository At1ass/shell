import QtQuick
import Quickshell
import FuzzySearch
import qs.src.core.services

// Провайдер для поиска и запуска приложений
BaseProvider {
    id: root

    name: "Applications"
    priority: 50  // Средний приоритет
    prefixes: []  // Нет префикса - всегда активен

    // Все доступные приложения
    readonly property var applications: DesktopEntries.applications.values

    // Кеш частот для производительности
    property var frequencyCache: ({})

    // Обработчик изменения частот
    function handleFrequencyChanged() {
        frequencyCache = AppFrequencyService.getAllFrequencies()
    }

    Component.onCompleted: {
        // Загружаем частоты при старте
        frequencyCache = AppFrequencyService.getAllFrequencies()

        // Подключаем обработчик изменений
        AppFrequencyService.frequencyChanged.connect(handleFrequencyChanged)
    }

    Component.onDestruction: {
        // Отключаем при уничтожении
        AppFrequencyService.frequencyChanged.disconnect(handleFrequencyChanged)
    }

    function search(query) {
        // Пустой запрос — топ 10 по частоте + алфавиту
        if (!query || query.trim() === "") {
            let visibleApps = applications.filter(app => !app.noDisplay)
            visibleApps.sort((a, b) => {
                let freqA = frequencyCache[a.id] || 0
                let freqB = frequencyCache[b.id] || 0
                if (freqA !== freqB) return freqB - freqA
                let nameA = (a.name || "").toLowerCase()
                let nameB = (b.name || "").toLowerCase()
                return nameA.localeCompare(nameB)
            })

            let topApps = []
            for (let i = 0; i < Math.min(10, visibleApps.length); i++) {
                topApps.push(createResult(visibleApps[i], 10 - i))
            }
            return topApps
        }

        // Собираем два массива: имена (приоритет) и полный текст (fallback)
        const visibleApps = []
        const names = []
        const fullTexts = []
        for (let i = 0; i < applications.length; i++) {
            const app = applications[i]
            if (app.noDisplay) continue
            visibleApps.push(app)
            names.push(app.name || "")
            fullTexts.push([
                app.name || "",
                app.genericName || "",
                app.comment || "",
                (app.keywords || []).join(" ")
            ].join(" "))
        }

        // Взвешенный поиск: имя × 2.5, полный текст × 1.0
        const hits = FuzzySearch.matchWeighted(query, names, fullTexts, 10, 30.0, 2.5)
        const results = []
        for (let i = 0; i < hits.length; i++) {
            const app = visibleApps[hits[i].index]
            // Бонус за частоту запуска
            let finalScore = hits[i].score
            const freq = frequencyCache[app.id] || 0
            if (freq > 0) finalScore += Math.min(freq * 5, 50)
            results.push(createResult(app, finalScore))
        }

        // Пересортировка с учётом frequency boost
        results.sort((a, b) => b.score - a.score)
        return results
    }

    function defaultResults() {
        return search("")
    }

    // Создание результата из DesktopEntry
    function createResult(app, score) {
        const entryId = app.id
            || app.filePath
            || app.desktopFile
            || ((app.name || "") + ":" + (app.execString || "") + ":" + (Array.isArray(app.command) ? app.command.join(" ") : ""))

        return {
            id: "application:" + entryId,
            text: app.name || "",
            description: app.comment || app.genericName || "",
            icon: app.icon || "application-x-executable",
            type: "application",
            score: score,
            data: { entry: app },
            action: function() {
                // Инкрементируем частоту запуска
                AppFrequencyService.incrementFrequency(app.id)

                // Запускаем приложение
                app.execute()
            }
        }
    }
}
