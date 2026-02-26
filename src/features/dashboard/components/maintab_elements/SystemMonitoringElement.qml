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
                clip: true

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
                        case "cpu":  return SystemMonitorService.cpuTemp + "\u00B0";
                        case "gpu":  return SystemMonitorService.gpuTemp + "\u00B0";
                        case "ram":  return SystemMonitorService.ramUsed + "G";
                        case "disk": return SystemMonitorService.diskUsed;
                    }
                }

                property string subtitle: {
                    switch (modelData.type) {
                        case "cpu":  return SystemMonitorService.cpuModel;
                        case "gpu":  return SystemMonitorService.gpuModel;
                        case "ram":  return SystemMonitorService.ramTotal + "G";
                        case "disk": return SystemMonitorService.diskTotal;
                    }
                }

                property var historyValues: {
                    switch (modelData.type) {
                        case "cpu":  return SystemMonitorService.cpuHistory;
                        case "gpu":  return SystemMonitorService.gpuHistory;
                        case "ram":  return SystemMonitorService.ramHistory;
                        case "disk": return [];
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

                // Sparkline background — fills bottom portion
                Sparkline {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: parent.height * 0.55
                    values: historyValues
                    lineColor: Qt.rgba(thresholdColor.r, thresholdColor.g, thresholdColor.b, 0.3)
                    fillColor: Qt.rgba(thresholdColor.r, thresholdColor.g, thresholdColor.b, 0.08)
                    lineWidth: 1
                    visible: historyValues.length > 1
                }

                // Color-coded left border
                Rectangle {
                    width: 3
                    height: parent.height
                    radius: Tokens.shape.small
                    color: parent.thresholdColor
                    anchors.left: parent.left
                }

                // Two-line content
                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Tokens.spacing.medium
                    anchors.rightMargin: Tokens.spacing.small
                    anchors.topMargin: Tokens.spacing.small
                    anchors.bottomMargin: Tokens.spacing.small
                    spacing: 2

                    // Line 1: icon + label + percent + extra
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            iconName: modelData.icon
                            fontSize: 16
                            iconColor: Theme.onSurfaceVariant
                            backgroundColor: "transparent"
                        }

                        Item { Layout.fillWidth: true }

                        MaterialText {
                            text: Math.round(currentPercent) + "%"
                            textStyle: "titleMedium"
                            colorRole: "onSurface"
                            font.weight: Font.Bold
                        }

                        MaterialText {
                            text: currentExtra
                            textStyle: "labelMedium"
                            colorRole: "onSurfaceVariant"
                        }
                    }

                    // Line 2: subtitle (model name / total)
                    MaterialText {
                        Layout.fillWidth: true
                        text: subtitle
                        textStyle: "labelSmall"
                        colorRole: "onSurfaceVariant"
                        opacity: 0.7
                        elide: Text.ElideMiddle
                    }
                }
            }
        }
    }
}
