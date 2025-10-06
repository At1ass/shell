import QtQuick
import QtQuick.Layouts
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.core.config

MaterialCard {
    color: Config.colors.surfaceContainerHigh
    radius: Config.shape.large

    RowLayout {
        anchors.fill: parent
        anchors.margins: Config.spacing.small
        spacing: Config.spacing.small
        Repeater {
            model: [
                {
                    icon: "notifications"
                },
                {
                    icon: "mail"
                },
                {
                    icon: "chat"
                },
                {
                    icon: "battery_full"
                },
                {
                    icon: "public"
                },
                {
                    icon: "lock"
                },
                {
                    icon: "cloud"
                }
            ]

            delegate: Rectangle {
                width: 28
                height: 28
                radius: 14
                color: Config.colors.surfaceContainerHighest

                MaterialIcon {
                    anchors.centerIn: parent
                    iconName: modelData.icon
                    fontSize: Config.typography.titleSmall.size
                    iconColor: Config.colors.onSurfaceVariant
                    backgroundColor: "transparent"
                }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: Config.colors.onSurface
                    opacity: trayMouseArea.containsMouse ? (trayMouseArea.pressed ? 0.12 : 0.08) : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Config.motion.duration.short4
                            easing.type: Config.motion.easing.standard
                        }
                    }
                }

                MouseArea {
                    id: trayMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }

        Item {
            Layout.fillWidth: true
        }
    }
}
