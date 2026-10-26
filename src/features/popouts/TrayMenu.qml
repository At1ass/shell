pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.src.core.config
import qs.src.ui.base
import qs.src.ui.containers

// StackView owns component-created pages, including their native menu openers.
StackView {
    id: root
    required property QsMenuHandle trayItem
    property real maximumHeight: Tokens.size.listItem * 10
    signal menuClosed()
    implicitWidth: (currentItem as Item)?.implicitWidth ?? Tokens.size.fieldWidth
    implicitHeight: (currentItem as Item)?.implicitHeight ?? 0
    initialItem: subMenuComponent
    pushEnter: Transition {}
    pushExit: Transition {}
    popEnter: Transition {}
    popExit: Transition {}
    clip: true

    function focusInitial() { if (currentItem) currentItem.forceActiveFocus(Qt.PopupFocusReason) }
    function back() {
        if (depth > 1) pop()
        else menuClosed()
    }
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Left) {
            root.back()
            event.accepted = true
        }
    }

    Component {
        id: subMenuComponent
        Item {
            id: menuPage
            property QsMenuHandle handle: root.trayItem
            property bool isSubMenu: false
            property int lastIndex: -1
            implicitWidth: Tokens.size.fieldWidth + Tokens.spacing.large * 2
            implicitHeight: Math.min(root.maximumHeight, body.implicitHeight)
            focus: true
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
                if (menuPage.handle || !menuPage.parentOpener || menuPage.entryLabel === "")
                    return;
                const entries = menuPage.parentOpener.children?.values ?? [];
                // Same label at the same position first: a Wi-Fi list can carry the
                // same SSID twice, and position is what tells those two apart.
                const exact = entries[menuPage.entryIndex];
                if (exact?.text === menuPage.entryLabel && exact.hasChildren) {
                    menuPage.handle = exact;
                    return;
                }
                for (const entry of entries) {
                    if (entry?.text === menuPage.entryLabel && entry.hasChildren) {
                        menuPage.handle = entry;
                        return;
                    }
                }
            }

            onHandleChanged: {
                if (menuPage.handle) {
                    lostTimer.stop();
                } else if (menuPage.parentOpener) {
                    menuPage.reresolve();
                    // The replacement usually arrives a beat later, with the
                    // parent's children signal; this only bounds the wait.
                    if (!menuPage.handle)
                        lostTimer.restart();
                }
            }

            Connections {
                target: menuPage.parentOpener
                enabled: menuPage.parentOpener !== null && !menuPage.handle

                function onChildrenChanged(): void {
                    menuPage.reresolve();
                }
            }

            Connections {
                target: menuPage.parentOpener?.children ?? null
                enabled: menuPage.parentOpener !== null && !menuPage.handle
                function onValuesChanged() { menuPage.reresolve() }
            }

            // If the entry is genuinely gone — Wi-Fi switched off, a VPN profile
            // deleted — go back a level instead of leaving an empty page up.
            Timer {
                id: lostTimer
                interval: Tokens.interaction.menuRefreshTimeout
                onTriggered: {
                    if (!menuPage.handle && root.depth > 1)
                        root.pop();
                }
            }


            function focusRow(start, direction) {
                for (let i = 0; i < rows.count; i++) {
                    const index = (start + direction * i + rows.count * 2) % rows.count
                    const row = rows.itemAt(index) as ListItem
                    if (row?.enabled && row.clickable) {
                        row.forceActiveFocus(Qt.TabFocusReason)
                        return
                    }
                }
                if (backRow.visible) backRow.forceActiveFocus(Qt.TabFocusReason)
            }
            onActiveFocusChanged: if (activeFocus) focusRow(Math.max(lastIndex, 0), 1)
            StackView.onActivated: Qt.callLater(() => { if (root.currentItem === menuPage) menuPage.focusRow(Math.max(menuPage.lastIndex, 0), 1) })

            QsMenuOpener { id: menuOpener; menu: menuPage.handle }
            ScrollableList {
                anchors.fill: parent
                spacing: 0
                ColumnLayout {
                    id: body
                    Layout.fillWidth: true
                    spacing: 0
                    ListItem {
                        id: backRow
                        Layout.fillWidth: true
                        visible: menuPage.isSubMenu
                        minimumHeight: Tokens.touchTarget.minimum
                        headline: "Back"
                        supportingText: menuPage.entryLabel
                        leadingIcon: "arrow_back"
                        onClicked: root.back()
                        Keys.onDownPressed: menuPage.focusRow(0, 1)
                        Keys.onUpPressed: menuPage.focusRow(rows.count - 1, -1)
                    }
                    Repeater {
                        id: rows
                        model: menuOpener.children
                        onItemAdded: (_index, _item) => Qt.callLater(() => {
                            if (root.currentItem === menuPage && menuPage.activeFocus)
                                menuPage.focusRow(Math.max(menuPage.lastIndex, 0), 1)
                        })
                        ListItem {
                            id: row
                            required property int index
                            required property QsMenuEntry modelData
                            readonly property bool separator: modelData?.isSeparator ?? true
                            readonly property bool checkable: !separator && (modelData?.buttonType ?? QsMenuButtonType.None) !== QsMenuButtonType.None
                            readonly property bool checked: (modelData?.checkState ?? Qt.Unchecked) !== Qt.Unchecked
                            Layout.fillWidth: true
                            minimumHeight: Tokens.touchTarget.minimum
                            // ColumnLayout uses layout hints, not height. A separator
                            // must not inherit an ordinary list row's implicit height.
                            Layout.preferredHeight: separator ? Tokens.spacing.small * 2 + Tokens.size.outline : implicitHeight
                            Layout.minimumHeight: Layout.preferredHeight
                            Layout.maximumHeight: Layout.preferredHeight
                            clickable: !separator
                            enabled: !separator && (modelData?.enabled ?? false)
                            headlineTextFormat: Text.PlainText
                            headline: separator ? "" : (modelData?.text ?? "")
                            leadingImageSource: !separator && !checkable ? (modelData?.icon ?? "") : ""
                            leadingIcon: !checkable ? "" : modelData?.buttonType === QsMenuButtonType.RadioButton
                                ? (checked ? "radio_button_checked" : "radio_button_unchecked")
                                : modelData?.checkState === Qt.PartiallyChecked ? "indeterminate_check_box"
                                : checked ? "check_box" : "check_box_outline_blank"
                            trailingIcon: !separator && (modelData?.hasChildren ?? false) ? "chevron_right" : ""
                            opacity: enabled || separator ? 1 : Tokens.state.disabledContentOpacity
                            Accessible.role: checkable ? Accessible.CheckBox : Accessible.MenuItem
                            Accessible.checkable: checkable
                            Accessible.checked: checked
                            onActiveFocusChanged: if (activeFocus) menuPage.lastIndex = index
                            function activate() {
                                const entry = row.modelData
                                if (!entry || !entry.enabled || entry.isSeparator) return
                                if (entry.hasChildren) {
                                    root.push(subMenuComponent, {
                                        handle: entry, isSubMenu: true,
                                        parentOpener: menuOpener,
                                        entryLabel: entry.text, entryIndex: row.index
                                    })
                                } else {
                                    entry.triggered()
                                    root.menuClosed()
                                }
                            }
                            onClicked: activate()
                            Keys.onPressed: event => {
                                switch (event.key) {
                                case Qt.Key_Down: menuPage.focusRow(row.index + 1, 1); break
                                case Qt.Key_Up: menuPage.focusRow(row.index - 1, -1); break
                                case Qt.Key_Home: menuPage.focusRow(0, 1); break
                                case Qt.Key_End: menuPage.focusRow(rows.count - 1, -1); break
                                case Qt.Key_Right: if (row.modelData?.hasChildren) row.activate(); break
                                case Qt.Key_Tab: menuPage.focusRow(row.index + (event.modifiers & Qt.ShiftModifier ? -1 : 1), event.modifiers & Qt.ShiftModifier ? -1 : 1); break
                                default: return
                                }
                                event.accepted = true
                            }
                            Divider { visible: row.separator; anchors.verticalCenter: parent.verticalCenter; width: parent.width }
                        }
                    }
                    MaterialText {
                        Layout.fillWidth: true
                        Layout.margins: Tokens.spacing.medium
                        visible: rows.count === 0
                        text: menuPage.handle ? "No actions available" : "Updating menu…"
                        colorRole: "onSurfaceVariant"
                    }
                }
            }
        }
    }
}
