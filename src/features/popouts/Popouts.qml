import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.src.core.config
import qs.src.core.services
import qs.src.ui.containers
import qs.src.features.statusbar as StatusBar

PanelWindow {
    id: root

    property string currentName: ""
    property string currentMode: "card"
    property var currentData: null
    property Item sourceItem: null

    readonly property bool hasPopout: currentName !== ""
    signal popoutClosed

    anchors {
        left: true
        top: true
        right: true
        bottom: true
    }

    color: "transparent"
    visible: PopoutsState.open

    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "shell:popouts:global"
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    property bool grabReady: false

    HyprlandFocusGrab {
        // active: root.visible && root.hasPopout && root.grabReady && PopoutsState.open && root. currentMode !== "card"
        active: root.visible && root.hasPopout && root.grabReady && PopoutsState.open
        windows: [root]
        onCleared: {
            console.log("Popouts: focus grab cleared, closing popout");
            root.closePopout();
        }
    }

    Timer {
        id: grabReadyTimer
        interval: 50
        repeat: false
        onTriggered: root.grabReady = true
    }
    // Focus grab disabled; close handled by click-outside.

    function openPopout(name, data, source) {
        console.log("Popouts: opening popout", name);
        if (!name)
            return;
        if (root.visible && root.sourceItem === source && root.currentName === name) {
            closePopout();
            return;
        }

        root.currentName = name;
        root.currentMode = modeFor(name);
        root.currentData = data;
        root.sourceItem = source;
        root.screen = getSourceScreen() || getFocusedScreen() || Quickshell.screens[0] || root.screen;
        root.grabReady = false;
        grabReadyTimer.start();

        PopoutsState.openPopout(root.currentName, root.screen?.name || "");
        grabReadyTimer.restart();
    }

    function closePopout() {
        console.log("Popouts: closing popout", root.currentName);
        root.grabReady = false;
        grabReadyTimer.stop();
        PopoutsState.closePopout();
        clearLocal();
        root.popoutClosed();
    }

    function clearLocal() {
        root.currentName = "";
        root.currentMode = "card";
        root.currentData = null;
        root.sourceItem = null;
        PopoutsState.setPopoutRect(0, 0, 0, 0, "");
    }

    Keys.onPressed: event => {
        if (root.visible && event.key === Qt.Key_Escape) {
            console.log("Popouts: Escape pressed, closing popout");
            closePopout();
            event.accepted = true;
        }
    }

    Item {
        id: outsideClickLayer
        anchors.fill: parent
        visible: root.visible && root.hasPopout && root.currentMode === "card"
        z: 0

        MouseArea {
            anchors.fill: parent
            enabled: outsideClickLayer.visible
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onPressed: mouse => {
                const inside = mouse.x >= popoutCard.x && mouse.y >= popoutCard.y && mouse.x <= popoutCard.x + popoutCard.width && mouse.y <= popoutCard.y + popoutCard.height;
                if (inside) {
                    mouse.accepted = false;
                    return;
                }
                mouse.accepted = true;
                root.closePopout();
            }
        }
    }

    Item {
        id: cardLayer
        anchors.fill: parent
        visible: root.visible && root.hasPopout && root.currentMode === "card"
        // z: 1

        readonly property real contentWidth: popoutContent.item?.implicitWidth ?? 0
        readonly property real contentHeight: popoutContent.item?.implicitHeight ?? 0
        readonly property real cardWidth: Math.max(contentWidth + Config.spacing.small * 2, 200)
        readonly property real cardHeight: contentHeight + Config.spacing.small * 2

        MaterialCard {
            id: popoutCard

            visible: cardLayer.visible
            opacity: visible ? 1 : 0
            scale: visible ? 1 : 0.95
            // z: 1

            color: Config.colors.surfaceContainerHigh
            radius: Config.shape.medium

            width: cardLayer.cardWidth
            height: cardLayer.cardHeight
            x: root.computeX(width, Config.spacing.small)
            y: root.computeY(height, Config.spacing.small)

            function updateRect() {
                if (root.currentMode !== "card" || !root.screen || !root.visible)
                    return;
                PopoutsState.setPopoutRect(x, y, width, height, root.screen?.name || "");
                console.log("Popouts: rect set", x, y, width, height, "screen", root.screen?.name || "");
            }

            onXChanged: updateRect()
            onYChanged: updateRect()
            onWidthChanged: updateRect()
            onHeightChanged: updateRect()
            onVisibleChanged: updateRect()

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: parent.radius - 1
                color: Config.colors.primary
                opacity: 0.08
                // z: -1
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
                id: popoutContent

                anchors.fill: parent
                anchors.margins: Config.spacing.small
                active: root.visible && root.hasPopout && root.currentMode === "card"
                asynchronous: true
                sourceComponent: popoutComponentFor(root.currentName)
                // z: 1
            }
        }
    }

    Item {
        id: panelLayer
        anchors.fill: parent
        visible: root.visible && root.hasPopout && root.currentMode === "panel"
        // z: 1

        Loader {
            id: panelContent
            anchors.fill: parent
            active: panelLayer.visible
            asynchronous: true
            sourceComponent: popoutComponentFor(root.currentName)
        }
    }

    Component {
        id: trayMenuComponent
        StatusBar.TrayMenu {
            trayItem: root.currentData
            onMenuClosed: {
                root.closePopout();
            }
        }
    }

    function popoutComponentFor(name) {
        switch (name) {
        case "traymenu":
            return trayMenuComponent;
        default:
            return null;
        }
    }

    function modeFor(name) {
        switch (name) {
        default:
            return "card";
        }
    }

    Connections {
        target: PopoutsState
        function onEpochChanged() {
            if (!PopoutsState.open)
                root.clearLocal();
        }
    }

    function sourceGlobalPos() {
        if (!root.sourceItem)
            return {
                x: 0,
                y: 0
            };

        const win = root.sourceItem.Window?.window;
        const posInWindow = root.sourceItem.mapToItem(null, 0, 0);
        return {
            x: (win ? win.x : 0) + posInWindow.x,
            y: (win ? win.y : 0) + posInWindow.y
        };
    }

    function getSourceScreen() {
        if (!root.sourceItem)
            return null;

        const globalPos = sourceGlobalPos();
        for (let i = 0; i < Quickshell.screens.length; i++) {
            const s = Quickshell.screens[i];
            if (globalPos.x >= s.x && globalPos.x < s.x + s.width && globalPos.y >= s.y && globalPos.y < s.y + s.height) {
                return s;
            }
        }
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
    }

    function getFocusedScreen() {
        const focused = Hyprland.focusedMonitor;
        if (!focused)
            return null;

        for (let i = 0; i < Quickshell.screens.length; i++) {
            const s = Quickshell.screens[i];
            const monitor = Hyprland.monitorFor(s);
            if (monitor && monitor.name === focused.name)
                return s;
        }

        return null;
    }

    function computeX(cardWidth, margin) {
        if (!root.sourceItem || !root.screen)
            return margin;

        const globalPos = sourceGlobalPos();
        const localX = globalPos.x - root.screen.x;
        let menuX = localX + root.sourceItem.width / 2 - cardWidth / 2;

        if (menuX < margin)
            menuX = margin;
        if (menuX + cardWidth > root.screen.width - margin)
            menuX = root.screen.width - cardWidth - margin;

        return menuX;
    }

    function computeY(cardHeight, margin) {
        if (!root.sourceItem || !root.screen)
            return margin;

        const globalPos = sourceGlobalPos();
        const localY = globalPos.y - root.screen.y;
        const barPosition = Config.data?.bar?.position || "top";

        let menuY = barPosition === "bottom" ? localY - cardHeight - margin : localY + root.sourceItem.height + margin;

        if (menuY < margin) {
            menuY = localY + root.sourceItem.height + margin;
            if (menuY + cardHeight > root.screen.height - margin)
                menuY = Math.max(margin, root.screen.height - cardHeight - margin);
        }

        if (menuY + cardHeight > root.screen.height - margin) {
            menuY = localY - cardHeight - margin;
            if (menuY < margin)
                menuY = Math.max(margin, root.screen.height - cardHeight - margin);
        }

        return menuY;
    }
}
