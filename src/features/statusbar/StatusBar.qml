pragma ComponentBehavior: Bound
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
    readonly property var barWidgets: AppConfig.ready ? (AppConfig.barWidgets || []) : []
    readonly property string screenName: screen ? screen.name : ""
    // property ShellScreen screen: null
    property var popouts: null

    implicitHeight: AppConfig.barHeight
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
        color: Qt.alpha(Theme.surfaceContainer, 0.90)
        // Primary surface tint - more visible
        Rectangle {
            anchors.fill: parent
            color: Theme.primary
            opacity: 0.12  // Increased from 0.08 to 0.12
            radius: parent.radius
        }

        // Left section
        Item {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            // anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Tokens.spacing.small
            width: leftSection.implicitWidth
            RowLayout {
                id: leftSection
                spacing: Tokens.spacing.small
                // Layout.alignment: Qt.AlignVCenter
                anchors.verticalCenter: parent.verticalCenter
                // anchors.: parent

                Repeater {
                    model: {
                        const widgets = statusBar.barWidgets;
                        return widgets.filter(w => (w.section || "left") === "left");
                    }

                    delegate: BarWidgetLoader {
                        required property var modelData

                        screenName: statusBar.screenName
                        widgetConfig: modelData
                        tooltipManager: statusBar.tooltip
                        popouts: statusBar.popouts
                    }
                }
            }
        }

        // Center section
        Item {
            anchors.centerIn: parent
            width: centerSection.implicitWidth
            RowLayout {
                id: centerSection
                spacing: Tokens.spacing.small
                anchors.verticalCenter: parent.verticalCenter

                Repeater {
                    model: {
                        const widgets = statusBar.barWidgets;
                        return widgets.filter(w => (w.section || "left") === "center");
                    }

                    delegate: BarWidgetLoader {
                        required property var modelData

                        screenName: statusBar.screenName
                        widgetConfig: modelData
                        tooltipManager: statusBar.tooltip
                        popouts: statusBar.popouts
                    }
                }
            }
        }

        // Right section
        Item {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.rightMargin: Tokens.spacing.small
            width: rightSection.implicitWidth
            RowLayout {
                id: rightSection
                spacing: Tokens.spacing.small
                anchors.verticalCenter: parent.verticalCenter

                Repeater {
                    model: {
                        const widgets = statusBar.barWidgets;
                        return widgets.filter(w => (w.section || "left") === "right");
                    }

                    delegate: BarWidgetLoader {
                        required property var modelData

                        screenName: statusBar.screenName

                        widgetConfig: modelData
                        tooltipManager: statusBar.tooltip
                        popouts: statusBar.popouts
                    }
                }
            }
        }
    }
}
