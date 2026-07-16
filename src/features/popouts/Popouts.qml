import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.src.core.config
import qs.src.core.services
import qs.src.ui.containers


// Renders whatever popout request PopoutsState currently holds. This window
// never receives instance calls from consumers — all coordination is data in
// PopoutsState, so unloading this module degrades requests to no-ops.
PanelWindow {
    id: root

    readonly property string currentName: PopoutsState.name
    readonly property string currentMode: modeFor(currentName)
    readonly property QtObject currentData: PopoutsState.data
    readonly property Item sourceItem: PopoutsState.sourceItem

    readonly property bool hasPopout: PopoutsState.open

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
        active: root.visible && root.hasPopout && root.grabReady
        windows: [root]
        onCleared: {
            PopoutsState.closePopout();
        }
    }

    Timer {
        id: grabReadyTimer
        interval: 50
        repeat: false
        onTriggered: root.grabReady = true
    }

    // React to every open/close/re-open: pick the screen while the request
    // is live, re-arm the focus grab, reset published geometry on close.
    Connections {
        target: PopoutsState
        function onEpochChanged() {
            root.grabReady = false;
            grabReadyTimer.stop();
            if (PopoutsState.open) {
                root.screen = root.getSourceScreen() || root.getFocusedScreen() || Quickshell.screens[0] || root.screen;
                grabReadyTimer.start();
            } else {
                PopoutsState.setPopoutRect(0, 0, 0, 0, "");
            }
        }
    }

    Item {
        id: outsideClickLayer
        anchors.fill: parent
        visible: root.visible && root.hasPopout && root.currentMode === "card"
        z: 0

        // Keys must live on a focused Item — a PanelWindow has no Keys
        // attached property support.
        focus: true
        Keys.onEscapePressed: PopoutsState.closePopout()

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
                PopoutsState.closePopout();
            }
        }
    }

    Item {
        id: cardLayer
        anchors.fill: parent
        visible: root.visible && root.hasPopout && root.currentMode === "card"
        // z: 1

        readonly property real contentWidth: (popoutContent.item as Item)?.implicitWidth ?? 0
        readonly property real contentHeight: (popoutContent.item as Item)?.implicitHeight ?? 0
        readonly property real cardWidth: Math.max(contentWidth + Tokens.spacing.small * 2, 200)
        readonly property real cardHeight: contentHeight + Tokens.spacing.small * 2

        MaterialCard {
            id: popoutCard

            visible: cardLayer.visible
            opacity: visible ? 1 : 0
            scale: visible ? 1 : 0.95
            // z: 1

            color: Theme.surfaceContainerHigh
            radius: Tokens.shape.medium

            width: cardLayer.cardWidth
            height: cardLayer.cardHeight
            x: root.computeX(width, Tokens.spacing.small)
            y: root.computeY(height, Tokens.spacing.small)

            function updateRect() {
                if (root.currentMode !== "card" || !root.screen || !root.visible)
                    return;
                PopoutsState.setPopoutRect(x, y, width, height, root.screen?.name || "");
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
                color: Theme.primary
                opacity: Tokens.stateLayer.hoverOpacity
                // z: -1
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Tokens.motion.duration.short4
                    easing.type: Tokens.motion.easing.standard
                    easing.bezierCurve: Tokens.motion.easing.standardPoints
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: Tokens.motion.duration.short4
                    easing.type: Tokens.motion.easing.standard
                    easing.bezierCurve: Tokens.motion.easing.standardPoints
                }
            }

            Loader {
                id: popoutContent

                anchors.fill: parent
                anchors.margins: Tokens.spacing.small
                active: root.visible && root.hasPopout && root.currentMode === "card"
                asynchronous: true
                sourceComponent: root.popoutComponentFor(root.currentName)
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
            sourceComponent: root.popoutComponentFor(root.currentName)
        }
    }

    Component {
        id: trayMenuComponent
        TrayMenu {
            trayItem: root.currentData as QsMenuHandle
            onMenuClosed: {
                PopoutsState.closePopout();
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
        const barPosition = AppConfig.barPosition;

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
