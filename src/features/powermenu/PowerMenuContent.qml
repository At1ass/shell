pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.src.core.config
import qs.src.ui.base
import qs.src.ui.containers
import qs.src.ui.feedback

// Presentation and keyboard operation; the window owns system actions and grabs.
FocusScope {
    id: root
    property var actions: []
    property bool confirmActions: true
    property int focusedIndex: 0
    readonly property string confirmingAction: actions[_confirmingIndex]?.action ?? ""
    property int _confirmingIndex: -1
    signal actionRequested(string action)
    signal closeRequested()

    readonly property real tileExtent: Tokens.size.control * 2 + Tokens.spacing.medium
    readonly property real cellWidth: {
        let widest = metrics.advanceWidth("Confirm?")
        for (const action of actions) widest = Math.max(widest, metrics.advanceWidth(action.label))
        return Math.max(Tokens.size.tileMinimumWidth, tileExtent, widest + Tokens.spacing.small)
    }
    implicitWidth: actions.length * cellWidth + Math.max(0, actions.length - 1) * grid.columnSpacing + Tokens.focusRing.offset * 2
    implicitHeight: grid.implicitHeight + Tokens.focusRing.offset * 2
    FontMetrics { id: metrics; font.family: Tokens.typography.fontFamily; font.pixelSize: Tokens.typography.titleSmall.size; font.weight: Tokens.typography.titleSmall.weight; font.letterSpacing: Tokens.typography.titleSmall.letterSpacing }

    function focusInitial() {
        if (!root.visible) return
        const tile = tiles.itemAt(root.focusedIndex)
        if (tile) tile.forceActiveFocus(Qt.TabFocusReason)
    }
    function reset() {
        root.cancelConfirmation()
        root.focusedIndex = 0
        Qt.callLater(root.focusInitial)
    }
    function cancelConfirmation() { confirmTimer.stop(); root._confirmingIndex = -1 }
    function select(index) {
        if (!actions.length) return
        focusedIndex = (index + actions.length) % actions.length
        focusInitial()
    }
    onFocusedIndexChanged: root.cancelConfirmation()
    onActionsChanged: root.reset()
    onVisibleChanged: if (!visible) root.cancelConfirmation()
    function activate(index) {
        const action = actions[index]?.action
        if (!action) return
        root.select(index)
        const destructive = ["reboot", "shutdown", "logout"].includes(action)
        if (confirmActions && destructive && _confirmingIndex !== index) {
            _confirmingIndex = index
            confirmTimer.restart()
        } else {
            root.cancelConfirmation()
            root.actionRequested(action)
        }
    }
    function handleKey(event) {
        if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) return
        const key = Keycodes.key(event)
        if (key === Qt.Key_Escape) {
            if (_confirmingIndex >= 0) cancelConfirmation()
            else closeRequested()
        } else if (key === Qt.Key_Tab || key === Qt.Key_Backtab) {
            select(focusedIndex + (key === Qt.Key_Backtab || (event.modifiers & Qt.ShiftModifier) ? -1 : 1))
        } else if (key === Qt.Key_Left) select(focusedIndex - 1)
        else if (key === Qt.Key_Right) select(focusedIndex + 1)
        else if (key === Qt.Key_Up) select(Math.max(0, focusedIndex - grid.columns))
        else if (key === Qt.Key_Down) select(Math.min(actions.length - 1, focusedIndex + grid.columns))
        else if (key === Qt.Key_Home) select(0)
        else if (key === Qt.Key_End) select(actions.length - 1)
        else if (key === Qt.Key_Return || key === Qt.Key_Enter || key === Qt.Key_Space) {
            if (!event.isAutoRepeat) activate(focusedIndex)
        } else {
            const letter = Keycodes.letter(event)
            const index = actions.findIndex(action => action.key === letter)
            if (index < 0) return
            if (!event.isAutoRepeat) activate(index)
        }
        event.accepted = true
    }
    Keys.onPressed: event => root.handleKey(event)
    Timer { id: confirmTimer; interval: Tokens.interaction.powerConfirmationTimeout; onTriggered: root.cancelConfirmation() }
    ScrollableList {
        anchors.fill: parent
        contentPadding: Tokens.focusRing.offset
        GridLayout {
            id: grid
            Layout.fillWidth: true
            columns: Math.max(1, Math.min(root.actions.length, Math.floor((width + columnSpacing) / (root.cellWidth + columnSpacing))))
            columnSpacing: Tokens.spacing.extraLarge
            rowSpacing: Tokens.spacing.large
            Repeater {
                id: tiles
                model: root.actions
                delegate: Item {
                    id: tile
                    required property var modelData
                    required property int index
                    readonly property bool confirming: root._confirmingIndex === index
                    Layout.fillWidth: true
                    Layout.preferredWidth: root.cellWidth
                    Layout.minimumWidth: 0
                    implicitHeight: visual.implicitHeight
                    Keys.forwardTo: [root]
                    Accessible.role: Accessible.Button
                    Accessible.name: (tile.confirming ? "Confirm " : "") + tile.modelData.label
                    Accessible.description: tile.modelData.key
                    Accessible.onPressAction: root.activate(tile.index)
                    ColumnLayout {
                        id: visual
                        width: parent.width
                        spacing: Tokens.spacing.small
                        Surface {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: Math.min(root.tileExtent, tile.width)
                            Layout.preferredHeight: root.tileExtent
                            radius: Tokens.shape.extraLarge
                            color: tile.confirming ? Theme.primary : (tile.activeFocus ? Theme.secondaryContainer : Qt.alpha(Theme.surfaceContainerHigh, 0.6))
                            StateLayer { hovered: pointer.containsMouse; focused: tile.activeFocus; pressed: pointer.pressed }
                            MaterialIcon {
                                anchors.centerIn: parent
                                iconName: tile.confirming ? "check" : tile.modelData.icon
                                fontSize: Tokens.iconSize.extraLarge
                                iconColor: tile.confirming ? Theme.onPrimary : (tile.activeFocus ? Theme.onSecondaryContainer : Theme.scrimForeground)
                            }
                        }
                        MaterialText {
                            Layout.fillWidth: true
                            text: tile.confirming ? "Confirm?" : tile.modelData.label
                            textStyle: "titleSmall"
                            textFormat: Text.PlainText
                            color: tile.confirming ? Theme.primary : Theme.scrimForeground
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }
                        MaterialText {
                            Layout.fillWidth: true
                            text: tile.modelData.key
                            textStyle: "labelSmall"
                            textFormat: Text.PlainText
                            color: Qt.alpha(Theme.scrimForeground, tile.activeFocus ? 0.7 : 0.5)
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                    MouseArea {
                        id: pointer
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activate(tile.index)
                    }
                }
            }
        }
    }
}
