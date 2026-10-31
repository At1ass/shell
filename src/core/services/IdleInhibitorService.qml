pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import SystemMonitor

// Caffeine owns a confirmed ScreenSaver D-Bus cookie, independently of any
// surface visibility or compositor heuristics. Requested state/deadlines remain
// persisted through TimedMode; actual activation is reported separately.
// TimedMode reads AppConfig.stateData and writes via AppConfig.updateState.
Singleton {
    id: root

    readonly property TimedMode _mode: TimedMode { section: "idleInhibitor" }
    readonly property bool inhibit: _mode.enabled
    readonly property bool temporary: _mode.temporary
    readonly property real expiresAt: temporary ? _mode.expiresAt : 0
    readonly property bool active: backend.active
    readonly property bool pending: backend.pending
    readonly property string errorMessage: backend.error
    readonly property bool canRetry: inhibit && !active && !pending
    readonly property string statusText: !inhibit ? "" : pending ? "Activating…" : active ? _mode.statusText : "Not active"
    onErrorMessageChanged: if (inhibit && errorMessage !== "") ToastService.warning(errorMessage)
    function retry() { return canRetry && backend.retry() }
    function init() { _mode.refresh() }
    function setInhibit(on) { _mode.setEnabled(on) }
    function setForMinutes(minutes) { return _mode.start(minutes) }
    function toggleInhibit() { setInhibit(!inhibit) }

    SessionIdleInhibitor {
        id: backend
        enabled: root.inhibit
    }
    IpcHandler {
        target: "caffeine"
        function retry(): bool { return root.retry() }
        function status(): string {
            return JSON.stringify({requested:root.inhibit,active:root.active,pending:root.pending,
                available:backend.available,error:root.errorMessage,details:backend.details,
                expiresAt:root.expiresAt})
        }
    }
}
