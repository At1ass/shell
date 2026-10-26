pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.src.ui.base
import qs.src.core.config
import qs.src.core.services

// Presentation only. The service retains samples while this lazy view is absent.
ColumnLayout {
    id: root
    spacing: Tokens.spacing.medium

    MaterialText {
        Layout.fillWidth: true
        text: "Recent history · up to 4 minutes · 2 s samples"
        textStyle: "labelSmall"
        colorRole: "onSurfaceVariant"
        wrapMode: Text.Wrap
    }
    GridLayout {
        Layout.fillWidth: true
        columns: root.width >= Tokens.size.fieldWidth * 2 ? 2 : 1
        columnSpacing: Tokens.spacing.large
        rowSpacing: Tokens.spacing.large
        Repeater {
            model: ["cpu", "gpu", "ram"]
            ColumnLayout {
                id: cell
                required property string modelData
                readonly property bool cpu: modelData === "cpu"
                readonly property bool gpu: modelData === "gpu"
                readonly property bool thermal: cpu || gpu
                readonly property bool hasTemperature: cpu ? SystemMonitorService.hasCpuTemp : gpu && SystemMonitorService.hasGpuTemp
                readonly property var historyValues: cpu ? SystemMonitorService.cpuHistory
                    : gpu ? SystemMonitorService.gpuHistory
                    : SystemMonitorService.ramHistory
                readonly property var temperatureValues: cpu ? SystemMonitorService.cpuTempHistory : gpu ? SystemMonitorService.gpuTempHistory : []
                readonly property string title: cpu ? "CPU" : gpu ? "GPU" : "Memory"
                readonly property real usage: cpu ? SystemMonitorService.cpuUsage
                    : gpu ? SystemMonitorService.gpuUsage
                    : SystemMonitorService.ramUsage
                readonly property string caption: cpu ? SystemMonitorService.cpuModel
                    : gpu ? SystemMonitorService.gpuModel
                    : `${SystemMonitorService.ramUsed} / ${SystemMonitorService.ramTotal} GiB`

                visible: !gpu || SystemMonitorService.hasGpuStats
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignTop
                spacing: Tokens.spacing.extraSmall

                RowLayout {
                    Layout.fillWidth: true
                    MaterialText { Layout.fillWidth: true; text: cell.title; textStyle: "titleSmall" }
                    MaterialText { text: `${Math.round(cell.usage)}%`; textStyle: "labelLarge" }
                }
                MaterialText {
                    Layout.fillWidth: true
                    text: cell.caption
                    textFormat: Text.PlainText
                    textStyle: "bodySmall"
                    colorRole: "onSurfaceVariant"
                    elide: Text.ElideRight
                }
                Sparkline {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Tokens.iconSize.extraLarge
                    visible: cell.historyValues.length > 1
                    values: cell.historyValues
                    lineColor: Theme.onSurfaceVariant
                    fillColor: Qt.alpha(Theme.onSurface, Tokens.stateLayer.hoverOpacity)
                    lineWidth: Tokens.size.outline
                    Accessible.name: `${cell.title} usage history, 0 to 100 percent`
                }
                MaterialText {
                    Layout.fillWidth: true
                    visible: cell.thermal
                    text: cell.hasTemperature
                        ? `Temperature · ${cell.cpu ? SystemMonitorService.cpuTemp : SystemMonitorService.gpuTemp} °C`
                        : "Temperature unavailable"
                    textStyle: "bodySmall"
                    colorRole: "onSurfaceVariant"
                }
                Sparkline {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Tokens.iconSize.large
                    visible: cell.thermal && cell.hasTemperature && cell.temperatureValues.length > 1
                    values: cell.temperatureValues
                    lineColor: Theme.onSurfaceVariant
                    showFill: false
                    lineWidth: Tokens.size.outline
                    Accessible.name: `${cell.title} temperature history, 0 to 120 degrees Celsius`
                }
                MaterialText {
                    Layout.fillWidth: true
                    visible: cell.cpu
                    text: `Load average · 1 / 5 / 15 min\n${SystemMonitorService.loadAvg1.toFixed(2)} / ${SystemMonitorService.loadAvg5.toFixed(2)} / ${SystemMonitorService.loadAvg15.toFixed(2)}`
                    textStyle: "bodySmall"
                    colorRole: "onSurfaceVariant"
                    wrapMode: Text.Wrap
                }
                MaterialText {
                    Layout.fillWidth: true
                    visible: cell.cpu && SystemMonitorService.cpuFreqGHz > 0
                    text: `${SystemMonitorService.cpuFreqGHz.toFixed(2)} GHz`
                    textStyle: "bodySmall"
                    colorRole: "onSurfaceVariant"
                }

            }
        }
    }
    StorageSection { Layout.fillWidth: true }
}
