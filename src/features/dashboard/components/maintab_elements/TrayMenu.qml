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

    // required property Item popouts
    required property QsMenuHandle trayItem

    signal menuClosed()

    implicitWidth: currentItem.implicitWidth
    implicitHeight: currentItem.implicitHeight

    initialItem: SubMenu {
        handle: root.trayItem
    }

    pushEnter: NoAnim {}
    pushExit: NoAnim {}
    popEnter: NoAnim {}
    popExit: NoAnim {}

    component NoAnim: Transition {
        NumberAnimation {
            duration: 0
        }
    }

    component SubMenu: Column {
        id: menu

        required property QsMenuHandle handle
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
                                    root.push(subMenuComp.createObject(null, {
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

                            sourceComponent: IconImage {
                                implicitSize: label.implicitHeight

                                source: item.modelData.icon
                            }
                        }

                        MaterialText {
                            id: label

                            anchors.left: icon.active ? icon.right : parent.left
                            anchors.leftMargin: icon.active ? Tokens.spacing.extraSmall : Tokens.spacing.small
                            anchors.verticalCenter: parent.verticalCenter

                            text: labelMetrics.elidedText
                            color: item.modelData.enabled ? Theme.onSurface : Theme.outline
                        }

                        TextMetrics {
                            id: labelMetrics

                            text: item.modelData.text
                            font.pointSize: label.font.pointSize
                            font.family: label.font.family

                            elide: Text.ElideRight
                            elideWidth: item.implicitWidth - (icon.active ? icon.implicitWidth + Tokens.spacing.small * 2 : Tokens.spacing.medium) - (expand.active ? expand.implicitWidth + Tokens.spacing.small * 2 : Tokens.spacing.small)
                        }

                        Loader {
                            id: expand

                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: parent.right
                            anchors.rightMargin: Tokens.spacing.extraSmall

                            active: item.modelData.hasChildren
                            asynchronous: true

                            sourceComponent: MaterialIcon {
                                iconName: "chevron_right"
                                iconColor: item.modelData.enabled ? Theme.onSurface : Theme.outline
                                backgroundColor: "transparent"
                            }
                        }
                    }
                }
            }
        }

        Loader {
            active: menu.isSubMenu
            asynchronous: true

            sourceComponent: Item {
                implicitWidth: back.implicitWidth
                implicitHeight: back.implicitHeight + Tokens.spacing.small / 2

                Item {
                    anchors.bottom: parent.bottom
                    implicitWidth: back.implicitWidth + Tokens.spacing.extraSmall * 2
                    implicitHeight: back.implicitHeight + Tokens.spacing.extraSmall

                    Rectangle {
                        anchors.fill: parent

                        radius: Tokens.shape.medium
                        color: Theme.secondaryContainer
                        border.width: 0

                        MouseArea {
                            id: backMouseArea
                            anchors.fill: parent
                            hoverEnabled: true

                            onClicked: {
                                root.pop();
                            }
                        }

                        StateLayer {
                            anchors.fill: parent
                            layerColor: Theme.onSecondaryContainer
                            hovered: backMouseArea.containsMouse
                            pressed: backMouseArea.pressed
                        }
                    }

                    Row {
                        id: back

                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: Tokens.spacing.extraSmall
                        spacing: Tokens.spacing.extraSmall / 2

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            iconName: "chevron_left"
                            iconColor: Theme.onSecondaryContainer
                            backgroundColor: "transparent"
                        }

                        MaterialText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Back")
                            color: Theme.onSecondaryContainer
                        }
                    }
                }
            }
        }
    }

    Component {
        id: subMenuComp

        SubMenu {}
    }
}
