import QtQuick
import QtQuick.Layouts
import qs.src.core.config
import qs.src.ui.base
import qs.src.ui.containers

// Material Design 3 Snackbar (presentational): inverse-surface bar with optional action.
// Show/hide/queue is the caller's concern (e.g. ToastOverlay / ToastService).
Surface {
    id: root

    property string message: ""
    property string actionText: ""

    signal actionClicked()

    elevation: 3
    radius: Tokens.shape.extraSmall
    color: Theme.inverseSurface

    implicitHeight: Math.max(48, content.implicitHeight + Tokens.spacing.small * 2)
    implicitWidth: Math.min(560, content.implicitWidth + Tokens.spacing.medium + Tokens.spacing.small)

    RowLayout {
        id: content
        anchors.fill: parent
        anchors.leftMargin: Tokens.spacing.medium
        anchors.rightMargin: root.actionText !== "" ? Tokens.spacing.small : Tokens.spacing.medium
        spacing: Tokens.spacing.medium

        MaterialText {
            text: root.message
            textStyle: "bodyMedium"
            color: Theme.inverseOnSurface
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            verticalAlignment: Text.AlignVCenter
        }

        // Action (text-button styled in inversePrimary)
        Item {
            visible: root.actionText !== ""
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: actionLabel.implicitWidth + Tokens.spacing.medium * 2
            implicitHeight: 36

            Rectangle {
                id: actionBg
                anchors.fill: parent
                radius: Tokens.shape.full
                color: "transparent"

                StateLayer {
                    target: actionBg
                    layerColor: Theme.inversePrimary
                    hovered: actionMouse.containsMouse
                    pressed: actionMouse.pressed
                    showFocusRing: false
                }
            }

            MaterialText {
                id: actionLabel
                anchors.centerIn: parent
                text: root.actionText
                textStyle: "labelLarge"
                color: Theme.inversePrimary
            }

            MouseArea {
                id: actionMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.actionClicked()
            }
        }
    }
}
