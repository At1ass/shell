import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.src.core.config

LazyLoader {
    id: root

    property Item hoverTarget
    default property Item contentItem
    property real popupBackgroundMargin: 0
    property bool showManually: false

    active: (hoverTarget && hoverTarget.containsMouse) || showManually


    component: PanelWindow {
        id: popupWindow
        color: "transparent"

        // Position at top of screen (below bar)
        anchors.left: false
        anchors.top: true
        anchors.right: true
        anchors.bottom: false

        implicitWidth: popupBackground.implicitWidth + Tokens.spacing.large * 2 + root.popupBackgroundMargin
        implicitHeight: popupBackground.implicitHeight + Tokens.spacing.large * 2 + root.popupBackgroundMargin

        mask: Region {
            item: popupBackground
        }

        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0

        margins {
            left: {
                const sw = popupWindow.screen?.width ?? 1920
                return Math.max(100, (sw / 2) - (popupBackground.implicitWidth / 2))
            }
            top: AppConfig.barPosition === "top" ? AppConfig.barHeight + AppConfig.barMargin * 2 : 0
            bottom: AppConfig.barPosition === "bottom" ? AppConfig.barHeight + AppConfig.barMargin * 2 : 0
        }

        WlrLayershell.namespace: "quickshell:popup"
        WlrLayershell.layer: WlrLayer.Overlay


        Rectangle {
            id: popupBackground
            readonly property real margin: Tokens.spacing.large
            anchors {
                fill: parent
                leftMargin: Tokens.spacing.large + root.popupBackgroundMargin
                rightMargin: Tokens.spacing.large + root.popupBackgroundMargin
                topMargin: Tokens.spacing.large + root.popupBackgroundMargin
                bottomMargin: Tokens.spacing.large + root.popupBackgroundMargin
            }

            implicitWidth: root.contentItem ? root.contentItem.implicitWidth + margin * 2 : 400
            implicitHeight: root.contentItem ? root.contentItem.implicitHeight + margin * 2 : 300

            color: Theme.surfaceContainerHigh
            radius: Tokens.shape.extraLarge
            children: root.contentItem ? [root.contentItem] : []

            border.width: 1
            border.color: Theme.outlineVariant

            // Simple shadow
            Rectangle {
                anchors.fill: parent
                anchors.topMargin: Tokens.spacing.small
                anchors.leftMargin: Tokens.spacing.small
                color: Qt.alpha("#000000", 0.1)
                radius: Tokens.shape.extraLarge
                z: -1
            }

            Component.onCompleted: {
                if (root.contentItem) {
                    root.contentItem.anchors.fill = popupBackground
                    root.contentItem.anchors.margins = margin
                }
            }
        }
    }

    // Convenience methods
    function show() {
        showManually = true
    }

    function hide() {
        showManually = false
    }

    function toggle() {
        showManually = !showManually
    }
}
