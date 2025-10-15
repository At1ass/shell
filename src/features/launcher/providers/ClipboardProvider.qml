import QtQuick
import Quickshell
import qs.src.core.services

// Провайдер для поиска в истории буфера обмена
BaseProvider {
    id: root

    name: "Clipboard"
    priority: 60  // Высокий приоритет, выше Applications
    prefixes: [">"]  // Префикс ">" для поиска в clipboard

    property var lastResults: []
    property string lastQuery: ""
    property var launcherService: null

    function search(query) {
        let searchQuery = removePrefix(query).trim()

        // Кешируем результаты
        if (searchQuery === lastQuery && lastResults.length > 0) {
            return lastResults
        }

        const searchResults = ClipboardService.fuzzySearch(searchQuery)
        const results = []

        for (let i = 0; i < searchResults.length; i++) {
            const item = searchResults[i]
            const entry = item.entry
            const content = item.content
            const score = item.score

            // Ограничиваем длину отображаемого текста
            let displayText = content
            if (displayText.length > 80) {
                displayText = displayText.substring(0, 80) + "..."
            }

            // Первые 150 символов для описания
            let description = content
            if (description.length > 150) {
                description = description.substring(0, 150) + "..."
            }

            // Определяем иконку
            let icon = "edit-paste"
            if (ClipboardService.entryIsImage(entry)) {
                icon = "image-x-generic"
            } else if (content.startsWith("http://") || content.startsWith("https://")) {
                icon = "internet-web-browser"
            } else if (content.match(/^[\d\s\+\-\*\/\(\)\.]+$/)) {
                icon = "accessories-calculator"
            }

            const capturedEntry = entry

            results.push({
                id: "clipboard:" + i + ":" + content.substring(0, 20),
                text: displayText,
                description: description,
                icon: icon,
                type: "clipboard",
                score: score,
                data: { entry: capturedEntry, content: content },
                action: function() {
                    console.log("Copying to clipboard:", content.substring(0, 50))
                    ClipboardService.copy(capturedEntry)
                }
            })
        }

        lastResults = results
        lastQuery = searchQuery

        return results
    }

    function defaultResults() {
        // Провайдер с префиксом - не показываем результаты по умолчанию
        return []
    }

    Component.onCompleted: {
        launcherService = LauncherService
    }
}
