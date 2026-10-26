import QtQuick
import qs.src.core.config

// One persisted flag and optional absolute deadline, independent of UI lifetime.
QtObject {
    id: root
    required property string section
    property string enabledKey: "enabled"
    readonly property var modeState: AppConfig.stateData?.[section] ?? ({})
    readonly property bool storedEnabled: modeState[enabledKey] === true
    readonly property real expiresAt: {
        const value = Number(modeState.expiresAt ?? 0)
        return Number.isFinite(value) && value >= 0 && value <= 8640000000000000 ? value : -1
    }
    property real _now: Date.now()
    readonly property bool enabled: AppConfig.stateReady && storedEnabled
        && (expiresAt === 0 || expiresAt > _now)
    readonly property bool temporary: enabled && expiresAt > 0
    readonly property string statusText: temporary
        ? "Until " + Qt.formatDateTime(new Date(expiresAt), "ddd HH:mm") : ""

    onModeStateChanged: { _now = Date.now(); Qt.callLater(refresh) }
    Component.onCompleted: refresh()

    function setEnabled(on) {
        const fields = {expiresAt:0}
        fields[enabledKey] = !!on
        if (!AppConfig.stateReady || storedEnabled !== !!on || expiresAt !== 0) AppConfig.updateState(section, fields)
    }
    function start(minutes) {
        if (!Number.isInteger(minutes) || minutes < 1 || minutes > 1440) return false
        const fields = {expiresAt:Date.now() + minutes * 60000}
        fields[enabledKey] = true
        AppConfig.updateState(section, fields)
        return true
    }
    function refresh() {
        _now = Date.now()
        expiryTimer.stop()
        if (!AppConfig.stateReady || !storedEnabled || expiresAt === 0) return
        if (expiresAt <= _now) { Qt.callLater(expireIfNeeded); return }
        expiryTimer.interval = Math.min(2147483647, Math.max(1, expiresAt - _now))
        expiryTimer.start()
    }
    function expireIfNeeded() {
        _now = Date.now()
        // Re-read current state: a manual action can supersede a queued expiry.
        if (AppConfig.stateReady && storedEnabled && expiresAt !== 0 && expiresAt <= _now)
            setEnabled(false)
    }
    readonly property Timer expiryTimer: Timer { onTriggered: root.refresh() }
    readonly property Connections stateWatch: Connections {
        target: AppConfig
        function onStateReadyChanged() { root.refresh() }
    }
    readonly property Connections clockWatch: Connections {
        enabled: root.storedEnabled && root.expiresAt !== 0
        target: DateTime.clock
        function onDateChanged() { root.refresh() }
    }
    readonly property Connections resumeWatch: Connections {
        enabled: root.storedEnabled && root.expiresAt !== 0
        target: SessionMonitor
        function onResumed() { root.refresh() }
    }
}
