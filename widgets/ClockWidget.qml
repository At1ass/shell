import QtQuick
import qs.components.base
import qs.components.tooltip
import qs.config

BarElement {
    id: clockWidget

    property var tooltipManager: null

    property string currentTime: ""
    property string currentDate: ""
    property string currentDateTime: ""

    // BarElement configuration
    expandOnHover: true
    expandedWidth: 160
    minWidth: 70

    nonVisualChildren: [
        Timer {
            interval: 1000
            running: true
            repeat: true
            triggeredOnStart: true

            onTriggered: {
                const now = new Date()
                clockWidget.currentTime = Qt.formatTime(now, "hh:mm")
                clockWidget.currentDate = Qt.formatDate(now, "dd MMM")
                clockWidget.currentDateTime = Qt.formatDateTime(now, "hh:mm:ss\ndddd, d MMMM yyyy")
            }
        },

        // Tooltip для детальной информации о времени
        TooltipItem {
            id: clockTooltip
            tooltip: clockWidget.tooltipManager
            owner: clockWidget
            show: clockWidget.hovered

            Column {
                anchors.centerIn: parent
                spacing: Config.spacing.extraSmall

                MaterialText {
                    text: clockWidget.currentDateTime
                    textStyle: "bodyLarge"
                    colorRole: "surfaceText"
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                    wrapMode: Text.Wrap
                }
            }
        }
    ]

    // Time display content
    Row {
        spacing: Config.spacing.extraSmall

        MaterialText {
            text: clockWidget.currentTime
            textStyle: "titleMedium"
            colorRole: clockWidget.expanded ? "primaryContainerText" : "surfaceText"
            anchors.verticalCenter: parent.verticalCenter
        }

        MaterialText {
            text: "•"
            textStyle: "bodyMedium"
            colorRole: clockWidget.expanded ? "primaryContainerText" : "surfaceVariantText"
            anchors.verticalCenter: parent.verticalCenter
            visible: clockWidget.expanded
        }

        MaterialText {
            text: clockWidget.currentDate
            textStyle: "bodyMedium"
            colorRole: clockWidget.expanded ? "primaryContainerText" : "surfaceVariantText"
            anchors.verticalCenter: parent.verticalCenter
            visible: clockWidget.expanded
        }
    }
}
