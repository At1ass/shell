import QtQuick
import QtQuick.Layouts
import qs.src.core.config
import qs.src.ui.base
import qs.src.ui.containers

// Presentation only: the owner controls visibility and the action deadline.
Surface {
    id: root
    property string message: ""
    property string actionText: ""
    signal actionClicked()
    elevation: 3
    radius: Tokens.shape.extraSmall
    color: Theme.inverseSurface
    implicitHeight: Math.max(Tokens.touchTarget.minimum, snackbarLayout.implicitHeight + Tokens.spacing.small * 2)
    implicitWidth: Tokens.size.fieldWidth * 2
    GridLayout {
        id: snackbarLayout
        anchors.fill: parent
        anchors.leftMargin: Tokens.spacing.medium
        anchors.rightMargin: Tokens.spacing.small
        anchors.topMargin: Tokens.spacing.small
        anchors.bottomMargin: Tokens.spacing.small
        columns: root.actionText === "" || root.width >= messageLabel.implicitWidth
            + action.implicitWidth + Tokens.spacing.medium * 2 + Tokens.spacing.small ? 2 : 1
        columnSpacing: Tokens.spacing.medium
        rowSpacing: Tokens.spacing.extraSmall
        MaterialText {
            id: messageLabel
            Layout.fillWidth: true
            text: root.message
            textFormat: Text.PlainText
            textStyle: "bodyMedium"
            color: Theme.inverseOnSurface
            wrapMode: Text.Wrap
        }
        Item {
            id: action
            visible: root.actionText !== ""
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            implicitWidth: actionLabel.implicitWidth + Tokens.spacing.medium * 2
            implicitHeight: Math.max(Tokens.touchTarget.minimum, actionLabel.implicitHeight + Tokens.spacing.small * 2)
            activeFocusOnTab: visible && enabled
            Accessible.role: Accessible.Button
            Accessible.name: root.actionText
            Accessible.onPressAction: root.actionClicked()
            Keys.onPressed: event => {
                if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space) return
                if (!event.isAutoRepeat) root.actionClicked()
                event.accepted = true
            }
            StateLayer {
                target: action
                layerColor: Theme.inversePrimary
                hovered: actionMouse.containsMouse
                pressed: actionMouse.pressed
                focused: action.activeFocus
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
