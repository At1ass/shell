import QtQuick
import QtQuick.Layouts
import qs.src.ui.containers
import qs.src.ui.inputs
import qs.src.ui.feedback
import QtQuick.Controls
import qs.src.core.config
import qs.src.ui.base

Rectangle {
    id: root

    Layout.fillWidth: true
    Layout.fillHeight: true
    color: Config.colors.surfaceContainerHigh
    radius: Config.shape.medium

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Config.spacing.medium
        spacing: Config.spacing.small

        MaterialText {
            text: "Notifications"
            textStyle: "titleSmall"
            colorRole: "onSurface"
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ColumnLayout {
                width: parent.width
                spacing: Config.spacing.small

                Repeater {
                    model: [
                        {title: "Firefox", text: "Download completed", time: "2m ago", iconName: "globe"},
                        {title: "Discord", text: "New message from @user", time: "5m ago", iconName: "chat"},
                        {title: "System", text: "Updates available", time: "1h ago", iconName: "settings"},
                        {title: "Spotify", text: "Now playing: Song Title", time: "2h ago", iconName: "music_note"}
                    ]

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 60
                        color: Config.colors.surface
                        radius: Config.shape.small

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Config.spacing.small
                            spacing: Config.spacing.medium

                            MaterialIcon {
                                iconName: modelData.iconName
                                // iconStyle: "bold"
                                fontSize: Config.typography.bodyLarge.size
                                color: "transparent"
                                iconColor: Config.colors.onSurface
                                radius: 0
                                enableRipple: false
                                Layout.preferredWidth: 24
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                RowLayout {
                                    Layout.fillWidth: true

                                    MaterialText {
                                        text: modelData.title
                                        textStyle: "labelMedium"
                                        colorRole: "onSurface"
                                        font.weight: Font.Medium
                                        Layout.fillWidth: true
                                    }

                                    MaterialText {
                                        text: modelData.time
                                        textStyle: "labelSmall"
                                        colorRole: "onSurfaceVariant"
                                    }
                                }

                                MaterialText {
                                    text: modelData.text
                                    textStyle: "bodySmall"
                                    colorRole: "onSurfaceVariant"
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
