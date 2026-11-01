pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.src.ui.base
import qs.src.core.config

Item {
    id: root
    required property var modelData
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
        MaterialText {
            Layout.fillWidth: true
            Layout.preferredWidth: root.stacked ? -1 : Tokens.size.fieldWidth
            text: root.modelData.name || ""
            textFormat: Text.PlainText
            textStyle: "bodyMedium"
            colorRole: "primary"
            font.family: Tokens.typography.monoFamily
            wrapMode: Text.Wrap
        }
        MaterialText {
            Layout.fillWidth: true
            Layout.preferredWidth: root.stacked ? -1 : Tokens.size.fieldWidth
            text: "(" + (root.modelData.params || "") + ")"
            textFormat: Text.PlainText
            textStyle: "bodySmall"
            colorRole: "onSurfaceVariant"
            font.family: Tokens.typography.monoFamily
            wrapMode: Text.Wrap
        }
        MaterialText {
            Layout.fillWidth: true
            text: root.modelData.description || ""
            textFormat: Text.PlainText
            textStyle: "bodyMedium"
            wrapMode: Text.Wrap
        }
    }
}
