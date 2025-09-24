import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.widgets
import qs.components.sections
import qs.config

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
        left: Config.spacing.medium
        top: Config.spacing.small
        right: Config.spacing.medium
    }

    implicitHeight: Config.bar.height
    color: "transparent"

    Rectangle {
        id: barBackground
        anchors.fill: parent
        color: Config.colors.surfaceContainer
        radius: Config.shape.extraLarge
        opacity: Config.bar.backgroundOpacity

        // Primary surface tint
        Rectangle {
            anchors.fill: parent
            color: Config.colors.primary
            opacity: 0.05
            radius: parent.radius
        }

        // Left section - Workspaces
        LeftBarSection {
            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
                leftMargin: Config.spacing.medium
            }

            WorkspaceWidget {}
        }

        // Center section - Clock (absolute positioning)
        ClockWidget {
            anchors.centerIn: parent
        }

        // Right section - System info
        RightBarSection {
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
                rightMargin: Config.spacing.medium
            }

            Row {
                spacing: Config.spacing.small
                SystemWidget {}
                TrayWidget {}
            }
        }
    }
}
