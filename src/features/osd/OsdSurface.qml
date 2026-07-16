pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.src.core.config
import qs.src.ui.containers

// Shared OSD window shell: one overlay PanelWindow PER SCREEN, each bound
// to its own output (`screen: modelData` — without it the compositor maps
// every copy onto one monitor), scale+opacity reveal, MD3 card with outline
// and tokenized elevation tint. Concrete OSDs supply `contentComponent`
// (instantiated once per screen) and drive `shown`.
Scope {
    id: root

    property bool shown: false
    property string namespacePart: "osd"
    property string edge: "top"           // "top" | "bottom"
    property color cardColor: Theme.surfaceContainerHigh

    // 0 = size the card to its content.
    property int cardWidth: 0
    property int cardHeight: 0

    property Component contentComponent: null

    // OSD geometry spec — single definition site for the module.
    readonly property int topEdgeMargin: 80
    readonly property int bottomEdgeMargin: 48

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: osdWindow

            required property ShellScreen modelData
            screen: modelData

            visible: root.shown
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore

            WlrLayershell.namespace: "quickshell:" + root.namespacePart
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors {
                top: root.edge === "top"
                bottom: root.edge === "bottom"
            }
            margins {
                top: root.edge === "top" ? root.topEdgeMargin : 0
                bottom: root.edge === "bottom" ? root.bottomEdgeMargin : 0
            }

            implicitWidth: card.width
            implicitHeight: card.height

            Item {
                anchors.centerIn: parent
                width: card.width
                height: card.height

                opacity: root.shown ? 1 : 0
                scale: root.shown ? 1 : 0.92

                Behavior on opacity {
                    NumberAnimation {
                        duration: Tokens.motion.duration.short4
                        easing.type: Tokens.motion.easing.emphasized
                        easing.bezierCurve: Tokens.motion.easing.emphasizedPoints
                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: Tokens.motion.duration.short4
                        easing.type: Tokens.motion.easing.emphasized
                        easing.bezierCurve: Tokens.motion.easing.emphasizedPoints
                    }
                }

                MaterialCard {
                    id: card
                    color: root.cardColor
                    radius: Tokens.shape.extraLarge
                    width: root.cardWidth > 0 ? root.cardWidth : contentLoader.implicitWidth
                    height: root.cardHeight > 0 ? root.cardHeight : contentLoader.implicitHeight

                    SurfaceTint {
                        level: 2
                        radius: card.radius
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: card.radius
                        border.color: Theme.outlineVariant
                        border.width: 1
                        color: "transparent"
                    }

                    // Loader forwards the loaded item's implicit size as its
                    // own — used when cardWidth/cardHeight are 0.
                    Loader {
                        id: contentLoader
                        anchors.fill: parent
                        sourceComponent: root.contentComponent
                    }
                }
            }
        }
    }
}
