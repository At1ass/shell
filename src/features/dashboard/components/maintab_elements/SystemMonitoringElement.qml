import QtQuick
import QtQuick.Layouts
import qs.src.ui.base
import qs.src.core.config
import qs.src.core.services

Item {
    RowLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.small

        Repeater {
            model: [
                { icon: "developer_board", type: "cpu" },
                { icon: "videogame_asset", type: "gpu" },
                { icon: "memory",          type: "ram" },
                { icon: "storage",         type: "disk" }
            ]

            delegate: Rectangle {
                required property var modelData

                visible: modelData.type !== "gpu" || SystemMonitorService.hasGpuStats
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Tokens.shape.small
                color: Theme.surfaceContainerHighest

                property real currentPercent: {
                    switch (modelData.type) {
                        case "cpu":  return SystemMonitorService.cpuUsage;
                        case "gpu":  return SystemMonitorService.gpuUsage;
                        case "ram":  return SystemMonitorService.ramUsage;
                        case "disk": return SystemMonitorService.diskUsage;
                    }
                }

                property string currentExtra: {
                    switch (modelData.type) {
                        case "cpu":  return SystemMonitorService.cpuTemp + "°";
                        case "gpu":  return SystemMonitorService.gpuTemp + "°";
                        case "ram":  return SystemMonitorService.ramUsed + "G";
                        case "disk": return SystemMonitorService.diskUsed;
                    }
                }

                property real animatedProgress: currentPercent / 100
                property color thresholdColor: {
                    if (animatedProgress < 0.5) return Theme.primary;
                    if (animatedProgress < 0.8) return Theme.tertiary;
                    return Theme.error;
                }

                Behavior on animatedProgress {
                    NumberAnimation {
                        duration: Tokens.motion.duration.long2
                        easing.type: Tokens.motion.easing.emphasizedDecelerate
                    }
                }

                Behavior on thresholdColor {
                    ColorAnimation { duration: Tokens.motion.duration.medium2 }
                }

                // Color-coded left border
                Rectangle {
                    width: 4
                    height: parent.height
                    radius: Tokens.shape.small
                    color: parent.thresholdColor
                    anchors.left: parent.left
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Tokens.spacing.medium
                    anchors.rightMargin: Tokens.spacing.small
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        iconName: modelData.icon
                        fontSize: 16
                        iconColor: Theme.onSurfaceVariant
                        backgroundColor: "transparent"
                    }

                    MaterialText {
                        text: Math.round(currentPercent) + "%"
                        textStyle: "labelMedium"
                        colorRole: "onSurface"
                        font.weight: Font.Medium
                    }

                    MaterialText {
                        text: currentExtra
                        textStyle: "labelSmall"
                        colorRole: "onSurfaceVariant"
                    }
                }
            }
        }
    }
}
