pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.src.core.config
import qs.src.ui.base

// Meter-style OSD (volume/brightness): icon badge, title, percentage and a
// progress track inside the shared OsdSurface shell.
OsdSurface {
    id: root

    property string iconName: ""
    property color badgeColor: Theme.primaryContainer
    property color badgeContentColor: Theme.onPrimaryContainer
    property string title: ""
    property real progress: 0          // 0..1
    property color progressColor: Theme.primary

    readonly property int badgeSize: 56
    readonly property int trackHeight: 8

    cardWidth: 380
    cardHeight: 100

    contentComponent: Component {
        RowLayout {
            anchors.fill: parent
            anchors.margins: Tokens.spacing.large
            spacing: Tokens.spacing.large

            Rectangle {
                Layout.preferredWidth: root.badgeSize
                Layout.preferredHeight: root.badgeSize
                radius: Tokens.shape.full
                color: root.badgeColor

                Behavior on color {
                    ColorAnimation { duration: Tokens.motion.duration.short4 }
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    iconName: root.iconName
                    fontSize: Tokens.iconSize.extraLarge
                    iconColor: root.badgeContentColor
                    backgroundColor: "transparent"

                    Behavior on iconColor {
                        ColorAnimation { duration: Tokens.motion.duration.short4 }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    MaterialText {
                        text: root.title
                        textStyle: "titleMedium"
                        colorRole: "onSurface"
                        font.weight: Font.Bold
                    }

                    Item { Layout.fillWidth: true }

                    MaterialText {
                        text: Math.round(root.progress * 100) + "%"
                        textStyle: "titleLarge"
                        colorRole: "primary"
                        font.weight: Font.Bold
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.trackHeight
                    radius: Tokens.shape.full
                    color: Theme.surfaceContainerHighest

                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width * Math.max(0, Math.min(1, root.progress))
                        height: parent.height
                        radius: Tokens.shape.full
                        color: root.progressColor

                        Behavior on width {
                            NumberAnimation {
                                duration: Tokens.motion.duration.short4
                                easing.type: Tokens.motion.easing.emphasized
                                easing.bezierCurve: Tokens.motion.easing.emphasizedPoints
                            }
                        }

                        Behavior on color {
                            ColorAnimation { duration: Tokens.motion.duration.short4 }
                        }
                    }
                }
            }
        }
    }
}
