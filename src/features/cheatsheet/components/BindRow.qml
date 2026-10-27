pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.src.ui.base
import qs.src.ui.feedback
import qs.src.core.config

Item {
    id: root

    required property var modelData

    implicitHeight: 44
    implicitWidth: parent ? parent.width : 400

    // Type detection
    readonly property bool isShellBind: modelData.type === "shell"

    MaterialShape {
        id: bg
        anchors.fill: parent
        radius: Tokens.shape.small
        color: "transparent"

        StateLayer {
            target: bg
            hovered: hoverArea.containsMouse
            layerColor: Theme.onSurface
        }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Tokens.spacing.small
            anchors.rightMargin: Tokens.spacing.small
            spacing: Tokens.spacing.medium

            // Key combo zone (220px) or Shell action chip
            Item {
                Layout.preferredWidth: 220
                Layout.fillHeight: true
                visible: !root.isShellBind

                Flow {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 4

                    Repeater {
                        model: root.modelData.modifiers || []

                        MaterialShape {
                            id: modifierChip
                            required property string modelData
                            width: modLabel.implicitWidth + 12
                            height: 24
                            radius: Tokens.shape.small
                            color: Theme.primaryContainer

                            MaterialText {
                                id: modLabel
                                anchors.centerIn: parent
                                text: modifierChip.modelData
                                textStyle: "labelSmall"
                                colorRole: "onPrimaryContainer"
                            }
                        }
                    }

                    MaterialShape {
                        width: keyLabel.implicitWidth + 12
                        height: 24
                        radius: Tokens.shape.small
                        color: Theme.secondaryContainer

                        MaterialText {
                            id: keyLabel
                            anchors.centerIn: parent
                            text: root.modelData.key || ""
                            textStyle: "labelSmall"
                            colorRole: "onSecondaryContainer"
                        }
                    }
                }
            }

            // Shell bind: action chip
            MaterialShape {
                Layout.preferredWidth: 220
                Layout.fillHeight: true
                visible: root.isShellBind
                color: "transparent"

                MaterialShape {
                    anchors.verticalCenter: parent.verticalCenter
                    width: actionLabel.implicitWidth + 16
                    height: 24
                    radius: Tokens.shape.small
                    color: Theme.tertiaryContainer

                    MaterialText {
                        id: actionLabel
                        anchors.centerIn: parent
                        text: root.isShellBind ? root.modelData.action : ""
                        textStyle: "labelSmall"
                        colorRole: "onTertiaryContainer"
                        font.family: Tokens.typography.monoFamily
                    }
                }
            }

            // Description (fill width)
            MaterialText {
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: root.modelData.description || ""
                textStyle: "bodyMedium"
                colorRole: "onSurface"
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }

            // Dispatcher+arg trailing (only for Hyprland binds)
            MaterialText {
                Layout.preferredWidth: 180
                Layout.fillHeight: true
                visible: !root.isShellBind
                text: {
                    const d = root.modelData.dispatcher || ""
                    const a = root.modelData.arg || ""
                    return a ? d + " " + a : d
                }
                textStyle: "bodySmall"
                colorRole: "onSurfaceVariant"
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
