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

        RowLayout {
            spacing: Config.spacing.small

            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                bottom: parent.bottom
                leftMargin: Config.spacing.medium
                rightMargin: Config.spacing.medium
            }

        // Left section
        RowLayout {
            spacing: Config.spacing.small
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            // anchors.left: parent.left
            // anchors.leftMargin: Config.spacing.medium
            // anchors.verticalCenter: parent.verticalCenter

            Repeater {
                model: {
                    let widgets = Config.ready ? (Config.data.bar?.widgets || Config.bar.entries) : Config.bar.entries;
                    return widgets.filter(w => (w.section || "left") === "left");
                }

                delegate: Item {
                    implicitHeight: loaderLeft.item?.implicitHeight ?? 0
                    implicitWidth: loaderLeft.item?.implicitWidth ?? 0
                    Layout.alignment: Qt.AlignVCenter

                    BarWidgetLoader {
                        id: loaderLeft
                        anchors.verticalCenter: parent.verticalCenter
                        widgetConfig: modelData
                        tooltipManager: statusBar.tooltip
                    }
                }
            }
        }

        // Left spacer
        // Item {
        //     Layout.fillWidth: true
        // }

        // Center section
        RowLayout {
            spacing: Config.spacing.small
            // Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            anchors.centerIn: parent
            // anchors.leftMargin: Config.spacing.medium
            // anchors.verticalCenter: parent.verticalCenter

            Repeater {
                model: {
                    let widgets = Config.ready ? (Config.data.bar?.widgets || Config.bar.entries) : Config.bar.entries;
                    return widgets.filter(w => (w.section || "left") === "center");
                }

                delegate: Item {
                    implicitHeight: loaderCenter.item?.implicitHeight ?? 0
                    implicitWidth: loaderCenter.item?.implicitWidth ?? 0

                    BarWidgetLoader {
                        id: loaderCenter
                        anchors.verticalCenter: parent.verticalCenter
                        widgetConfig: modelData
                        tooltipManager: statusBar.tooltip
                    }
                }
            }
        }

        // Right spacer
        // Item {
        //     Layout.fillWidth: true
        // }

        // Right section
        RowLayout {
            spacing: Config.spacing.small
            // Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            // Layout.fillWidth: true
            // anchors.centerIn: parent
            // anchors.right: parent.right
            // anchors.left: parent.left
            // anchors.rightMargin: Config.spacing.medium
            // anchors.verticalCenter: parent.verticalCenter
            // MPRISWidget {
            //     visible: statusBar.screen.name === "DP-2"
            //     tooltipManager: statusBar.tooltip
            // }
            //
            // VolumeWidget {
            //     tooltipManager: statusBar.tooltip
            // }
            //
            // LayoutWidget {
            // }
            Repeater {
                model: {
                    let widgets = Config.ready ? (Config.data.bar?.widgets || Config.bar.entries) : Config.bar.entries;
                    return widgets.filter(w => (w.section || "left") === "right");
                }
                Layout.fillWidth: true

                delegate: Item {
                    implicitHeight: loaderRight.item?.implicitHeight ?? 0
                    implicitWidth: loaderRight.item?.implicitWidth ?? 0

                    BarWidgetLoader {
                        id: loaderRight
                        anchors.verticalCenter: parent.verticalCenter
                        widgetConfig: modelData
                        tooltipManager: statusBar.tooltip
                    }
                }
            }
        }
    }
    }
}
