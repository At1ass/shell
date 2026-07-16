import QtQuick
import Quickshell
import qs.src.core.services

// Provider for searching clipboard history
BaseProvider {
    id: root

    name: "Clipboard"
    priority: 60  // High priority, above Applications
    prefixes: [">"]  // ">" prefix for clipboard search

    property var launcherService: null

    function search(query) {
        let searchQuery = removePrefix(query).trim()
        // No result cache: preparedEntries is the source of truth and gets
        // updated reactively on every clipboard change. A stale cache here
        // would mask the just-copied entry behind an old list.
        const searchResults = ClipboardService.fuzzySearch(searchQuery)
        if (ClipboardService.debug) {
            console.info("[ClipboardProvider.search] query:", JSON.stringify(query),
                        "searchQuery:", JSON.stringify(searchQuery),
                        "results:", searchResults.length)
        }
        const results = []
        for (let i = 0; i < searchResults.length; i++) {
            const item = searchResults[i]
            const entry = item.entry
            const content = item.content
            const isImage = ClipboardService.entryIsImage(entry)

            // Limit the displayed text length
            let displayText = isImage ? "[Image]" : content
            if (displayText.length > 80) {
                displayText = displayText.substring(0, 80) + "..."
            }

            // First 150 characters for the description
            let description = isImage ? "" : content
            if (description.length > 150) {
                description = description.substring(0, 150) + "..."
            }

            // Pick an icon
            let icon = "edit-paste"
            if (isImage) {
                icon = "image-x-generic"
                // Request thumbnail generation
                ClipboardService.requestThumbnail(entry)
            } else if (content.startsWith("http://") || content.startsWith("https://")) {
                icon = "internet-web-browser"
            } else if (content.match(/^[\d\s\+\-\*\/\(\)\.]+$/)) {
                icon = "accessories-calculator"
            }

            const capturedEntry = entry

            // Equal score for every clipboard result → LauncherService's
            // stable sort keeps them in cliphist (recency) order. Fuzzy
            // match scores are deliberately discarded so that text matches
            // never bubble above newer screenshots.
            results.push({
                id: "clipboard:" + i + ":" + content.substring(0, 20),
                text: displayText,
                description: description,
                icon: icon,
                type: "clipboard",
                score: 0,
                data: { entry: capturedEntry, content: content, isImage: isImage },
                action: function() {
                    ClipboardService.copy(capturedEntry)
                }
            })
        }

        return results
    }

    function defaultResults() {
        // Prefixed provider - do not show default results
        return []
    }

    Component.onCompleted: {
        launcherService = LauncherService
    }
}
