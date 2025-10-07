import QtQuick
import QtQuick.Layouts
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.ui.feedback
import qs.src.core.config

MaterialCard {
    color: Config.colors.surfaceContainerHigh
    radius: Config.shape.large

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Config.spacing.small
        spacing: Config.spacing.extraSmall

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 5
            rows: 2
            columnSpacing: 4
            rowSpacing: 4

            Repeater {
                model: [
                    // Row 1
                    {
                        icon: "wifi",
                        active: true
                    },
                    {
                        icon: "bluetooth",
                        active: false
                    },
                    {
                        icon: "do_not_disturb_on",
                        active: false
                    },
                    {
                        icon: "nightlight",
                        active: true
                    },
                    {
                        icon: "screenshot",
                        active: false
                    },
                    {
                        icon: "lock",
                        active: false
                    },
                    {
                        icon: "coffee",
                        active: false
                    },
                    {
                        icon: "videogame_asset",
                        active: false
                    },
                    // Row 2
                    {
                        icon: "colorize",
                        active: false
                    },
                    {
                        icon: "wallpaper",
                        active: false
                    }
                ]

                delegate: Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Config.shape.small
                    color: modelData.active ? Config.colors.primaryContainer : Config.colors.surfaceContainerHighest

                    MaterialIcon {
                        anchors.centerIn: parent
                        iconName: modelData.icon
                        iconColor: modelData.active ? Config.colors.onPrimaryContainer : Config.colors.onSurfaceVariant
                        fontSize: Config.typography.titleMedium.size
                        backgroundColor: "transparent"
                    }

                    StateLayer {
                        layerColor: modelData.active ? Config.colors.onPrimaryContainer : Config.colors.onSurface
                        hovered: actionMouseArea.containsMouse
                        pressed: actionMouseArea.pressed
                    }

                    MouseArea {
                        id: actionMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }
        }
    }
}
