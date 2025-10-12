import QtQuick
import Quickshell
import qs.src.core.config
import qs.src.ui.base
import qs.src.ui.containers

Item {
    id: root
    anchors.fill: parent
    visible: false

    property QsMenuHandle currentHandle: null
    property Item sourceItem: null

    readonly property bool hasMenu: currentHandle !== null

    signal menuClosed()

    function showMenu(menuHandle, source) {
        if (!menuHandle)
            return;

        if (root.visible && root.sourceItem === source) {
            hideMenu();
            return;
        }

        root.currentHandle = menuHandle;
        root.sourceItem = source;

        menuLoader.active = false;
        menuLoader.active = true;

        root.visible = true;
    }

    function hideMenu() {
        menuLoader.active = false;
        root.visible = false;
        root.currentHandle = null;
        root.sourceItem = null;
        root.menuClosed();
    }

    Keys.onPressed: event => {
        if (root.visible && event.key === Qt.Key_Escape) {
            hideMenu();
            event.accepted = true;
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.visible
        onClicked: root.hideMenu()
    }

    MaterialCard {
        id: menuCard

        visible: root.visible && root.hasMenu
        opacity: visible ? 1 : 0
        scale: visible ? 1 : 0.95

        color: Config.colors.surfaceContainerHigh
        radius: Config.shape.medium

        width: implicitWidth
        height: implicitHeight

        readonly property real horizontalMargin: Config.spacing.small
        readonly property real verticalMargin: Config.spacing.small

        implicitWidth: Math.max((menuLoader.item?.implicitWidth ?? 0) + Config.spacing.small * 2, 200)
        implicitHeight: (menuLoader.item?.implicitHeight ?? 0) + Config.spacing.small * 2

        x: root.computeX(width, horizontalMargin)
        y: root.computeY(height, verticalMargin)

        // M3 elevation через surface tint (вместо DropShadow)
        // border уже есть в MaterialCard через outlined: true
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: parent.radius - 1
            color: Config.colors.primary
            opacity: 0.08
            z: -1
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Config.motion.duration.short4
                easing.type: Config.motion.easing.standard
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Config.motion.duration.short4
                easing.type: Config.motion.easing.standard
            }
        }

        Loader {
            id: menuLoader

            anchors.fill: parent
            anchors.margins: Config.spacing.small
            active: root.visible && root.hasMenu
            asynchronous: true

            sourceComponent: menuComponent
        }
    }

    Component {
        id: menuComponent

        TrayMenu {
            trayItem: root.currentHandle
            onMenuClosed: root.hideMenu()
        }
    }

    function computeX(cardWidth, margin) {
        if (!root.sourceItem)
            return margin;

        const globalPos = root.sourceItem.mapToItem(root, 0, 0);
        let posX = globalPos.x + root.sourceItem.width / 2 - cardWidth / 2;

        if (posX < margin)
            posX = margin;
        if (posX + cardWidth > root.width - margin)
            posX = root.width - cardWidth - margin;

        return posX;
    }

    function computeY(cardHeight, margin) {
        if (!root.sourceItem)
            return margin;

        const globalPos = root.sourceItem.mapToItem(root, 0, 0);
        let preferredY = globalPos.y - cardHeight - margin;

        if (preferredY < margin) {
            preferredY = globalPos.y + root.sourceItem.height + margin;
            if (preferredY + cardHeight > root.height - margin)
                preferredY = Math.max(margin, root.height - cardHeight - margin);
        }

        return preferredY;
    }
}
