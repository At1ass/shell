pragma ComponentBehavior: Bound

import qs.src.core.config
import qs.src.ui.feedback
import qs.src.ui.base
import qs.src.ui.containers
import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls

StackView {
    id: root

    required property QsMenuHandle trayItem

    signal menuClosed()

    implicitWidth: currentItem ? currentItem.implicitWidth : 0
    implicitHeight: currentItem ? currentItem.implicitHeight : 0

    initialItem: subMenuComponent

    pushEnter: noAnim
    pushExit: noAnim
    popEnter: noAnim
    popExit: noAnim

    Transition {
        id: noAnim
        NumberAnimation {
            duration: 0
        }
    }

    Component {
        id: subMenuComponent
        Column {
            id: menu

            property QsMenuHandle handle: root.trayItem
            property bool isSubMenu
            property bool shown

            padding: Tokens.spacing.extraSmall / 2
            spacing: 1

            opacity: shown ? 1 : 0
            scale: shown ? 1 : 0.8

            Component.onCompleted: shown = true
            StackView.onActivating: shown = true
            StackView.onDeactivating: shown = false
            StackView.onRemoved: destroy()

            Behavior on opacity {
                NumberAnimation {
                    duration: Tokens.motion.duration.medium4
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Tokens.motion.easing.standard
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: Tokens.motion.duration.medium4
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Tokens.motion.easing.standard
                }
            }

            QsMenuOpener {
                id: menuOpener
                menu: menu.handle
            }

            Repeater {
                model: menuOpener.children

                Rectangle {
                    id: item

                    required property QsMenuEntry modelData

                    implicitWidth: 220
                    implicitHeight: modelData.isSeparator ? 1 : children.implicitHeight

                    radius: Tokens.shape.medium
                    color: modelData.isSeparator ? Theme.outlineVariant : "transparent"
                    border.width: 0

                    Loader {
                        id: children

                        anchors.left: parent.left
                        anchors.right: parent.right

                        active: !item.modelData.isSeparator
                        asynchronous: true

                        sourceComponent: Item {
                            implicitHeight: label.implicitHeight + Tokens.spacing.extraSmall

                            MouseArea {
                                id: mouseArea

                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: item.modelData.enabled

                                onClicked: {
                                    const entry = item.modelData;
                                    if (entry.hasChildren) {
                                        root.push(subMenuComponent.createObject(null, {
                                            handle: entry,
                                            isSubMenu: true
                                        }));
                                    } else {
                                        item.modelData.triggered();
                                        root.menuClosed();
                                    }
                                }
                            }

                            StateLayer {
                                anchors.fill: parent
                                hovered: mouseArea.containsMouse
                                pressed: mouseArea.pressed
                            }

                            Loader {
                                id: icon

                                anchors.left: parent.left
                                anchors.leftMargin: Tokens.spacing.extraSmall
                                anchors.verticalCenter: parent.verticalCenter

                                active: item.modelData.icon !== ""
                                asynchronous: true

                                sourceComponent: MaterialIcon {
                                    iconName: item.modelData.icon
                                    iconColor: item.modelData.enabled ? "onSurface" : "outline"
                                    fontSize: Tokens.typography.titleMedium.size
                                }
                            }

                            MaterialText {
                                id: label

                                anchors.left: icon.active ? icon.right : parent.left
                                anchors.leftMargin: Tokens.spacing.extraSmall
                                anchors.right: rightIcon.left
                                anchors.rightMargin: Tokens.spacing.extraSmall
                                anchors.verticalCenter: parent.verticalCenter

                                text: item.modelData.text
                                textStyle: "bodyMedium"
                                colorRole: item.modelData.enabled ? "onSurface" : "outline"
                                elide: Text.ElideRight
                            }

                            MaterialIcon {
                                id: rightIcon

                                anchors.right: parent.right
                                anchors.rightMargin: Tokens.spacing.extraSmall
                                anchors.verticalCenter: parent.verticalCenter

                                visible: item.modelData.hasChildren
                                iconName: "chevron_right"
                                iconColor: item.modelData.enabled ? "onSurface" : "outline"
                                fontSize: Tokens.typography.titleMedium.size
                            }
                        }
                    }
                }
            }
        }
    }
}
