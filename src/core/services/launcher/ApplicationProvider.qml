import QtQuick
import Quickshell
import FuzzySearch
import qs.src.core.config
import qs.src.core.services

// Application search/launch provider.
BaseProvider {
    id: root

    name: "Applications"
    priority: 50   // medium priority
    prefixes: []   // no prefix — always active

    readonly property var applications: DesktopEntries.applications.values

    // Launch-frequency cache (id → count) for ranking.
    property var frequencyCache: ({})

    // Search corpus (visible apps + name/full-text arrays for FuzzySearch).
    // Rebuilt ONLY when the application list changes — building four strings
    // per app on every keystroke was pure allocation churn.
    property var _corpus: null
    onApplicationsChanged: _corpus = null

    // launcher.hiddenApps changes arrive through config hot-reload.
    readonly property Connections _configWatch: Connections {
        target: AppConfig
        function onDataChanged() { root._corpus = null }
    }

    function _buildCorpus() {
        const hidden = AppConfig.launcherHiddenApps.map(
            id => id.toLowerCase().replace(/\.desktop$/, ""))
        const visible = []
        const names = []
        const fullTexts = []
        for (let i = 0; i < applications.length; i++) {
            const app = applications[i]
            if (app.noDisplay) continue
            if (hidden.indexOf((app.id || "").toLowerCase().replace(/\.desktop$/, "")) !== -1) continue
            visible.push(app)
            names.push(app.name || "")
            fullTexts.push([
                app.name || "",
                app.genericName || "",
                app.comment || "",
                (app.keywords || []).join(" ")
            ].join(" "))
        }
        _corpus = { "visible": visible, "names": names, "fullTexts": fullTexts }
    }

    function handleFrequencyChanged() {
        frequencyCache = AppFrequencyService.getAllFrequencies()
    }

    Component.onCompleted: {
        frequencyCache = AppFrequencyService.getAllFrequencies()
        AppFrequencyService.frequencyChanged.connect(handleFrequencyChanged)
    }

    Component.onDestruction: {
        AppFrequencyService.frequencyChanged.disconnect(handleFrequencyChanged)
    }

    function search(query) {
        if (!_corpus) _buildCorpus()

        // Empty query — top 10 by launch frequency, then alphabetically.
        if (!query || query.trim() === "") {
            const sorted = _corpus.visible.slice()
            sorted.sort((a, b) => {
                const freqA = frequencyCache[a.id] || 0
                const freqB = frequencyCache[b.id] || 0
                if (freqA !== freqB) return freqB - freqA
                return (a.name || "").toLowerCase().localeCompare((b.name || "").toLowerCase())
            })

            const topApps = []
            for (let i = 0; i < Math.min(10, sorted.length); i++) {
                topApps.push(createResult(sorted[i], 10 - i))
            }
            return topApps
        }

        // Weighted search: name x 2.5, full text x 1.0.
        const hits = FuzzySearch.matchWeighted(query, _corpus.names, _corpus.fullTexts, 10, 30.0, 2.5)
        const results = []
        for (let i = 0; i < hits.length; i++) {
            const app = _corpus.visible[hits[i].index]
            let finalScore = hits[i].score
            const freq = frequencyCache[app.id] || 0
            if (freq > 0) finalScore += Math.min(freq * 5, 50)
            results.push(createResult(app, finalScore))
        }

        // Re-sort after the frequency boost.
        results.sort((a, b) => b.score - a.score)
        return results
    }

    function defaultResults() {
        return search("")
    }

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
                AppFrequencyService.incrementFrequency(app.id)
                app.execute()
            }
        }
    }
}
