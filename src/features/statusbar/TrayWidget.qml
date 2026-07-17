pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import qs.src.ui.base
import qs.src.ui.containers
import qs.src.ui.feedback
import qs.src.core.config
import qs.src.core.services

BarElement {
    id: root
    hoverable: true
    clickable: false
    minWidth: 48

    property var widgetConfig: null
    property var widgetSettings: widgetConfig?.settings ?? ({})
    property var tooltipManager: null

    property int iconSize: widgetSettings.iconSize ?? 20
    property int itemSpacing: widgetSettings.spacing ?? Tokens.spacing.small

    RowLayout {
        spacing: root.itemSpacing

        Repeater {
            model: SystemTray.items

            Item {
                id: trayItem
                required property SystemTrayItem modelData

                width: root.iconSize + Tokens.spacing.extraSmall * 2
                height: root.iconSize + Tokens.spacing.extraSmall * 2

                StateLayer {
                    anchors.fill: parent
                    layerColor: Theme.onSurface
                    hovered: trayMouseArea.containsMouse
                    pressed: trayMouseArea.pressed
                }

                Image {
                    anchors.centerIn: parent
                    width: root.iconSize
                    height: root.iconSize
                    source: root.getTrayIcon(trayItem.modelData.icon)
                    sourceSize.width: width
                    sourceSize.height: height
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                MouseArea {
                    id: trayMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                    onClicked: event => {
                        event.accepted = true

                        if (event.button === Qt.LeftButton) {
                            PopoutsState.closePopout()
                            // SNI ItemIsMenu: activate() is a no-op for
                            // menu-only items — open the menu instead.
                            if (trayItem.modelData.onlyMenu && trayItem.modelData.hasMenu)
                                PopoutsState.openPopout("traymenu", trayItem.modelData.menu, trayItem)
                            else
                                trayItem.modelData.activate()
                            return
                        }

                        if (event.button === Qt.MiddleButton) {
                            PopoutsState.closePopout()
                            trayItem.modelData.secondaryActivate()
                            return
                        }

                        if (event.button === Qt.RightButton && trayItem.modelData.hasMenu) {
                            PopoutsState.openPopout("traymenu", trayItem.modelData.menu, trayItem)
                        }
                    }

                    // scroll() takes INTEGER steps — touchpad deltas (<120)
                    // truncated to 0 and were discarded; accumulate them.
                    property real _wheelAccum: 0
                    onWheel: event => {
                        event.accepted = true
                        _wheelAccum += event.angleDelta.y / 120
                        const steps = _wheelAccum > 0 ? Math.floor(_wheelAccum) : Math.ceil(_wheelAccum)
                        if (steps !== 0) {
                            _wheelAccum -= steps
                            trayItem.modelData.scroll(steps, false)
                        }
                    }
                }

            }
        }
    }

    function getTrayIcon(icon) {
        // Quickshell's icon image provider resolves ?path= itself (theme
        // lookup FIRST, then the shipped directory) — the old manual split
        // skipped the theme lookup and broke nm-applet-style items.
        return icon || ""
    }
}
