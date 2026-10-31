pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io

// Outgoing shell notices use the same notification server and policy as apps.
// At most one call and one latest pending notice; no subprocess polling.
QtObject {
    id: root
    property string appName: "Timer"
    readonly property bool running: transport.running
    readonly property var command: transport.command
    property int starts: 0
    property var _pending: null
    signal delivered(int exitCode)
    function cancelPending() { _pending=null }
    function cancelAbove(urgency) { if(_pending && _pending.urgency>urgency)_pending=null }
    function send(summary, body, urgency) {
        const notice={summary:summary,body:body,urgency:urgency===2 ? 2 : 1}
        if (running) {
            if (!_pending || notice.urgency>=_pending.urgency) _pending=notice
            return
        }
        transport.command=["gdbus","call","--session","--timeout","5",
            "--dest","org.freedesktop.Notifications","--object-path","/org/freedesktop/Notifications",
            "--method","org.freedesktop.Notifications.Notify","--",JSON.stringify(appName),"0",
            JSON.stringify("appointment-soon"),JSON.stringify(summary),JSON.stringify(body),"[]",
            notice.urgency===2 ? "{'urgency': <byte 2>}" : "{}","-1"]
        ++starts
        transport.running=true
    }
    function flushPending() {
        if (running || !_pending) return
        const notice=_pending;_pending=null
        send(notice.summary,notice.body,notice.urgency)
    }
    readonly property Process transport: Process {
        onExited: exitCode => { root.delivered(exitCode);Qt.callLater(root.flushPending) }
    }
}
