import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.src.ui.base
import qs.src.ui.feedback
import qs.src.core.config

pragma ComponentBehavior: Bound

Item {
    id: root

    property bool loading: false
    property string errorMessage: ""
    signal retryRequested()
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
            MaterialShape {
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
                        font.family: Tokens.typography.monoFamily
                        wrapMode: Text.WordWrap
                    }
                }
            }

            MaterialText {
                Layout.fillWidth: true
                visible: root.loading || root.errorMessage !== ""
                text: root.loading ? "Reading IPC commands…" : root.errorMessage
                textStyle: "bodyMedium"
                colorRole: root.errorMessage !== "" ? "error" : "onSurfaceVariant"
                wrapMode: Text.WordWrap
            }
            MaterialButton {
                visible: !root.loading && root.errorMessage !== ""
                text: "Try again"
                variant: "text"
                onClicked: root.retryRequested()
            }
            // Empty state
            MaterialText {
                Layout.fillWidth: true
                Layout.topMargin: Tokens.spacing.extraLarge
                visible: root.handlers.length === 0 && !root.loading && root.errorMessage === ""
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
                            font.family: Tokens.typography.monoFamily
                            font.weight: Font.Medium
                        }

                        // Neutral count chip, not the MD3 error badge — hence the
                        // explicit surface/onSurfaceVariant pair.
                        Badge {
                            inline: true
                            text: handlerDelegate.handler.functions.length
                            badgeColor: Theme.surfaceContainerHighest
                            textColor: Theme.onSurfaceVariant
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
