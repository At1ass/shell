import QtQuick
import QtQuick.Layouts
import qs.src.ui.base
import qs.src.ui.feedback
import qs.src.core.config

pragma ComponentBehavior: Bound

Item {
    id: root

    required property var modelData

    implicitHeight: 44
    implicitWidth: parent ? parent.width : 400

    Rectangle {
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

            // Function name (monospace, primary)
            MaterialText {
                Layout.preferredWidth: 200
                Layout.fillHeight: true
                text: root.modelData.name || ""
                textStyle: "bodyMedium"
                colorRole: "primary"
                font.family: "monospace"
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }

            // Params (monospace, onSurfaceVariant)
            MaterialText {
                Layout.preferredWidth: 180
                Layout.fillHeight: true
                text: root.modelData.params ? "(" + root.modelData.params + ")" : "()"
                textStyle: "bodySmall"
                colorRole: "onSurfaceVariant"
                font.family: "monospace"
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }

            // Description
            MaterialText {
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: root.modelData.description || ""
                textStyle: "bodyMedium"
                colorRole: "onSurface"
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
