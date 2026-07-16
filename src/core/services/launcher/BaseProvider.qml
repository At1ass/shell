import QtQuick

// Base type for launcher search providers.
QtObject {
    id: root

    // Provider name (debugging).
    property string name: "BaseProvider"

    // Higher priority = earlier in merged results.
    property int priority: 0

    // Prefixes this provider handles (e.g. ["=", "calc"]).
    // Empty array = handles every query.
    property var prefixes: []

    // Emitted when previously returned results became stale (throttled or
    // asynchronous providers). LauncherService re-runs the current query.
    signal resultsInvalidated()

    // Can this provider handle the query?
    function canHandle(query) {
        if (!query) return false

        if (prefixes.length === 0) return true

        for (let i = 0; i < prefixes.length; i++) {
            if (query.startsWith(prefixes[i])) {
                return true
            }
        }

        return false
    }

    // Search (override in subtypes). Returns an array of:
    // {
    //   id: "type:stable-key",
    //   text: "Result text",
    //   description: "Result description",
    //   icon: "icon-name",
    //   type: "calculator|application|file|action",
    //   score: 100,
    //   data: {...},              // extra payload
    //   action: function() {...}  // what to execute
    // }
    function search(query) {
        console.warn(name + ": search() not implemented")
        return []
    }

    // Results for the empty query.
    function defaultResults() {
        return []
    }

    // Strip a matching prefix from the query.
    function removePrefix(query) {
        for (let i = 0; i < prefixes.length; i++) {
            if (query.startsWith(prefixes[i])) {
                return query.slice(prefixes[i].length).trim()
            }
        }
        return query
    }
}
