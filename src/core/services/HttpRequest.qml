pragma ComponentBehavior: Bound

import QtQuick

// Qt's XHR is Level 1: timeout/onerror are not browser-compatible APIs.
// One owned request, one real deadline, and no callbacks after cancellation.
QtObject {
    id: root
    property int timeoutMs: 15000
    property var _request: null
    readonly property bool running: _request !== null
    signal succeeded(string body)
    signal failed(string message, int status)

    readonly property Timer _deadline: Timer {
        interval: Math.max(1, root.timeoutMs)
        onTriggered: {
            root.cancel()
            root.failed("Request timeout", 0)
        }
    }

    function cancel() {
        _deadline.stop()
        const previous = _request
        _request = null
        if (previous) {
            previous.onreadystatechange = null
            previous.abort()
        }
    }

    function get(url) {
        root.cancel()
        const xhr = new XMLHttpRequest()
        root._request = xhr
        xhr.onreadystatechange = function() {
            if (root._request !== xhr || xhr.readyState !== XMLHttpRequest.DONE) return
            root._deadline.stop()
            root._request = null
            xhr.onreadystatechange = null
            if (xhr.status >= 200 && xhr.status < 300)
                root.succeeded(xhr.responseText)
            else
                root.failed(xhr.status === 0 ? "Network error" : "HTTP " + xhr.status, xhr.status)
        }
        try {
            xhr.open("GET", url, true)
            root._deadline.restart()
            xhr.send()
        } catch (e) {
            root.cancel()
            root.failed("Request failed: " + e.message, 0)
        }
    }

    Component.onDestruction: root.cancel()
}
