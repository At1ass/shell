import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../widgets"

PanelWindow {
    id: statusBar

    property var modelData: parent.modelData
    screen: modelData

    // Position on top edge
    anchors {
        left: true
        top: true
        right: true
    }

    margins {
        left: 16
        top: 8
        right: 16
    }

    implicitHeight: 48
    color: "transparent"
    // exclusionMode: ExclusionMode.Exclusive

    Rectangle {
        id: barBackground
        anchors.fill: parent
        color: "#1c1b1f"
        radius: 16
        opacity: 0.96

        // Primary surface tint
        Rectangle {
            anchors.fill: parent
            color: "#d0bcff"
            opacity: 0.05
            radius: parent.radius
        }

        RowLayout {
            id: barLayout
            anchors.fill: parent
            anchors.margins: 8
            spacing: 16

            // Left section - Workspaces
            WorkspaceWidget {
                Layout.alignment: Qt.AlignVCenter
            }

            // Middle section - Clock (centered)
            Item {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter

                ClockWidget {
                    anchors.centerIn: parent
                }
            }

            // Right section - System info
            Row {
                spacing: 12
                Layout.alignment: Qt.AlignVCenter

                SystemWidget {}
                TrayWidget {}
            }
        }
    }

    // Remove hover overlay - not needed
}