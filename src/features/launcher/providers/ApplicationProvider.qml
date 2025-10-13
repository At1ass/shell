import QtQuick
import Quickshell

// Провайдер для поиска и запуска приложений
BaseProvider {
    id: root

    name: "Applications"
    priority: 50  // Средний приоритет
    prefixes: []  // Нет префикса - всегда активен

    // Все доступные приложения
    readonly property var applications: DesktopEntries.applications.values

    // Fuzzy search function
    function fuzzyMatch(text, query) {
        if (!query) return true

        text = text.toLowerCase()
        query = query.toLowerCase()

        // Exact substring match
        if (text.includes(query)) return true

        // Fuzzy match - all characters of query must appear in order
        let queryIndex = 0
        for (let i = 0; i < text.length && queryIndex < query.length; i++) {
            if (text[i] === query[queryIndex]) {
                queryIndex++
            }
        }
        return queryIndex === query.length
    }

    function search(query) {
        // Пустой запрос - возвращаем топ 10 приложений
        if (!query || query.trim() === "") {
            let topApps = []
            for (let i = 0; i < Math.min(10, applications.length); i++) {
                if (!applications[i].noDisplay) {
                    topApps.push(createResult(applications[i], 10 - i))
                }
            }
            return topApps
        }

        const queryLower = query.toLowerCase()
        const results = []

        for (let i = 0; i < applications.length; i++) {
            const app = applications[i]

            // Skip NoDisplay apps
            if (app.noDisplay) continue

            // Search in name, genericName, comment, keywords
            const searchText = [
                app.name || "",
                app.genericName || "",
                app.comment || "",
                (app.keywords || []).join(" ")
            ].join(" ")

            if (fuzzyMatch(searchText, queryLower)) {
                // Calculate score based on match position
                let score = 0
                const nameLower = (app.name || "").toLowerCase()

                if (nameLower.startsWith(queryLower)) {
                    score = 100 // Exact prefix match
                } else if (nameLower.includes(queryLower)) {
                    score = 50 // Contains match
                } else {
                    score = 10 // Fuzzy match
                }

                results.push(createResult(app, score))
            }
        }

        // Sort by score (descending)
        results.sort((a, b) => b.score - a.score)

        // Return top 10
        return results.slice(0, 10)
    }

    // Создание результата из DesktopEntry
    function createResult(app, score) {
        return {
            text: app.name || "",
            description: app.comment || app.genericName || "",
            icon: app.icon || "application-x-executable",
            type: "application",
            score: score,
            data: { entry: app },
            action: function() {
                console.log("Launching:", app.name)
                app.execute()
            }
        }
    }
}
