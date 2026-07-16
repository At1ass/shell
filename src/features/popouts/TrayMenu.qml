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
                    easing.type: Tokens.motion.easing.standard
                    easing.bezierCurve: Tokens.motion.easing.standardPoints
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: Tokens.motion.duration.medium4
                    easing.type: Tokens.motion.easing.standard
                    easing.bezierCurve: Tokens.motion.easing.standardPoints
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

                    // NOT required/typed-strict on access: the DBus menu can
                    // destroy entries while delegates still exist (close,
                    // app-side model reset) — modelData auto-nulls and every
                    // binding below must tolerate it.
                    required property QsMenuEntry modelData

                    implicitWidth: 220
                    implicitHeight: (modelData?.isSeparator ?? false) ? 1 : contentLoader.implicitHeight

                    radius: Tokens.shape.medium
                    color: (modelData?.isSeparator ?? false) ? Theme.outlineVariant : "transparent"
                    border.width: 0

                    Loader {
                        // Named contentLoader — an id of `children` shadows
                        // Item.children.
                        id: contentLoader

                        anchors.left: parent.left
                        anchors.right: parent.right

                        active: !(item.modelData?.isSeparator ?? true)
                        asynchronous: true

                        sourceComponent: Item {
                            implicitHeight: label.implicitHeight + Tokens.spacing.extraSmall

                            MouseArea {
                                id: mouseArea

                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: item.modelData?.enabled ?? false

                                onClicked: {
                                    const entry = item.modelData;
                                    if (!entry) return;
                                    if (entry.hasChildren) {
                                        root.push(subMenuComponent.createObject(null, {
                                            handle: entry,
                                            isSubMenu: true
                                        }));
                                    } else {
                                        entry.triggered();
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

                                active: (item.modelData?.icon ?? "") !== ""
                                asynchronous: true

                                sourceComponent: IconImage {
                                    implicitSize: label.implicitHeight
                                    source: Qt.resolvedUrl(item.modelData?.icon ?? "")
                                }
                            }

                            MaterialText {
                                id: label

                                anchors.left: icon.active ? icon.right : parent.left
                                anchors.leftMargin: Tokens.spacing.extraSmall
                                anchors.right: rightIcon.left
                                anchors.rightMargin: Tokens.spacing.extraSmall
                                anchors.verticalCenter: parent.verticalCenter

                                text: item.modelData?.text ?? ""
                                textStyle: "bodyMedium"
                                colorRole: (item.modelData?.enabled ?? false) ? "onSurface" : "outline"
                                elide: Text.ElideRight
                            }

                            MaterialIcon {
                                id: rightIcon

                                anchors.right: parent.right
                                anchors.rightMargin: Tokens.spacing.extraSmall
                                anchors.verticalCenter: parent.verticalCenter

                                visible: item.modelData?.hasChildren ?? false
                                iconName: "chevron_right"
                                iconColor: (item.modelData?.enabled ?? false) ? Theme.onSurface : Theme.outline
                                fontSize: Tokens.typography.titleMedium.size
                            }
                        }
                    }
                }
            }
        }
    }
}
