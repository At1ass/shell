pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.ui

Item {
    id: root
    property bool opened: false
    property bool busy: false
    property string errorMessage: ""
    property string confirming: ""
    signal requested(string action)
    signal closed()
    visible: opened
    function show() { confirming = ""; errorMessage = ""; opened = true; Qt.callLater(focusCancel) }
    function close() { opened = false; confirming = ""; closed() }
    function focusCancel() { const button = actions.itemAt(actions.count - 1); if (button) button.forceActiveFocus() }
    Keys.onEscapePressed: close()
    Keys.onPressed: event => {
        if (event.key !== Qt.Key_Tab && event.key !== Qt.Key_Backtab) return
        const buttons = []
        for (let i = 0; i < actions.count; i++) { const button = actions.itemAt(i); if (button.enabled) buttons.push(button) }
        const at = buttons.findIndex(button => button.activeFocus)
        const step = event.key === Qt.Key_Backtab || (event.modifiers & Qt.ShiftModifier) ? -1 : 1
        if (buttons.length) buttons[(at + step + buttons.length) % buttons.length].forceActiveFocus()
        event.accepted = true
    }
    Surface {
        anchors.centerIn: parent
        width: Math.min(parent.width - Tokens.spacing.large * 2, Tokens.size.fieldWidth + Tokens.spacing.extraLarge * 2)
        height: Math.min(parent.height - Tokens.spacing.large * 2, column.implicitHeight + Tokens.spacing.large * 2)
        elevation: 2
        Flickable {
            anchors.fill: parent
            anchors.margins: Tokens.spacing.large
            contentHeight: column.implicitHeight
            clip: true
            ColumnLayout {
                id: column
                width: parent.width
                spacing: Tokens.spacing.small
                MaterialText { Layout.fillWidth: true; text: root.confirming ? "Confirm " + root.confirming + "?" : "Power"; textStyle: "titleMedium"; wrapMode: Text.WordWrap }
                MaterialText { Layout.fillWidth: true; visible: root.confirming !== ""; text: "Other users may have unsaved work."; textStyle: "bodyMedium"; wrapMode: Text.WordWrap }
                MaterialText { Layout.fillWidth: true; visible: root.errorMessage !== ""; text: root.errorMessage; colorRole: "error"; wrapMode: Text.WordWrap }
                Repeater {
                    id: actions
                    model: root.confirming ? [{text:root.confirming === "reboot" ? "Restart" : "Shut down",action:root.confirming}, {text:"Cancel",action:"cancel"}]
                        : [{text:"Sleep",action:"suspend"},{text:"Restart…",action:"confirm-reboot"},{text:"Shut down…",action:"confirm-shutdown"},{text:"Cancel",action:"cancel"}]
                    delegate: MaterialButton {
                        required property var modelData
                        Layout.fillWidth: true
                        text: modelData.text
                        enabled: !root.busy || modelData.action === "cancel"
                        variant: modelData.action === "cancel" ? "text" : "tonal"
                        Keys.forwardTo: [root]
                        onClicked: {
                            const action = modelData.action
                            if (action === "cancel") root.close()
                            else if (action.startsWith("confirm-")) { root.confirming = action.slice(8); Qt.callLater(root.focusCancel) }
                            else root.requested(action)
                        }
                    }
                }
            }
        }
    }
}
