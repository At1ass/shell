pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.src.core.config
import qs.src.ui.base
import qs.src.ui.feedback
import qs.src.core.services

Scope {

    PanelWindow {
        id: launcherWindow
        visible: GlobalStates.launcherOpen

        // The output to map onto, resolved by GlobalStates.openPanel once per
        // open and before the open flag flips -- so this window is still
        // invisible when it moves, and a RETAINED panel still lands on the
        // monitor the user is looking at. Resolving in Component.onCompleted
        // was only correct while every open rebuilt the window.
        screen: GlobalStates.activePanelScreen ?? null

        WlrLayershell.namespace: "quickshell:launcher"
        color: "transparent"
        exclusiveZone: 0
        focusable: true

        anchors {
            left: true
            right: true
            top: true
            bottom: true
        }

        property bool grabReady: false
        function prepareGrab() {
            grabReady = false
            grabDelay.stop()
            if (visible) grabDelay.start()
        }
        Component.onCompleted: prepareGrab()
        onVisibleChanged: prepareGrab()
        Timer {
            id: grabDelay
            interval: Tokens.interaction.popupGrabDelay
            onTriggered: launcherWindow.grabReady = true
        }

        // Avoid consuming the mouse release that opened the launcher.
        HyprlandFocusGrab {
            id: focusGrab
            windows: [launcherWindow]
            active: GlobalStates.launcherOpen && launcherWindow.grabReady && contentLoader.active

            onCleared: {
                GlobalStates.closePanel("launcher")
            }
        }

        // MD3 Scrim (background dimming)
        Scrim {
            id: scrim
            shown: GlobalStates.launcherOpen
            duration: Tokens.motion.duration.medium4

            // MouseArea to close on scrim clicks
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    GlobalStates.closePanel("launcher")
                }
            }
        }

        // Content loader. Held active once the panel is retained, so the
        // expensive part -- LauncherContent and its providers -- is built once
        // rather than on every open. The entry animation below keys off the
        // open flag, not off construction, so it still runs on each open.
        Loader {
            id: contentLoader
            active: GlobalStates.launcherOpen || GlobalStates.panelRetained("launcher")
            width: Math.max(1, Math.min(AppConfig.launcherWidth, launcherWindow.width - Tokens.spacing.medium * 2))
            property real preferredHeight: 1
            function measuredHeight(component) { return component?.preferredHeight ?? 1 }
            function syncHeight() {
                if (item) preferredHeight = measuredHeight(item)
            }
            // Wrapped text settles during layout. Publish its measurement on
            // the next event turn rather than resizing its parent inside it.
            height: Math.max(1, Math.min(preferredHeight, launcherWindow.height
                - anchors.topMargin - Tokens.spacing.small
                - (AppConfig.barPosition === "bottom" ? BarMetrics.reservation : 0)))
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Math.min(Math.max(AppConfig.launcherTopMargin, (AppConfig.barPosition === "top" ? BarMetrics.reservation : 0) + Tokens.spacing.small), Math.max(Tokens.spacing.small, launcherWindow.height - Tokens.size.field - Tokens.panelPadding * 2))  // barHeight + MD3 spacing

            sourceComponent: Item {
                id: launcherCard
                readonly property real preferredHeight: launcherContent.implicitHeight
                onPreferredHeightChanged: Qt.callLater(contentLoader.syncHeight)

                // Created by a Loader with the open flag ALREADY true, so a
                // Behavior never saw a change and this animation was dead — see
                // Scrim._ready. The flag holds the binding at the start value
                // for one pass so the first evaluation is a real transition.
                property bool _ready: false
                Component.onCompleted: { launcherCard._ready = true; Qt.callLater(contentLoader.syncHeight) }

                // MD3 entrance animation (slide down + fade in)
                opacity: launcherCard._ready && GlobalStates.launcherOpen ? 1.0 : 0.0
                y: launcherCard._ready && GlobalStates.launcherOpen ? 0 : -Tokens.spacing.medium

                Behavior on opacity {
                    MotionAnimation {
                        duration: Tokens.motion.duration.medium4
                        curve: "emphasizedDecelerate"
                    }
                }

                Behavior on y {
                    MotionAnimation {
                        duration: Tokens.motion.duration.medium4
                        curve: "emphasizedDecelerate"
                    }
                }

                // Block clicks inside the content from the parent MouseArea
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        // Do nothing, just block the click from passing through
                    }
                }

                LauncherContent {
                    id: launcherContent
                    anchors.fill: parent
                }
            }
        }
    }
}
