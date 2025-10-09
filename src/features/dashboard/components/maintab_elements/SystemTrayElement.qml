import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.ui.feedback
import qs.src.core.config

MaterialCard {
    id: root
    color: Config.colors.surfaceContainerHigh
    radius: Config.shape.large

    // Properties for external menu/tooltip
    property var trayMenu: null
    property var trayTooltip: null

    RowLayout {
        anchors.fill: parent
        anchors.margins: Config.spacing.small
        spacing: Config.spacing.small

        Repeater {
            model: SystemTray.items

            Item {
                id: trayItem
                required property SystemTrayItem modelData

                width: 32
                height: 32

                property bool menuVisible: root.trayMenu && root.trayMenu.visible && root.trayMenu.sourceItem === trayItem

                // Background
                Rectangle {
                    id: iconBackground
                    anchors.fill: parent
                    color: "transparent"
                    radius: Config.shape.medium
                }

                // StateLayer for MD3 interaction (under icon)
                StateLayer {
                    anchors.fill: parent
                    layerColor: Config.colors.onSurface
                    hovered: trayMouseArea.containsMouse
                    pressed: trayMouseArea.pressed
                }

                // Tray icon
                Image {
                    id: trayIcon
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    source: root.getTrayIcon(trayItem.modelData.id, trayItem.modelData.icon)
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
                        event.accepted = true;

                        if (event.button == Qt.LeftButton) {
                            if (root.trayMenu && root.trayMenu.visible)
                                root.trayMenu.hideMenu();
                            trayItem.modelData.activate();
                        } else if (event.button == Qt.MiddleButton) {
                            if (root.trayMenu && root.trayMenu.visible)
                                root.trayMenu.hideMenu();
                            trayItem.modelData.secondaryActivate();
                        } else if (event.button == Qt.RightButton && trayItem.modelData.hasMenu) {
                            // Show menu through external component
                            if (root.trayMenu) {
                                if (root.trayTooltip)
                                    root.trayTooltip.hideTooltip();
                                root.trayMenu.showMenu(trayItem.modelData.menu, trayItem)
                            }
                        }
                    }

                    onWheel: event => {
                        event.accepted = true;
                        const points = event.angleDelta.y / 120;
                        trayItem.modelData.scroll(points, false);
                    }

                    onEntered: {
                        // Show tooltip through external component
                        if (root.trayTooltip && !trayItem.menuVisible) {
                            const tooltipText = trayItem.modelData.tooltipTitle ||
                                              trayItem.modelData.title ||
                                              trayItem.modelData.id
                            root.trayTooltip.showTooltip(tooltipText, trayItem)
                        }
                    }

                    onExited: {
                        // Hide tooltip
                        if (root.trayTooltip) {
                            root.trayTooltip.hideTooltip()
                        }
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
        }
    }

    function getTrayIcon(id: string, icon: string): string {
        if (icon.includes("?path=")) {
            const [name, path] = icon.split("?path=");
            icon = Qt.resolvedUrl(`${path}/${name.slice(name.lastIndexOf("/") + 1)}`);
        }
        return icon;
    }
}
