pragma Singleton
import QtQuick
import Quickshell
import GreeterData 1.0

Singleton {
    id: root
    readonly property var sessions: GreeterDataBackend.sessions
    readonly property list<string> names: GreeterDataBackend.sessionNames
    readonly property bool ready: GreeterDataBackend.ready
    readonly property string errorString: ready && sessions.length === 0 ? GreeterDataBackend.errorString : ""
    property int selectedIndex: 0
    property string _selectedId: ""
    property bool _defaultApplied: false
    readonly property var currentSession: sessions[selectedIndex] ?? null

    onSelectedIndexChanged: _selectedId = sessions[selectedIndex]?.id ?? ""
    onSessionsChanged: {
        const previous = GreeterDataBackend.sessionIndex(_selectedId)
        selectedIndex = previous >= 0 ? previous : 0
        _selectedId = sessions[selectedIndex]?.id ?? ""
        applyDefault()
    }
    function applyDefault() {
        if (_defaultApplied || !ready || !GreeterConfig.ready || sessions.length === 0) return
        _defaultApplied = true
        const preferred = GreeterDataBackend.sessionIndex(GreeterConfig.defaultSession)
        if (preferred >= 0) selectedIndex = preferred
        _selectedId = sessions[selectedIndex]?.id ?? ""
    }
    Connections { target: GreeterConfig; function onReadyChanged() { root.applyDefault() } }
    onReadyChanged: applyDefault()
    Component.onCompleted: applyDefault()
}
