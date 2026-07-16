import QtQuick
import Quickshell
import Qalculate

// Math evaluation provider backed by libqalculate. Evaluation is fully
// asynchronous (QalculateWrapper.evalAsync on a pool thread): search()
// returns the cached result immediately and requests a fresh evaluation;
// when `evaluated` arrives the cache updates and resultsInvalidated()
// makes LauncherService re-run the live query. The UI thread never blocks.
BaseProvider {
    id: root

    name: "Calculator"
    priority: 100   // high priority
    prefixes: ["="]

    // Single-slot cache: expression -> built result rows (errors included).
    property string _cachedExpr: ""
    property var _cachedRows: null

    // Expression currently awaiting evaluation (dedupes repeat requests).
    property string _inflightExpr: ""
    // Whether the query that requested it carried the explicit "=" prefix.
    property bool _inflightHadPrefix: false

    readonly property Connections _evalWatch: Connections {
        target: QalculateWrapper
        function onEvaluated(expression, result) {
            if (expression !== root._inflightExpr)
                return
            root._inflightExpr = ""
            root._cachedExpr = expression.trim()
            root._cachedRows = root._buildRows(expression, result, root._inflightHadPrefix)
            root.resultsInvalidated()
        }
    }

    function search(query) {
        const expr = removePrefix(query)
        const normalized = expr ? expr.trim() : ""

        if (!normalized) {
            _cachedExpr = ""
            _cachedRows = null
            _inflightExpr = ""
            return []
        }

        if (normalized === _cachedExpr && _cachedRows !== null)
            return _cachedRows

        if (_inflightExpr !== expr) {
            _inflightExpr = expr
            _inflightHadPrefix = query.startsWith("=")
            QalculateWrapper.evalAsync(expr, false)
        }

        // Stale-but-instant: previous rows until `evaluated` lands.
        return _cachedRows ?? []
    }

    function _buildRows(expr, result, hadPrefix) {
        const normalized = expr.trim()

        if (!result || result.startsWith("error:") || result.startsWith("warning:")) {
            // Surface the error only under the explicit "=" prefix.
            if (hadPrefix) {
                return [{
                    id: "calculator:error:" + normalized,
                    text: "Error",
                    description: result || "Invalid expression",
                    icon: "dialog-error",
                    type: "calculator",
                    score: 0,
                    action: function() {}
                }]
            }
            return []
        }

        return [{
            id: "calculator:" + normalized,
            text: result,
            description: normalized + " = " + result,
            icon: "accessories-calculator",
            type: "calculator",
            score: 100,
            data: { result: result, expression: normalized },
            action: function() {
                Quickshell.clipboardText = result
            }
        }]
    }
}
