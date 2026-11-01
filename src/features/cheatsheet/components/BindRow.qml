pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.src.ui.base
import qs.src.core.config

Item {
    id: root
    required property var modelData
    readonly property bool isShellBind: modelData.type === "shell"
    readonly property bool stacked: width < Tokens.size.fieldWidth * 2 + Tokens.typography.bodyMedium.lineHeight * 12
    implicitHeight: Math.max(Tokens.size.control, layout.implicitHeight + Tokens.spacing.small * 2)

    GridLayout {
        id: layout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Tokens.spacing.small
        columns: root.stacked ? 1 : 3
        columnSpacing: Tokens.spacing.medium
        rowSpacing: Tokens.spacing.extraSmall
        Item {
            Layout.fillWidth: true
            Layout.preferredWidth: root.stacked ? -1 : Tokens.size.fieldWidth
            implicitHeight: combo.height
            Flow {
                id: combo
                objectName: "keyCombo"
                width: parent.width
                spacing: Tokens.spacing.extraSmall
                Repeater {
                    model: root.isShellBind ? [root.modelData.action || ""] : (root.modelData.modifiers || []).concat([root.modelData.key || ""])
                    MaterialShape {
                        id: keyChip
                        required property string modelData
                        width: Math.min(combo.width, label.implicitWidth + Tokens.spacing.small * 2)
                        height: label.implicitHeight + Tokens.spacing.extraSmall * 2
                        radius: Tokens.shape.small
                        color: root.isShellBind ? Theme.tertiaryContainer : Theme.primaryContainer
                        MaterialText {
                            id: label
                            anchors.centerIn: parent
                            width: Math.max(0, parent.width - Tokens.spacing.small * 2)
                            text: keyChip.modelData
                            textFormat: Text.PlainText
                            wrapMode: Text.Wrap
                            textStyle: "labelSmall"
                            colorRole: root.isShellBind ? "onTertiaryContainer" : "onPrimaryContainer"
                        }
                    }
                }
            }
        }
        MaterialText {
            Layout.fillWidth: true
            text: root.modelData.description || ""
            textFormat: Text.PlainText
            textStyle: "bodyMedium"
            wrapMode: Text.Wrap
        }
        MaterialText {
            Layout.fillWidth: true
            Layout.preferredWidth: root.stacked ? -1 : Tokens.size.fieldWidth
            visible: !root.isShellBind
            text: [root.modelData.dispatcher || "", root.modelData.arg || ""].filter(Boolean).join(" ")
            textFormat: Text.PlainText
            textStyle: "bodySmall"
            colorRole: "onSurfaceVariant"
            font.family: Tokens.typography.monoFamily
            wrapMode: Text.Wrap
        }
    }
}
