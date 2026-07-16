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

                    onWheel: event => {
                        event.accepted = true
                        const points = event.angleDelta.y / 120
                        trayItem.modelData.scroll(points, false)
                    }
                }

            }
        }
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
