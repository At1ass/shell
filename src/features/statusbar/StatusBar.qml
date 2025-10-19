import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.src.core.config
import qs.src.features.dashboard
import qs.src.ui.containers
import qs.src.ui.containers
import qs.src.ui.feedback
import qs.src.ui.feedback
import qs.src.ui.inputs

PanelWindow {
    id: statusBar

    // property var modelData: parent.modelData
    // Tooltip Manager
    readonly property TooltipManager tooltip: tooltipManager

    // screen: modelData
    implicitHeight: Config.bar.height
    color: "transparent"

    exclusiveZone: implicitHeight
	WlrLayershell.namespace: "shell:bar"

    // Position on top edge
    anchors {
        left: true
        top: true
        right: true
    }

    TooltipManager {
        id: tooltipManager

        bar: statusBar
    }

    Rectangle {
        id: barBackground

        anchors.fill: parent
        color: Config.colors.surfaceContainer
        opacity: Config.bar.backgroundOpacity

        // Primary surface tint
        Rectangle {
            anchors.fill: parent
            color: Config.colors.primary
            opacity: Config.elevation.level2Opacity
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

            WorkspaceWidget {
            }

        }

        // Center section - Clock and MPRIS (absolute positioning)
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

            // MPRIS Widget (only on main monitor DP-2)
            MPRISWidget {
                visible: statusBar.screen.name === "DP-2"
                tooltipManager: statusBar.tooltip
            }

            VolumeWidget {
                tooltipManager: statusBar.tooltip
            }

            LayoutWidget {
            }
        }

    }
}
