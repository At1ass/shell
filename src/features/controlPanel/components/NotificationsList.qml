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
            colorRole: "surfaceText"
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
                        {title: "System", text: "Updates available", time: "1h ago", iconName: "gear"},
                        {title: "Spotify", text: "Now playing: Song Title", time: "2h ago", iconName: "music-note"}
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
                                iconStyle: "bold"
                                iconSize: 20
                                color: "transparent"
                                iconColor: Config.colors.surfaceText
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
                                        colorRole: "surfaceText"
                                        font.weight: Font.Medium
                                        Layout.fillWidth: true
                                    }

                                    MaterialText {
                                        text: modelData.time
                                        textStyle: "labelSmall"
                                        colorRole: "surfaceVariantText"
                                    }
                                }

                                MaterialText {
                                    text: modelData.text
                                    textStyle: "bodySmall"
                                    colorRole: "surfaceVariantText"
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