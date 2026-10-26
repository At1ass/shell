pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.src.core.config
import qs.src.core.services
import qs.src.ui.base
import qs.src.ui.containers

MaterialCard {
    id: root
    signal closeRequested()
    property bool mixerExpanded: false
    readonly property bool active: GlobalStates.audioOpen && root.visible
    readonly property bool modalOpen: outputPicker.visible || inputPicker.visible
    implicitWidth: AppConfig.audioWidth
    implicitHeight: column.implicitHeight + Tokens.panelPadding * 2
    color: Theme.surfaceContainer
    radius: Tokens.shape.large
    function reset() {
        root.mixerExpanded = false
        if (outputPicker.visible) outputPicker.close()
        if (inputPicker.visible) inputPicker.close()
    }
    function focusInitial() {
        if (AudioService.defaultSink) output.focusInitial()
        else if (AudioService.defaultSource) microphone.focusInitial()
        else closeButton.forceActiveFocus(Qt.TabFocusReason)
    }
    onActiveChanged: if (!active) root.reset()
    Keys.onEscapePressed: event => {
        if (!root.modalOpen) {
            if (root.mixerExpanded) { root.mixerExpanded = false; applications.forceActiveFocus() }
            else root.closeRequested()
        }
        event.accepted = true
    }
    ScrollableList {
        anchors.fill: parent
        contentPadding: Tokens.panelPadding
        ColumnLayout {
            id: column
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium
            RowLayout {
                Layout.fillWidth: true
                MaterialText { Layout.fillWidth: true; text: "Audio"; textStyle: "titleMedium" }
                IconButton { id: closeButton; iconName: "close"; Accessible.name: "Close audio"; onClicked: root.closeRequested() }
            }
            AudioLevel {
                id: output
                Layout.fillWidth: true
                title: "Output"
                deviceName: AudioService.defaultSink?.description || AudioService.defaultSink?.name || "No output device"
                available: AudioService.defaultSink !== null
                volume: AudioService.masterVolume
                muted: AudioService.masterMuted
                onVolumeRequested: value => AudioService.setMasterVolume(value)
                onMuteRequested: AudioService.toggleMasterMute()
                onDeviceRequested: outputPicker.openDialog("Output device", "output")
            }
            AudioLevel {
                id: microphone
                Layout.fillWidth: true
                title: "Microphone"
                icon: "mic"
                mutedIcon: "mic_off"
                deviceName: AudioService.defaultSource?.description || AudioService.defaultSource?.name || "No input device"
                available: AudioService.defaultSource !== null
                volume: AudioService.micVolume
                muted: AudioService.micMuted
                onVolumeRequested: value => AudioService.setMicVolume(value)
                onMuteRequested: AudioService.toggleMicMute()
                onDeviceRequested: inputPicker.openDialog("Input device", "input")
            }
            ListItem {
                id: applications
                Layout.fillWidth: true
                headline: "Applications"
                supportingText: AudioService.streamNodes.length > 0 ? AudioService.streamNodes.length + " active streams" : "No active streams"
                leadingIcon: "graphic_eq"
                trailingIcon: root.mixerExpanded ? "expand_less" : "expand_more"
                margin: Tokens.spacing.small
                radius: Tokens.shape.small
                onClicked: root.mixerExpanded = !root.mixerExpanded
            }
            Repeater {
                model: ScriptModel { values: root.active && root.mixerExpanded ? AudioService.streamNodes : [] }
                delegate: AudioStreamRow {
                    required property var modelData
                    Layout.fillWidth: true
                    stream: modelData
                }
            }
            MaterialText {
                Layout.fillWidth: true
                visible: root.mixerExpanded && AudioService.streamNodes.length === 0
                text: "Play something to adjust application volume."
                textStyle: "bodySmall"
                colorRole: "onSurfaceVariant"
                wrapMode: Text.WordWrap
            }
        }
    }
    AudioDevicePicker {
        id: outputPicker
        onDeviceSelected: device => AudioService.setDefaultSink(device)
    }
    AudioDevicePicker {
        id: inputPicker
        onDeviceSelected: device => AudioService.setDefaultSource(device)
    }
}
