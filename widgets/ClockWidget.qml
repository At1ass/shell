import QtQuick
import qs.components.base
import qs.config

BarElement {
    id: clockWidget

    property string currentTime: ""
    property string currentDate: ""

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
