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
        spacing: 6

        Text {
            text: clockWidget.currentTime
            font.family: Config.typography.fontFamily
            font.pixelSize: Config.typography.titleMedium.size
            font.weight: Config.typography.titleMedium.weight
            font.letterSpacing: Config.typography.titleMedium.letterSpacing
            color: clockWidget.expanded ? Config.colors.primaryContainerText : Config.colors.surfaceText
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: "•"
            font.family: Config.typography.fontFamily
            font.pixelSize: Config.typography.bodyMedium.size
            font.weight: Config.typography.titleMedium.weight
            color: clockWidget.expanded ? Config.colors.primaryContainerText : Config.colors.surfaceVariantText
            anchors.verticalCenter: parent.verticalCenter
            visible: clockWidget.expanded
        }

        Text {
            text: clockWidget.currentDate
            font.family: Config.typography.fontFamily
            font.pixelSize: Config.typography.titleMedium.size
            font.weight: Config.typography.titleMedium.weight
            font.letterSpacing: Config.typography.bodyMedium.letterSpacing
            color: clockWidget.expanded ? Config.colors.primaryContainerText : Config.colors.surfaceVariantText
            anchors.verticalCenter: parent.verticalCenter
            visible: clockWidget.expanded
        }
    }
}
