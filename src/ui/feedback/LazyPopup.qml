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

        implicitWidth: popupBackground.implicitWidth + Config.spacing.large * 2 + root.popupBackgroundMargin
        implicitHeight: popupBackground.implicitHeight + Config.spacing.large * 2 + root.popupBackgroundMargin

        mask: Region {
            item: popupBackground
        }

        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0

        margins {
            left: {
                // Simple positioning in center-ish area
                return Math.max(100, (1920 / 2) - (popupBackground.implicitWidth / 2))
            }
            top: {
                // Position below the bar
                return 60
            }
        }

        WlrLayershell.namespace: "quickshell:popup"
        WlrLayershell.layer: WlrLayer.Overlay


        Rectangle {
            id: popupBackground
            readonly property real margin: Config.spacing.large
            anchors {
                fill: parent
                leftMargin: Config.spacing.large + root.popupBackgroundMargin
                rightMargin: Config.spacing.large + root.popupBackgroundMargin
                topMargin: Config.spacing.large + root.popupBackgroundMargin
                bottomMargin: Config.spacing.large + root.popupBackgroundMargin
            }

            implicitWidth: root.contentItem ? root.contentItem.implicitWidth + margin * 2 : 400
            implicitHeight: root.contentItem ? root.contentItem.implicitHeight + margin * 2 : 300

            color: Config.colors.surfaceContainerHigh
            radius: Config.shape.extraLarge
            children: root.contentItem ? [root.contentItem] : []

            border.width: 1
            border.color: Config.colors.outlineVariant

            // Simple shadow
            Rectangle {
                anchors.fill: parent
                anchors.topMargin: Config.spacing.small
                anchors.leftMargin: Config.spacing.small
                color: Qt.alpha("#000000", 0.1)
                radius: Config.shape.extraLarge
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
