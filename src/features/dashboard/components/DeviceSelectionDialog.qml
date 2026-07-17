import QtQuick
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
    dialogWidth: Math.min(500, parent.width - Tokens.spacing.large * 2)

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
                text: root.dialogTitle
                textStyle: "headlineSmall"
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
                model: root.devices

                delegate: ListItem {
                    required property var modelData
                    // PwNode refs can die under the dialog (device unplug);
                    // every access below is null-tolerant.
                    readonly property var device: modelData
                    readonly property bool isSelected: (device?.id ?? -1) === (root.activeDevice?.id ?? -2)

                    Layout.fillWidth: true
                    radius: Tokens.shape.medium
                    color: isSelected ? Theme.secondaryContainer : "transparent"
                    headline: device?.description || device?.name || "Unknown Device"
                    supportingText: isSelected ? "Active" : ""
                    trailingIcon: isSelected ? "check" : ""
                    trailingIconColor: Theme.primary

                    leadingContent: [
                        MaterialRadioButton {
                            checked: isSelected
                            onClicked: {
                                if (!device) return
                                root._selectionMade = true
                                root.deviceSelected(device)
                                root.close()
                            }
                        }
                    ]

                    onClicked: {
                        if (!device) return
                        root._selectionMade = true
                        root.deviceSelected(device)
                        root.close()
                    }
                }
            }

            // Empty state
            EmptyState {
                visible: root.devices.length === 0
                Layout.fillWidth: true
                Layout.preferredHeight: 120

                iconName: root.deviceType === "output" ? "speaker_notes_off" : "mic_off"
                title: "No devices available"
                iconContainerSize: 64
                iconSize: 40
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
