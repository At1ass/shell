pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    // All available applications
    readonly property var applications: DesktopEntries.applications.values

    // Filtered applications based on search
    property var filteredApps: applications

    // Current search query
    property string searchQuery: ""

    // Launch an application
    function launch(entry) {
        if (!entry) return

        console.log("Launching:", entry.name)
        entry.execute()
    }

    // Simple fuzzy search function
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

    // Search applications
    function search(query) {
        searchQuery = query

        if (!query || query.trim() === "") {
            // Return top 10 apps when no search
            filteredApps = applications.slice(0, 10)
            return
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

                results.push({ entry: app, score: score })
            }
        }

        // Sort by score (descending)
        results.sort((a, b) => b.score - a.score)

        // Take top 10 and extract entries
        filteredApps = results.slice(0, 10).map(r => r.entry)
    }

    // Initialize with top apps
    Component.onCompleted: {
        search("")
    }
}
