import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Services.SystemTray
import qs.components.base
import qs.components.tooltip
import qs.config
import qs.widgets

BarElement {
    id: trayWidget

    property var tooltipManager: null

    // BarElement configuration
    clickable: false
    // implicitWidth: 32 // Минимальная ширина, будет расширяться автоматически
    implicitWidth: trayLayout.width + 12

    Row {
        id: trayLayout
        spacing: Config.spacing.extraSmall
        width: childrenRect.width
        height: childrenRect.height
        // anchors.verticalCenter: parent.verticalCenter
        // anchors.right: parent.right
        // anchors.rightMargin: Config.spacing.small
        //

        Repeater {
            model: SystemTray.items

            Item {
                id: trayItem
                required property SystemTrayItem modelData

                property bool targetMenuOpen: false

                width: 24
                height: 24


                Rectangle {
                    id: iconBackground
                    anchors.fill: parent
                    color: mouseArea.containsMouse || trayItem.targetMenuOpen ?
                           Config.colors.surfaceContainerHighest : "transparent"
                    radius: Config.shape.small

                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }
                }

                Image {
                    id: trayIcon
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    source: trayItem.modelData.icon
                    sourceSize.width: width
                    sourceSize.height: height
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                    onClicked: event => {
                        event.accepted = true;

                        if (event.button == Qt.LeftButton) {
                            trayItem.modelData.activate();
                        } else if (event.button == Qt.MiddleButton) {
                            trayItem.modelData.secondaryActivate();
                        }
                    }

                    onPressed: event => {
                        if (event.button == Qt.RightButton && trayItem.modelData.hasMenu) {
                            trayItem.targetMenuOpen = !trayItem.targetMenuOpen;
                        }
                    }

                    onWheel: event => {
                        event.accepted = true;
                        const points = event.angleDelta.y / 120;
                        trayItem.modelData.scroll(points, false);
                    }
                }

                // Tooltip для иконки трея
                TooltipItem {
                    id: iconTooltip
                    tooltip: trayWidget.tooltipManager
                    owner: trayItem
                    show: mouseArea.containsMouse && !trayItem.targetMenuOpen

                    Column {
                        anchors.centerIn: parent
                        spacing: Config.spacing.extraSmall

                        MaterialText {
                            text: trayItem.modelData.tooltipTitle || trayItem.modelData.title || trayItem.modelData.id
                            textStyle: "bodyLarge"
                            colorRole: "surfaceText"
                            horizontalAlignment: Text.AlignHCenter
                            anchors.horizontalCenter: parent.horizontalCenter
                            wrapMode: Text.Wrap
                        }
                    }
                }

                // Контекстное меню
                TooltipItem {
                    id: contextMenu
                    tooltip: trayWidget.tooltipManager
                    owner: trayItem
                    isMenu: true
                    show: trayItem.targetMenuOpen && trayItem.modelData.hasMenu
                    animateSize: true

                    onClose: trayItem.targetMenuOpen = false

                    Loader {
                        id: menuLoader
                        active: trayItem.targetMenuOpen || contextMenu.visible

                        sourceComponent: Component {
                            SystemTrayMenuView {
                                menu: trayItem.modelData.menu
                                onMenuClosed: trayItem.targetMenuOpen = false
                            }
                        }
                    }
                }
            }
        }
    }
}
