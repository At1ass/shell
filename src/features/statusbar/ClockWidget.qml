import QtQuick
import QtQuick.Layouts
import qs.src.core.services
import qs.src.ui.base
import qs.src.ui.containers
import qs.src.ui.inputs
import qs.src.ui.feedback
import qs.src.core.config

BarElement {
    id: clockWidget

    property var widgetConfig: null
    property var widgetSettings: widgetConfig?.settings ?? ({})

    property var tooltipManager: null

    property string currentTime: ""
    property string currentDate: ""
    property string currentDateTime: ""
    property string timeFormat: widgetSettings.format ?? "HH:mm"
    property bool showDate: widgetSettings.showDate ?? true

    // BarElement configuration
    expandOnHover: true
    expandedWidth: 160
    clickable: true
    minWidth: 70

    nonVisualChildren: [
        Timer {
            interval: 1000
            running: true
            repeat: true
            triggeredOnStart: true

            onTriggered: {
                const now = new Date()
                clockWidget.currentTime = Qt.formatTime(now, clockWidget.timeFormat)
                clockWidget.currentDate = Qt.formatDate(now, "dd MMM")
                clockWidget.currentDateTime = Qt.formatDateTime(now, "hh:mm:ss\ndddd, d MMMM yyyy")
            }
        },

        // Tooltip with detailed date/time information
        TooltipItem {
            id: clockTooltip
            tooltip: clockWidget.tooltipManager
            owner: clockWidget
            show: clockWidget.hovered

            Column {
                anchors.centerIn: parent
                spacing: Tokens.spacing.extraSmall

                MaterialText {
                    text: clockWidget.currentDateTime
                    textStyle: "bodyLarge"
                    colorRole: "onSurface"
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                    wrapMode: Text.Wrap
                }
            }
        }
    ]

    clickHandler: function(mouse) {
        if (mouse.button === Qt.RightButton && widgetConfig?.clickAction) {
            GlobalStates.handleClickAction(widgetConfig.clickAction)
            mouse.accepted = true
            return
        }

        mouse.accepted = false
    }

    // Time display content
    RowLayout {
        spacing: Tokens.spacing.extraSmall

        MaterialText {
            text: clockWidget.currentTime
            textStyle: "titleMedium"
            colorRole: clockWidget.expanded ? "onPrimaryContainer" : "onSurface"
        }

        MaterialText {
            text: "•"
            textStyle: "bodyMedium"
            colorRole: clockWidget.expanded ? "onPrimaryContainer" : "onSurfaceVariant"
            visible: clockWidget.expanded && clockWidget.showDate
        }

        MaterialText {
            text: clockWidget.currentDate
            textStyle: "bodyMedium"
            colorRole: clockWidget.expanded ? "onPrimaryContainer" : "onSurfaceVariant"
            visible: clockWidget.expanded && clockWidget.showDate
        }
    }
}
