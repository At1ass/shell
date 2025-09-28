import QtQuick
import QtQuick.Layouts
import qs.src.ui.containers
import qs.src.ui.inputs
import qs.src.ui.feedback
import QtQuick.Controls
import Quickshell
import Quickshell.Services.SystemTray
import qs.src.ui.base
import qs.src.ui.feedback
import qs.src.core.config
import qs.src.features.statusbar

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

                    // Дополнительный эффект при hover
                    scale: mouseArea.containsMouse ? 1.1 : 1.0
                    opacity: mouseArea.containsMouse ? 0.8 : 1.0

                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }

                    Behavior on scale {
                        SmoothedAnimation { velocity: 8; duration: 100 }
                    }

                    Behavior on opacity {
                        SmoothedAnimation { velocity: 6; duration: 120 }
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
                    animateSize: false

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
