import QtQuick
import QtQuick.Layouts
import qs.src.ui.base
import qs.src.core.config
import qs.src.core.services

// What the collapsed metrics line CANNOT show: the last few minutes, and what
// the hardware actually is.
//
// It used to show neither. Unfolding drew four 96px cards that repeated the
// icon, the percentage and the temperature already sitting one line above --
// with a threshold colour, a coloured edge and a heading each -- and put the
// history behind all of it at 30% opacity. More paint for the same numbers.
//
// So: the history, at the width of the column it belongs to, and one dim line
// naming the part. Nothing here appears anywhere else.
Item {
    id: root

    // Sized by what it holds. It used to be handed a constant from the caller,
    // which is the same drift the dashboard's height table has: the number was
    // right once, and then the content changed.
    anchors.left: parent.left
    anchors.right: parent.right
    implicitHeight: strip.implicitHeight
    height: implicitHeight

    RowLayout {
        id: strip
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        // The same column rhythm as the collapsed line above, so a sparkline
        // sits under the number it belongs to rather than near it.
        spacing: Tokens.spacing.medium

        Repeater {
            model: [
                { type: "cpu" },
                { type: "gpu" },
                { type: "ram" },
                { type: "disk" }
            ]

            delegate: ColumnLayout {
                id: cell
                required property var modelData

                readonly property var historyValues: {
                    switch (cell.modelData.type) {
                    case "cpu": return SystemMonitorService.cpuHistory
                    case "gpu": return SystemMonitorService.gpuHistory
                    case "ram": return SystemMonitorService.ramHistory
                    // Disk usage does not move on the scale of a panel being
                    // open, so there is no history worth a line.
                    default:    return []
                    }
                }

                readonly property string caption: {
                    switch (cell.modelData.type) {
                    case "cpu": return SystemMonitorService.cpuModel
                    case "gpu": return SystemMonitorService.gpuModel
                    case "ram": return SystemMonitorService.ramTotal + "G total"
                    default:    return SystemMonitorService.diskTotal + " total"
                    }
                }

                visible: cell.modelData.type !== "gpu" || SystemMonitorService.hasGpuStats
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignTop
                spacing: Tokens.spacing.extraSmall

                // The height is reserved by the wrapper, not by the chart. A
                // column with no history -- disk -- would otherwise collapse and
                // hang its caption a chart's height above the others.
                Item {
                    Layout.fillWidth: true
                    Layout.rightMargin: Tokens.spacing.medium
                    Layout.preferredHeight: Tokens.iconSize.extraLarge

                    Sparkline {
                        anchors.fill: parent
                        values: cell.historyValues
                        visible: cell.historyValues.length > 1
                        // One neutral, like the gauge above it: this is a
                        // quantity over time, and colouring it by threshold
                        // spends the accent on something that changes every
                        // two seconds.
                        lineColor: Theme.onSurfaceVariant
                        fillColor: Qt.alpha(Theme.onSurface, Tokens.stateLayer.hoverOpacity)
                        lineWidth: 1
                    }
                }

                MaterialText {
                    Layout.fillWidth: true
                    Layout.rightMargin: Tokens.spacing.medium
                    text: cell.caption
                    textStyle: "labelSmall"
                    colorRole: "onSurfaceVariant"
                    elide: Text.ElideRight
                }
            }
        }
    }
}
