pragma ComponentBehavior: Bound

import qs.src.core.config
import qs.src.ui.feedback
import qs.src.ui.base
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

            // Re-resolution, for menus that rebuild themselves underneath us.
            //
            // libdbusmenu applications periodically discard their whole menu tree
            // and publish a fresh one with NEW item ids. nm-applet does it every
            // few seconds while a wireless device is scanning: the id of its
            // "Available networks" entry walked 1467 -> 1528 -> 1590 -> 1654 ->
            // 1721 inside 80 seconds, and by then the tree had been rebuilt from
            // 1427 to 2007. Quickshell drops items whose id is missing from the
            // new layout, so the handle a pushed page was opened with is destroyed
            // under it — children empty, the column shrinks to its padding, and
            // the submenu the user was reading collapses to a sliver.
            //
            // The same entry comes straight back under a new id with the same
            // label, so the page re-points itself at it instead of dying. The
            // parent level is the only place that can be asked, hence parentOpener.
            property QsMenuOpener parentOpener: null
            property string entryLabel: ""
            property int entryIndex: -1

            function reresolve(): void {
                if (menu.handle || !menu.parentOpener || menu.entryLabel === "")
                    return;
                const entries = menu.parentOpener.children?.values ?? [];
                // Same label at the same position first: a Wi-Fi list can carry the
                // same SSID twice, and position is what tells those two apart.
                const exact = entries[menu.entryIndex];
                if (exact?.text === menu.entryLabel && exact.hasChildren) {
                    menu.handle = exact;
                    return;
                }
                for (const entry of entries) {
                    if (entry?.text === menu.entryLabel && entry.hasChildren) {
                        menu.handle = entry;
                        return;
                    }
                }
            }

            onHandleChanged: {
                if (menu.handle) {
                    lostTimer.stop();
                } else if (menu.parentOpener) {
                    menu.reresolve();
                    // The replacement usually arrives a beat later, with the
                    // parent's children signal; this only bounds the wait.
                    if (!menu.handle)
                        lostTimer.restart();
                }
            }

            Connections {
                target: menu.parentOpener
                enabled: menu.parentOpener !== null && !menu.handle

                function onChildrenChanged(): void {
                    menu.reresolve();
                }
            }

            // If the entry is genuinely gone — Wi-Fi switched off, a VPN profile
            // deleted — go back a level instead of leaving an empty page up.
            Timer {
                id: lostTimer
                interval: 3000
                onTriggered: {
                    if (!menu.handle && root.depth > 1)
                        root.pop();
                }
            }

            padding: Tokens.spacing.extraSmall / 2
            spacing: 1

            opacity: shown ? 1 : 0
            scale: shown ? 1 : 0.8

            Component.onCompleted: shown = true
            StackView.onActivating: shown = true
            StackView.onDeactivating: shown = false
            StackView.onRemoved: destroy()

            Behavior on opacity {
                MotionAnimation {
                    duration: Tokens.motion.duration.medium4
                    curve: "standard"
                }
            }

            Behavior on scale {
                MotionAnimation {
                    duration: Tokens.motion.duration.medium4
                    curve: "standard"
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
                                            isSubMenu: true,
                                            parentOpener: menuOpener,
                                            entryLabel: entry.text,
                                            entryIndex: (menuOpener.children?.values ?? []).indexOf(entry)
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
