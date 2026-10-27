import QtQuick
import Quickshell.Services.SystemTray
import qs.src.core.config
import qs.src.core.services
import qs.src.ui.base
import qs.src.ui.feedback

Item {
    id: root
    property SystemTrayItem trayItem: null
    property int iconSize: Tokens.iconSize.medium
    property var tooltipManager: null
    property Item menuAnchor: root
    readonly property string label: trayItem?.tooltipTitle || trayItem?.title || trayItem?.id || "Application"
    implicitWidth: iconSize + Tokens.spacing.extraSmall * 2
    implicitHeight: iconSize + Tokens.spacing.extraSmall * 2
    enabled: trayItem !== null
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: root.label
    function activate(button) {
        const item = root.trayItem
        if (!item) return
        if (button === Qt.RightButton || (button === Qt.LeftButton && item.onlyMenu && item.hasMenu)) {
            if (item.hasMenu) PopoutsState.openPopout("traymenu", item.menu, root.menuAnchor)
        } else {
            PopoutsState.closePopout()
            if (button === Qt.MiddleButton) item.secondaryActivate()
            else item.activate()
        }
    }
    Accessible.onPressAction: root.activate(Qt.LeftButton)
    Keys.onPressed: event => {
        if (event.isAutoRepeat && [Qt.Key_Return, Qt.Key_Enter, Qt.Key_Space, Qt.Key_Menu, Qt.Key_F10].includes(event.key)) {
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) root.activate(Qt.LeftButton)
        else if (event.key === Qt.Key_Menu || (event.key === Qt.Key_F10 && (event.modifiers & Qt.ShiftModifier))) root.activate(Qt.RightButton)
        else return
        event.accepted = true
    }
    StateLayer { hovered: pointer.containsMouse; pressed: pointer.pressed; focused: root.activeFocus }
    Image {
        anchors.centerIn: parent
        width: root.iconSize; height: width
        source: String(root.trayItem?.icon ?? "")
        sourceSize.width: width; sourceSize.height: height
        fillMode: Image.PreserveAspectFit
        smooth: true
    }
    MaterialIndicator {
        anchors.right: parent.right
        anchors.top: parent.top
        size: "extraSmall"
        animated: false
        colorRole: "primary"
        visible: root.trayItem?.status === Status.NeedsAttention
    }
    TooltipItem {
        tooltip: root.tooltipManager
        owner: root
        show: pointer.containsMouse && !PopoutsState.open
        text: root.label
    }
    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: event => root.activate(event.button)
        property real wheelRemainder: 0
        onWheel: event => {
            if (!root.trayItem) return
            wheelRemainder += event.angleDelta.y / 120
            const steps = wheelRemainder > 0 ? Math.floor(wheelRemainder) : Math.ceil(wheelRemainder)
            if (steps !== 0) { wheelRemainder -= steps; root.trayItem.scroll(steps, false) }
            event.accepted = true
        }
    }
}
