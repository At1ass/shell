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
                supportingText: Qt.formatDate(modelData.date, "dd MMM") + "\n" +  modelData.time

                leadingContent: Rectangle {
                    width: 3
                    height: 48
                    radius: 1.5
                    color: {
                        if (modelData.color === 'primary') return Theme.primary
                        if (modelData.color === 'secondary') return Theme.secondary
                        if (modelData.color === 'tertiary') return Theme.tertiary
                        return Theme.primary
                    }
                }
            }
        }

        // Empty state
        EmptyState {
            visible: CalendarService.upcomingEvents.length === 0
            Layout.fillWidth: true
            Layout.fillHeight: true

            iconName: "event_available"
            title: "No events today"
            iconContainerSize: 64
            iconSize: 40
        }
    }
}
