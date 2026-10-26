pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import QtQuick.Layouts
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.ui.feedback
import qs.src.ui.inputs
import qs.src.core.config
import qs.src.core.services

// Audio device picker. The device list and the "active" marker are LIVE
// bindings into AudioService — a snapshot taken at open time went stale the
// moment a device (un)plugged, and retained dead PwNode refs after close.
Dialog {
    id: root
    dialogWidth: Tokens.size.fieldWidth * 2

    property string dialogTitle: "Select Device"
    property string deviceType: "output"  // "output" or "input"

    readonly property var devices: deviceType === "output"
        ? AudioService.sinkNodes
        : AudioService.sourceNodes
    readonly property var activeDevice: deviceType === "output"
        ? AudioService.defaultSink
        : AudioService.defaultSource

    signal deviceSelected(var device)
    // Fires only when the dialog closes WITHOUT a selection.
    signal cancelled()

    property bool _selectionMade: false

    onClosed: {
        if (!_selectionMade) cancelled()
        _selectionMade = false
    }

    function openDialog(title, type) {
        root.dialogTitle = title || "Select Device"
        root.deviceType = type || "output"
        root._selectionMade = false
        root.open()
    }

    ColumnLayout {
        id: contentLayout
        anchors.fill: parent
        anchors.margins: Tokens.spacing.large
        spacing: Tokens.spacing.medium

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            MaterialIcon {
                iconName: root.deviceType === "output" ? "volume_up" : "mic"
                fontSize: Tokens.typography.headlineMedium.size
                iconColor: Theme.primary
                backgroundColor: "transparent"
            }

            MaterialText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: root.dialogTitle
                textStyle: "titleMedium"
                colorRole: "onSurface"
                font.weight: Font.Bold
            }
        }

        // Device list
        ScrollableList {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Tokens.spacing.small

            Repeater {
                id: devicesRepeater
                model: ScriptModel {
                    values: root.devices
                    objectProp: "id"
                }

                delegate: ListItem {
                    id: deviceRow
                    required property var modelData
                    required property int index
                    Keys.onPressed: event => {
                        let next = deviceRow.index
                        if (event.key === Qt.Key_Down) next++
                        else if (event.key === Qt.Key_Up) next--
                        else if (event.key === Qt.Key_Home) next = 0
                        else if (event.key === Qt.Key_End) next = devicesRepeater.count - 1
                        else return
                        const row = devicesRepeater.itemAt(Math.max(0, Math.min(devicesRepeater.count - 1, next)))
                        if (row) row.forceActiveFocus(Qt.TabFocusReason)
                        event.accepted = true
                    }
                    // PwNode refs can die under the dialog (device unplug);
                    // every access below is null-tolerant.
                    readonly property var device: deviceRow.modelData
                    readonly property bool isSelected: (deviceRow.device?.id ?? -1) === (root.activeDevice?.id ?? -2)

                    Layout.fillWidth: true
                    radius: Tokens.shape.medium
                    color: deviceRow.isSelected ? Theme.secondaryContainer : "transparent"
                    headline: deviceRow.device?.description || deviceRow.device?.name || "Unknown Device"
                    supportingText: deviceRow.isSelected ? "Active" : ""
                    trailingIcon: deviceRow.isSelected ? "check" : ""
                    trailingIconColor: Theme.primary

                    leadingContent: [
                        MaterialRadioButton {
                            activeFocusOnTab: false
                            checked: deviceRow.isSelected
                            onClicked: deviceRow._choose()
                        }
                    ]

                    onClicked: deviceRow._choose()

                    function _choose() {
                        if (!deviceRow.device) return
                        root._selectionMade = true
                        root.deviceSelected(deviceRow.device)
                        root.close()
                    }
                }
            }

            // Empty state
            EmptyState {
                visible: root.devices.length === 0
                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight + Tokens.spacing.medium * 2

                iconName: root.deviceType === "output" ? "speaker_notes_off" : "mic_off"
                title: "No devices available"
                iconContainerSize: Tokens.iconSize.extraLarge * 2
                iconSize: Tokens.iconSize.large
            }
        }

        // Cancel button
        MaterialButton {
            Layout.fillWidth: true
            text: "Cancel"
            variant: "text"
            onClicked: root.close()
        }
    }
}
