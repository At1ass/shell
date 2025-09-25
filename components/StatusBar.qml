import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.widgets
import qs.components.sections
import qs.components.tooltip
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

    // Tooltip Manager
    readonly property TooltipManager tooltip: tooltipManager
    TooltipManager {
        id: tooltipManager
        bar: statusBar
    }

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
        BarSection {
            alignment: "left"
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
            tooltipManager: statusBar.tooltip
        }

        // Right section - System info
        BarSection {
            alignment: "right"
            spacingToken: "small"
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
                rightMargin: Config.spacing.medium
            }

            LayoutWidget {}
            SystemWidget {}
            TrayWidget {
                tooltipManager: statusBar.tooltip
            }
        }
    }
}
