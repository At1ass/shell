import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import qs.src.ui.containers
import qs.src.ui.feedback
import qs.src.core.config
import qs.src.core.services

BarElement {
    id: root
    hoverable: true
    clickable: widgetConfig?.clickAction ? true : false
    minWidth: 48

    property var widgetConfig: null
    property var widgetSettings: widgetConfig?.settings ?? ({})
    property var tooltipManager: null

    property int iconSize: widgetSettings.iconSize ?? 20
    property int itemSpacing: widgetSettings.spacing ?? Config.spacing.small

    clickHandler: function(mouse) {
        if (mouse.button === Qt.RightButton && widgetConfig?.clickAction) {
            GlobalStates.handleClickAction(widgetConfig.clickAction)
            mouse.accepted = true
            return
        }

        mouse.accepted = false
    }

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
                    source: root.getTrayIcon(modelData.icon)
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
                            modelData.activate()
                            return
                        }

                        if (event.button === Qt.MiddleButton) {
                            modelData.secondaryActivate()
                            return
                        }

                        if (event.button === Qt.RightButton && modelData.hasMenu) {
                            root.showMenu(modelData, trayItem)
                        }
                    }

                    onWheel: event => {
                        event.accepted = true
                        const points = event.angleDelta.y / 120
                        modelData.scroll(points, false)
                    }
                }

                ToolTip {
                    visible: trayMouseArea.containsMouse
                    text: modelData.tooltipTitle || modelData.title || modelData.id
                    delay: 500
                }
            }
        }
    }

    function showMenu(item, sourceItem) {
        if (!root.window || !item || !item.hasMenu)
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
