import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.src.core.config
import qs.src.features.dashboard
import qs.src.features.statusbar
import qs.src.ui.containers
import qs.src.ui.feedback
import qs.src.ui.inputs

PanelWindow {
    id: statusBar

    readonly property TooltipManager tooltip: tooltipManager
    readonly property var barWidgets: Config.ready ? (Config.data.bar?.widgets || []) : []
    property var popouts: null


    implicitHeight: Config.bar.height
    color: "transparent"

    exclusiveZone: implicitHeight
    WlrLayershell.namespace: "shell:bar"

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

            // Left section
            RowLayout {
                spacing: Config.spacing.small
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Config.spacing.small

                Repeater {
                    model: {
                        const widgets = statusBar.barWidgets
                        return widgets.filter(w => (w.section || "left") === "left")
                    }

                    delegate: BarWidgetLoader {
                        required property var modelData

                        widgetConfig: modelData
                        tooltipManager: statusBar.tooltip
                        popouts: statusBar.popouts
                    }
                }
            }

            // Center section
            RowLayout {
                spacing: Config.spacing.small
                anchors.centerIn: parent

                Repeater {
                    model: {
                        const widgets = statusBar.barWidgets
                        return widgets.filter(w => (w.section || "left") === "center")
                    }

                    delegate: BarWidgetLoader {
                        required property var modelData

                        widgetConfig: modelData
                        tooltipManager: statusBar.tooltip
                        popouts: statusBar.popouts
                    }
                }
            }

            // Right section
            RowLayout {
                spacing: Config.spacing.small
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: Config.spacing.small

                Repeater {
                    model: {
                        const widgets = statusBar.barWidgets
                        return widgets.filter(w => (w.section || "left") === "right")
                    }

                    delegate: BarWidgetLoader {
                        required property var modelData

                        widgetConfig: modelData
                        tooltipManager: statusBar.tooltip
                        popouts: statusBar.popouts
                    }
                }
            }
        }
}
