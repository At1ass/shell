pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import qs.src.core.config
import qs.src.core.services
import qs.src.features.statusbar
import qs.src.ui.base
import qs.src.ui.containers

Item {
    id: root
    property TrayModel trayModel: null
    property int _requestEpoch: -1
    property int currentIndex: 0
    function focusRow(index) {
        if (!rows.count) return
        const next = Math.max(0, Math.min(rows.count - 1, index))
        const item = rows.itemAt(next)
        if (item) item.forceActiveFocus(Qt.TabFocusReason)
    }
    implicitWidth: Tokens.size.fieldWidth + Tokens.spacing.large * 2
    implicitHeight: Math.min(column.implicitHeight + Tokens.spacing.small * 2,
        Math.max(0, (root.Window.window?.height ?? implicitWidth * 2) - BarMetrics.reservation - Tokens.spacing.large * 2))
    function closeIfEmpty() {
        if (root.trayModel && root.trayModel.hiddenItems.length > 0) return
        const epoch = root._requestEpoch
        Qt.callLater(() => {
            if (PopoutsState.name !== "trayoverflow" || PopoutsState.epoch !== epoch) return
            if (!root.trayModel || root.trayModel.hiddenItems.length === 0) PopoutsState.closePopout()
        })
    }
    Component.onCompleted: {
        root._requestEpoch = PopoutsState.epoch
        root.closeIfEmpty()
        root.forceActiveFocus()
        Qt.callLater(() => root.focusRow(0))
    }
    onTrayModelChanged: root.closeIfEmpty()
    Connections { target: root.trayModel; function onHiddenItemsChanged() { root.closeIfEmpty() } }
    Keys.onEscapePressed: PopoutsState.closePopout()
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Down) root.focusRow(root.currentIndex + 1)
        else if (event.key === Qt.Key_Up) root.focusRow(root.currentIndex - 1)
        else if (event.key === Qt.Key_Home) root.focusRow(0)
        else if (event.key === Qt.Key_End) root.focusRow(rows.count - 1)
        else return
        event.accepted = true
    }
    ScrollableList {
        anchors.fill: parent
        contentPadding: Tokens.spacing.small
        ColumnLayout {
            id: column
            Layout.fillWidth: true
            spacing: Tokens.spacing.extraSmall
            MaterialText { text: "Tray"; textStyle: "titleSmall" }
            Repeater {
                id: rows
                model: ScriptModel { values: Array.from(root.trayModel?.hiddenItems ?? []) }
                delegate: ListItem {
                    id: row
                    required property SystemTrayItem modelData
                    required property int index
                    onActiveFocusChanged: if (activeFocus) root.currentIndex = row.index
                    onIndexChanged: if (activeFocus) root.currentIndex = row.index
                    Layout.fillWidth: true
                    headline: modelData.tooltipTitle || modelData.title || modelData.id
                    leadingImageSource: modelData.icon
                    supportingText: modelData.status === Status.NeedsAttention ? "Needs attention" : ""
                    margin: Tokens.spacing.small
                    function activate(button) {
                        const item = row.modelData
                        if (!item) return
                        if (button === Qt.RightButton || (button === Qt.LeftButton && item.onlyMenu && item.hasMenu)) {
                            if (item.hasMenu) PopoutsState.openPopout("traymenu", item.menu, root.trayModel?.anchorItem ?? null)
                        } else {
                            PopoutsState.closePopout()
                            if (button === Qt.MiddleButton) item.secondaryActivate()
                            else item.activate()
                        }
                    }
                    onClicked: row.activate(Qt.LeftButton)
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Menu || (event.key === Qt.Key_F10 && (event.modifiers & Qt.ShiftModifier))) {
                            row.activate(Qt.RightButton)
                            event.accepted = true
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        z: -1
                        acceptedButtons: Qt.RightButton | Qt.MiddleButton
                        onClicked: event => row.activate(event.button)
                    }
                    trailingContent: IconButton {
                        iconName: "more_horiz"
                        iconSize: Tokens.iconSize.medium
                        Accessible.name: "Menu for " + row.headline
                        visible: row.modelData.hasMenu
                        onClicked: row.activate(Qt.RightButton)
                    }
                }
            }
        }
    }
}
