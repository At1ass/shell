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
            text: "App Volume Mixer"
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
                    model: ["Firefox", "Discord", "Spotify", "System Sounds"]

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 50
                        color: Config.colors.surface
                        radius: Config.shape.small

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Config.spacing.small
                            spacing: Config.spacing.medium

                            Rectangle {
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                                color: Config.colors.primary
                                radius: 4

                                MaterialText {
                                    anchors.centerIn: parent
                                    text: modelData.charAt(0)
                                    textStyle: "labelSmall"
                                    colorRole: "primaryText"
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                MaterialText {
                                    text: modelData
                                    textStyle: "labelMedium"
                                    colorRole: "surfaceText"
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 4
                                    color: Config.colors.outline
                                    radius: 2

                                    Rectangle {
                                        width: parent.width * (0.3 + index * 0.2)
                                        height: parent.height
                                        color: Config.colors.secondary
                                        radius: 2
                                    }
                                }
                            }

                            MaterialText {
                                text: Math.round((30 + index * 20)) + "%"
                                textStyle: "labelSmall"
                                colorRole: "surfaceVariantText"
                            }
                        }
                    }
                }
            }
        }
    }
}