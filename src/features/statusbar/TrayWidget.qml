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
    // clickable: widgetConfig?.clickAction ? true : false
    clickable: false
    minWidth: 48

    property var widgetConfig: null
    property var widgetSettings: widgetConfig?.settings ?? ({})
    property var tooltipManager: null
    readonly property var currentTrayItem: null
    property var popouts: null

    property int iconSize: widgetSettings.iconSize ?? 20
    property int itemSpacing: widgetSettings.spacing ?? Config.spacing.small

    // clickHandler: function(mouse) {
    //     if (mouse.button === Qt.RightButton && widgetConfig?.clickAction) {
    //         GlobalStates.handleClickAction(widgetConfig.clickAction)
    //         mouse.accepted = true
    //         return
    //     }
    //
    //     mouse.accepted = false
    // }

    // nonVisualChildren: [
    //     // Simple hover tooltip for track info
    //     TooltipItem {
    //         id: hoverTooltip
    //         tooltip: root.tooltipManager
    //         owner: root
    //         isMenu: false
    //         hoverable: true
    //         show: root.hovered && (typeof MprisController !== 'undefined') && !!MprisController.activePlayer
    //
    //         MaterialText {
    //             text: root.currentTrayItem
    //                 // if (typeof MprisController === 'undefined' || !MprisController.activeTrack)
    //                 //     return "Нет воспроизведения";
    //                 // const title = MprisController.activeTrack.title || "Unknown Title";
    //                 // const artist = MprisController.activeTrack.artist || "Unknown Artist";
    //                 // return `${title} — ${artist}`;
    //             //     visible: trayMouseArea.containsMouse
    //             //     delay: 500
    //             textStyle: "bodyMedium"
    //             colorRole: "onSurface"
    //         }
    //     }
    // ]
    RowLayout {
        spacing: root.itemSpacing

        Repeater {
            model: SystemTray.items

            Item {
                id: trayItem
                required property SystemTrayItem modelData

                width: root.iconSize + Config.spacing.extraSmall * 2
                height: root.iconSize + Config.spacing.extraSmall * 2

                StateLayer {
                    anchors.fill: parent
                    layerColor: Config.colors.onSurface
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
                    // onPressed: event => {
                    console.log("TrayWidget: clicked on tray item", trayItem.modelData.id, "button:", event.button)
                        event.accepted = true

                        if (event.button === Qt.LeftButton) {
                            if (root.popouts && root.popouts.visible)
                                root.popouts.closePopout()
                            trayItem.modelData.activate()
                            return
                        }

                        if (event.button === Qt.MiddleButton) {
                            if (root.popouts && root.popouts.visible)
                                root.popouts.closePopout()
                            trayItem.modelData.secondaryActivate()
                            return
                        }

                        if (event.button === Qt.RightButton && trayItem.modelData.hasMenu) {
                            if (root.popouts) {
                                root.popouts.openPopout("traymenu", trayItem.modelData.menu, trayItem)
                                return
                            }
                            root.showMenu(trayItem.modelData, trayItem)
                        }
                    }

                    onWheel: event => {
                        event.accepted = true
                        const points = event.angleDelta.y / 120
                        trayItem.modelData.scroll(points, false)
                    }
                }

                // ToolTip {
                //     visible: trayMouseArea.containsMouse
                //     text: trayItem.modelData.tooltipTitle || trayItem.modelData.title || trayItem.modelData.id
                //     delay: 500
                // }
            }
        }
    }

    function showMenu(item, sourceItem) {
        if (!item || !item.hasMenu)
            return

        const windowItem = root.window.contentItem || root
        const pos = sourceItem.mapToItem(windowItem, 0, sourceItem.height)
        item.display(root.window, pos.x, pos.y)
    }

    function getTrayIcon(icon) {
        if (!icon)
            return ""
        if (icon.includes("?path=")) {
            const [name, path] = icon.split("?path=")
            return Qt.resolvedUrl(`${path}/${name.slice(name.lastIndexOf("/") + 1)}`)
        }
        return icon
    }
}
