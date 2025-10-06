import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.core.config
import qs.src.core.services

MaterialCard {
    color: Config.colors.surfaceContainerHigh
    radius: Config.shape.large

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Config.spacing.medium
        spacing: 4

        Repeater {
            model: CalendarService.upcomingEvents

            delegate: RowLayout {
                spacing: Config.spacing.small

                Rectangle {
                    width: 3
                    height: eventColumn.height
                    radius: 1.5
                    color: {
                        if (modelData.color === 'primary') return Config.colors.primary
                        if (modelData.color === 'secondary') return Config.colors.secondary
                        if (modelData.color === 'tertiary') return Config.colors.tertiary
                        return Config.colors.primary
                    }
                }

                ColumnLayout {
                    id: eventColumn
                    MaterialText {
                        text: modelData.title
                        textStyle: "bodySmall"
                        colorRole: "onSurface"
                        font.weight: Font.Medium
                    }
                    MaterialText {
                        text: modelData.time + " (" + Qt.formatDate(modelData.date, "dd MMM") + ")"
                        textStyle: "labelSmall"
                        colorRole: "onSurfaceVariant"
                        Layout.preferredWidth: 70
                    }
                }
            }
        }

        // Empty state
        Item {
            visible: CalendarService.upcomingEvents.length === 0
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                anchors.centerIn: parent
                spacing: Config.spacing.small

                MaterialIcon {
                    iconName: "event_available"
                    fontSize: Config.typography.displaySmall.size
                    iconColor: Config.colors.onSurfaceVariant
                    backgroundColor: "transparent"
                    Layout.alignment: Qt.AlignHCenter
                    opacity: 0.5
                }

                MaterialText {
                    text: "No events today"
                    textStyle: "bodyMedium"
                    colorRole: "onSurfaceVariant"
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }
    }
}
