import QtQuick
import Quickshell
import Qalculate

// Math evaluation provider backed by libqalculate.
BaseProvider {
    id: root

    name: "Calculator"
    priority: 100   // high priority
    prefixes: ["="]

    // Throttle cache: QalculateWrapper.eval is synchronous on the UI thread,
    // so rapid typing must not evaluate every keystroke. Errors are cached
    // like results (per project convention).
    property string _lastQuery: ""
    property var _lastResult: null
    property real _lastEvalTime: 0
    readonly property int _throttleMs: 150

    // Trailing edge: when a keystroke lands inside the throttle window the
    // stale result is shown — this timer re-runs the search afterwards so
    // the FINAL expression always gets evaluated ("=2+2" typed fast used to
    // stick at the result of "=2+").
    property bool _trailingPending: false
    readonly property Timer _trailingTimer: Timer {
        interval: root._throttleMs
        onTriggered: {
            if (root._trailingPending) {
                root._trailingPending = false
                root.resultsInvalidated()
            }
        }
    }

    function search(query) {
        let expr = removePrefix(query)
        let normalizedExpr = expr ? expr.trim() : ""

        if (!normalizedExpr) {
            _lastQuery = ""
            _lastResult = null
            return []
        }

        // Same expression — serve the cached result (including cached errors).
        if (normalizedExpr === _lastQuery && _lastResult !== null) {
            return _lastResult
        }

        // Inside the throttle window — serve the previous result and arm the
        // trailing re-evaluation.
        const now = Date.now()
        if (now - _lastEvalTime < _throttleMs && _lastResult !== null) {
            _trailingPending = true
            _trailingTimer.restart()
            return _lastResult
        }

        _lastEvalTime = now
        _lastQuery = normalizedExpr
        _trailingPending = false

        let result = QalculateWrapper.eval(expr, false)

        if (!result || result.startsWith("error:") || result.startsWith("warning:")) {
            // Surface the error only under the explicit "=" prefix.
            if (query.startsWith("=")) {
                const errorResult = [{
                    id: "calculator:error:" + normalizedExpr,
                    text: "Error",
                    description: result || "Invalid expression",
                    icon: "dialog-error",
                    type: "calculator",
                    score: 0,
                    action: function() {}
                }]
                _lastResult = errorResult
                return errorResult
            }
            _lastResult = []
            return []
        }

        const successResult = [{
            id: "calculator:" + normalizedExpr,
            text: result,
            description: expr + " = " + result,
            icon: "accessories-calculator",
            type: "calculator",
            score: 100,
            data: { result: result, expression: expr },
            action: function() {
                Quickshell.clipboardText = result
            }
        }]

        _lastResult = successResult
        return successResult
    }
}
