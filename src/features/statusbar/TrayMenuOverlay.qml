import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.src.core.config
import qs.src.core.services
import qs.src.ui.containers

PanelWindow {
    id: root

    property QsMenuHandle currentHandle: null
    property Item sourceItem: null

    readonly property bool hasMenu: currentHandle !== null

    signal menuClosed

    anchors {
        left: true
        top: true
        right: true
        bottom: true
    }

    color: "transparent"
    visible: GlobalStates.trayMenuOpen

    exclusiveZone: 0
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.namespace: "shell:traymenu:global"
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    property bool grabReady: false

    // Автозакрытие при клике вне области
    // Используем двойное условие: loader.active (быстрая задержка) + grabReady (таймер)
    // RIGHT CLICK обрабатывается дольше чем LEFT, поэтому нужна явная задержка
    HyprlandFocusGrab {
        id: focusGrab
        active: trayMenuLoader.active && root.grabReady && GlobalStates.trayMenuOpen
        windows: [root]
        onCleared: () => {
            hideMenu();
        }
    }

    Timer {
        id: grabReadyTimer
        interval: 50
        repeat: false
        onTriggered: {
            root.grabReady = true;
        }
    }

    function showMenu(menuHandle, source) {
        if (!menuHandle)
            return;

        if (root.visible && root.sourceItem === source) {
            hideMenu();
            return;
        }

        root.currentHandle = menuHandle;
        root.sourceItem = source;
        root.screen = getSourceScreen();

        root.grabReady = false;
        grabReadyTimer.stop();

        trayMenuLoader.active = false;
        trayMenuLoader.active = true;

        GlobalStates.openTrayMenu(root.screen?.name || "");

        grabReadyTimer.restart();
    }

    function hideMenu() {
        root.grabReady = false;
        grabReadyTimer.stop();

        GlobalStates.closeTrayMenu();
        clearLocal();
        root.menuClosed();
    }

    function clearLocal() {
        trayMenuLoader.active = false;
        root.currentHandle = null;
        root.sourceItem = null;
    }

    Keys.onPressed: event => {
        if (root.visible && event.key === Qt.Key_Escape) {
            hideMenu();
            event.accepted = true;
        }
    }

    Loader {
        id: trayMenuLoader

        anchors.fill: parent
        active: root.visible && root.hasMenu
        asynchronous: true

        sourceComponent: Item {

            MaterialCard {
                id: menuCard

                visible: root.visible && root.hasMenu
                opacity: visible ? 1 : 0
                scale: visible ? 1 : 0.95
                z: 1

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
        }
    }

    Component {
        id: menuComponent

        TrayMenu {
            trayItem: root.currentHandle
            onMenuClosed: root.hideMenu()
        }
    }

    Connections {
        target: GlobalStates
        function onTrayMenuEpochChanged() {
            if (!GlobalStates.trayMenuOpen)
                root.clearLocal();
        }
    }

    function sourceGlobalPos() {
        if (!root.sourceItem)
            return { x: 0, y: 0 };

        const win = root.sourceItem.Window?.window;
        const posInWindow = root.sourceItem.mapToItem(null, 0, 0);
        const globalX = (win ? win.x : 0) + posInWindow.x;
        const globalY = (win ? win.y : 0) + posInWindow.y;

        return { x: globalX, y: globalY };
    }

    function getSourceScreen() {
        if (!root.sourceItem)
            return null;

        const globalPos = sourceGlobalPos();

        for (let i = 0; i < Quickshell.screens.length; i++) {
            const screen = Quickshell.screens[i];
            if (globalPos.x >= screen.x && globalPos.x < screen.x + screen.width &&
                globalPos.y >= screen.y && globalPos.y < screen.y + screen.height) {
                return screen;
            }
        }

        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
    }

    function computeX(cardWidth, margin) {
        if (!root.sourceItem)
            return margin;

        const screen = root.screen || getSourceScreen();
        if (!screen)
            return margin;

        const globalPos = sourceGlobalPos();
        const localX = globalPos.x - screen.x;

        let menuX = localX + root.sourceItem.width / 2 - cardWidth / 2;

        if (menuX < margin)
            menuX = margin;
        if (menuX + cardWidth > screen.width - margin)
            menuX = screen.width - cardWidth - margin;

        return menuX;
    }

    function computeY(cardHeight, margin) {
        if (!root.sourceItem)
            return margin;

        const screen = root.screen || getSourceScreen();
        if (!screen)
            return margin;

        const globalPos = sourceGlobalPos();
        const localY = globalPos.y - screen.y;
        const barPosition = Config.data?.bar?.position || "top";

        let menuY = barPosition === "bottom"
            ? localY - cardHeight - margin
            : localY + root.sourceItem.height + margin;

        if (menuY < margin) {
            menuY = localY + root.sourceItem.height + margin;
            if (menuY + cardHeight > screen.height - margin)
                menuY = Math.max(margin, screen.height - cardHeight - margin);
        }

        if (menuY + cardHeight > screen.height - margin) {
            menuY = localY - cardHeight - margin;
            if (menuY < margin)
                menuY = Math.max(margin, screen.height - cardHeight - margin);
        }

        return menuY;
    }
}
