import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components.base
import qs.config

ColumnLayout {
    id: root

    property alias menu: menuView.menu
    property Item animatingItem: null
    property bool animating: animatingItem != null

    signal menuClosed()

    QsMenuOpener { id: menuView }

    spacing: 0
    implicitWidth: 200

    Repeater {
        model: menuView.children

        Loader {
            required property var modelData

            Layout.fillWidth: true
            Layout.preferredHeight: item ? item.height : 0

            sourceComponent: modelData.isSeparator ? separatorComponent : menuItemComponent

            Component {
                id: separatorComponent
                Rectangle {
                    height: 9
                    color: "transparent"

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width - Config.spacing.medium
                        height: 1
                        color: Config.colors.outline
                        opacity: 0.3
                    }
                }
            }

            Component {
                id: menuItemComponent
                Rectangle {
                    id: menuItem
                    height: Math.max(32, contentColumn.implicitHeight + Config.spacing.small)
                    color: mouseArea.containsMouse ? Config.colors.surfaceContainerHigh : "transparent"
                    radius: Config.shape.extraSmall

                    property bool hasSubmenu: modelData.hasSubmenu || false
                    property bool isCheckable: modelData.checkable || false
                    property bool isChecked: modelData.checked || false
                    property bool isEnabled: modelData.enabled

                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: menuItem.isEnabled

                        onClicked: {
                            if (modelData.hasSubmenu) {
                                // Для подменю можно добавить логику позже
                                return
                            }

                            modelData.triggered()
                            root.menuClosed()
                        }
                    }

                    Row {
                        id: contentColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Config.spacing.medium
                        anchors.rightMargin: Config.spacing.medium
                        spacing: Config.spacing.small

                        // Иконка чекбокса/радио
                        Item {
                            width: 16
                            height: 16
                            anchors.verticalCenter: parent.verticalCenter
                            visible: menuItem.isCheckable

                            Rectangle {
                                anchors.centerIn: parent
                                width: 12
                                height: 12
                                radius: 2
                                color: menuItem.isChecked ? Config.colors.primary : "transparent"
                                border.color: Config.colors.outline
                                border.width: 1

                                MaterialText {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    textStyle: "labelSmall"
                                    colorRole: "primaryText"
                                    visible: menuItem.isChecked
                                }
                            }
                        }

                        // Иконка пункта меню
                        Image {
                            width: 16
                            height: 16
                            anchors.verticalCenter: parent.verticalCenter
                            source: modelData.icon
                            visible: source.toString() !== ""
                            sourceSize.width: width
                            sourceSize.height: height
                            fillMode: Image.PreserveAspectFit
                        }

                        // Текст пункта меню
                        MaterialText {
                            text: modelData.text || ""
                            textStyle: "bodyMedium"
                            colorRole: menuItem.isEnabled ? "surfaceText" : "surfaceVariantText"
                            anchors.verticalCenter: parent.verticalCenter
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        // Индикатор подменю
                        MaterialText {
                            text: "▶"
                            textStyle: "labelSmall"
                            colorRole: "surfaceVariantText"
                            anchors.verticalCenter: parent.verticalCenter
                            visible: menuItem.hasSubmenu
                        }
                    }

                    // Затемнение для неактивных пунктов
                    Rectangle {
                        anchors.fill: parent
                        color: Config.colors.surface
                        opacity: menuItem.isEnabled ? 0 : 0.5
                        radius: parent.radius
                    }
                }
            }
        }
    }
}