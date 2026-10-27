pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.src.core.config
import qs.src.ui.containers

// Presentational menu; its owning surface handles dismissal and focus restore.
Surface {
    id: root
    property var model: []
    property int itemWidth: Tokens.size.fieldWidth
    property real maximumHeight: (root.Window.window?.height ?? Tokens.size.listItem * 10) - Tokens.spacing.large * 2
    property int _focusedIndex: -1
    signal triggered(int index)

    elevation: 2
    radius: Tokens.shape.extraSmall
    color: Theme.surfaceContainer
    implicitWidth: itemWidth
    implicitHeight: Math.min(maximumHeight, column.implicitHeight + Tokens.spacing.small * 2)

    function focusItem(start, direction) {
        if (!items.count) return
        for (let i = 0; i < items.count; i++) {
            const index = (start + direction * i + items.count * 2) % items.count
            const row = items.itemAt(index)
            if (row && row.enabled && row.activeFocusOnTab) {
                root._focusedIndex = index
                row.forceActiveFocus(Qt.TabFocusReason)
                return
            }
        }
    }
    function focusFirst() { root.focusItem(0, 1) }
    function focusNext(direction) {
        const step = direction < 0 ? -1 : 1
        root.focusItem(root._focusedIndex < 0 ? (step > 0 ? 0 : items.count - 1) : root._focusedIndex + step, step)
    }

    ScrollableList {
        anchors.fill: parent
        contentPadding: Tokens.spacing.small
        spacing: 0
        Column {
            id: column
            Layout.fillWidth: true
            Repeater {
                id: items
                model: root.model
                delegate: ListItem {
                    id: row
                    required property int index
                    required property var modelData
                    readonly property bool isObject: typeof modelData === "object" && modelData !== null
                    readonly property bool isSeparator: isObject && modelData.separator === true
                    width: column.width
                    height: isSeparator ? Tokens.spacing.small * 2 + Tokens.size.outline : implicitHeight
                    enabled: !isObject || modelData.enabled !== false
                    clickable: !isSeparator
                    headlineTextFormat: Text.PlainText
                    headline: isSeparator ? "" : (isObject ? modelData.label ?? "" : modelData)
                    leadingIcon: isObject ? modelData.icon ?? "" : ""
                    opacity: enabled ? 1 : Tokens.state.disabledContentOpacity
                    onActiveFocusChanged: if (activeFocus) root._focusedIndex = row.index
                    onClicked: root.triggered(row.index)
                    Keys.onPressed: event => {
                        switch (event.key) {
                        case Qt.Key_Tab: root.focusItem(row.index + (event.modifiers & Qt.ShiftModifier ? -1 : 1), event.modifiers & Qt.ShiftModifier ? -1 : 1); break
                        case Qt.Key_Down: root.focusItem(row.index + 1, 1); break
                        case Qt.Key_Up: root.focusItem(row.index - 1, -1); break
                        case Qt.Key_Home: root.focusFirst(); break
                        case Qt.Key_End: root.focusItem(items.count - 1, -1); break
                        default: return
                        }
                        event.accepted = true
                    }
                    Divider { visible: row.isSeparator; anchors.verticalCenter: parent.verticalCenter; width: parent.width }
                }
            }
        }
    }
}
