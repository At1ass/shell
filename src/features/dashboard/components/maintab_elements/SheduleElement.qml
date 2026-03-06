import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.ui.feedback
import qs.src.core.config
import qs.src.core.services

MaterialCard {
    color: Theme.surfaceContainerHigh
    radius: Tokens.shape.large

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.spacing.medium
        spacing: 4

        Repeater {
            model: CalendarService.upcomingEvents

            delegate: ListItem {
                Layout.fillWidth: true
                margin: Tokens.spacing.none
                clickable: false
                showStateLayer: false
                implicitHeight: 48

                headline: modelData.title
                supportingText: {
                    const dateStr = _formatRelativeDate(modelData.startDate)
                    const time = modelData.allDay ? "All day" : (modelData.startTime || "")
                    return dateStr + (time ? ", " + time : "")
                }

                leadingContent: Rectangle {
                    width: 3
                    height: 48
                    radius: 1.5
                    color: Theme.primary
                }
            }
        }

        EmptyState {
            visible: CalendarService.upcomingEvents.length === 0
            Layout.fillWidth: true
            Layout.fillHeight: true

            iconName: "event_available"
            title: "No upcoming events"
            iconContainerSize: 64
            iconSize: 40
        }
    }

    function _formatRelativeDate(khalDate) {
        if (!khalDate) return ""
        // khalDate is "dd.MM." or "dd.MM.yyyy"
        const parts = khalDate.replace(/\.$/, "").split(".")
        if (parts.length < 2) return khalDate
        const day = parseInt(parts[0])
        const month = parseInt(parts[1]) - 1
        const year = parts.length >= 3 && parts[2] ? parseInt(parts[2]) : new Date().getFullYear()
        const eventDate = new Date(year, month, day)
        const now = new Date()
        const today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
        const diffDays = Math.round((eventDate - today) / (24 * 60 * 60 * 1000))

        if (diffDays === 0) return "Today"
        if (diffDays === 1) return "Tomorrow"
        if (diffDays < 7) return Qt.formatDate(eventDate, "dddd")
        return Qt.formatDate(eventDate, "MMM d")
    }
}
