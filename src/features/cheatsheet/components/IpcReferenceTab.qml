import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.src.ui.base
import qs.src.ui.feedback
import qs.src.core.config

pragma ComponentBehavior: Bound

Item {
    id: root

    property var handlers: []

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        ColumnLayout {
            width: parent.width
            spacing: Tokens.spacing.medium

            // Usage banner
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: bannerLayout.implicitHeight + Tokens.spacing.medium * 2
                radius: Tokens.shape.medium
                color: Qt.rgba(Theme.primaryContainer.r, Theme.primaryContainer.g, Theme.primaryContainer.b, 0.5)

                RowLayout {
                    id: bannerLayout
                    anchors.fill: parent
                    anchors.margins: Tokens.spacing.medium
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        iconName: "info"
                        fontSize: Tokens.typography.bodyLarge.size
                        iconColor: Theme.onPrimaryContainer
                    }

                    MaterialText {
                        Layout.fillWidth: true
                        text: "qs ipc call <handler> <function> [args]"
                        textStyle: "bodyMedium"
                        colorRole: "onPrimaryContainer"
                        font.family: "monospace"
                        wrapMode: Text.WordWrap
                    }
                }
            }

            // Empty state
            MaterialText {
                Layout.fillWidth: true
                Layout.topMargin: Tokens.spacing.extraLarge
                visible: root.handlers.length === 0
                text: "No IPC functions found"
                textStyle: "bodyLarge"
                colorRole: "onSurfaceVariant"
                horizontalAlignment: Text.AlignHCenter
            }

            Repeater {
                id: handlerRepeater
                model: root.handlers

                ColumnLayout {
                    id: handlerDelegate
                    required property var modelData
                    required property int index

                    property var handler: modelData

                    Layout.fillWidth: true
                    spacing: 2

                    // Handler header
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: handlerDelegate.index > 0 ? Tokens.spacing.medium : 0
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            iconName: "terminal"
                            fontSize: Tokens.typography.titleSmall.size
                            iconColor: Theme.onSurfaceVariant
                        }

                        MaterialText {
                            text: handlerDelegate.handler.name
                            textStyle: "titleSmall"
                            colorRole: "primary"
                            font.family: "monospace"
                            font.weight: Font.Medium
                        }

                        // Badge with count
                        Rectangle {
                            width: funcCountLabel.implicitWidth + 12
                            height: 20
                            radius: Tokens.shape.full
                            color: Theme.surfaceContainerHighest

                            MaterialText {
                                id: funcCountLabel
                                anchors.centerIn: parent
                                text: handlerDelegate.handler.functions.length
                                textStyle: "labelSmall"
                                colorRole: "onSurfaceVariant"
                            }
                        }

                        Item { Layout.fillWidth: true }
                    }

                    // Functions list
                    Repeater {
                        model: handlerDelegate.handler.functions

                        IpcFunctionRow {
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }
    }
}
