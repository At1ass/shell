import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.src.core.config

// Material Design 3 Scrollable List Container
Item {
    id: root

    property int spacing: Tokens.spacing.small
    property int contentPadding: 0

    // Reveal a keyboard-focused descendant without polling or animating a
    // hidden subtree. Focus can move below the viewport after panel clamping.
    readonly property Item _focusedItem: {
        const focused = root.Window.window?.activeFocusItem ?? null
        for (let owner = focused; owner; owner = owner.parent)
            if (owner === contentLayout) return focused
        return null
    }
    readonly property rect _focusCursor: {
        const input = root._focusedItem as TextInput
        if (input) return input.cursorRectangle
        const edit = root._focusedItem as TextEdit
        return edit ? edit.cursorRectangle : Qt.rect(0, 0, 0, 0)
    }
    function contextFor(item) { return item?.focusContext ?? item }
    readonly property Item _focusContext: contextFor(_focusedItem)
    readonly property real _focusHeight: _focusContext?.height ?? 0
    on_FocusCursorChanged: Qt.callLater(root._revealFocus)
    on_FocusHeightChanged: Qt.callLater(root._revealFocus)
    on_FocusedItemChanged: Qt.callLater(root._revealFocus)
    on_FocusContextChanged: Qt.callLater(root._revealFocus)
    // Font scaling and panel clamping can move the same focused control
    // outside the viewport without producing another focus event.
    onHeightChanged: Qt.callLater(root._revealFocus)
    onWidthChanged: Qt.callLater(root._revealFocus)
    onVisibleChanged: if (visible) Qt.callLater(root._revealFocus)

    function _revealFocus() {
        if (!root.visible || !root._focusedItem) return
        const view = scrollView.contentItem as Flickable
        if (!view) return
        const margin = Tokens.spacing.small
        // An expanding editor may be taller than the viewport. Reveal its
        // caret rather than repeatedly scrolling to the bottom of the editor.
        const caret = root._focusCursor
        const useCaret = caret.height > 0 && root._focusedItem.height > view.height - margin * 2
        // Include supporting/error text when it fits. Large editors still
        // reveal their caret, rather than jumping to the end of the field.
        const target = !useCaret && root._focusHeight <= view.height - margin * 2 ? root._focusContext : root._focusedItem
        const top = target.mapToItem(contentLayout, 0, useCaret ? caret.y : 0).y + root.contentPadding
        const bottom = top + (useCaret ? caret.height : target.height)
        const maximum = Math.max(0, view.contentHeight - view.height)
        if (top < view.contentY + margin)
            view.contentY = Math.max(0, top - margin)
        else if (bottom > view.contentY + view.height - margin)
            view.contentY = Math.min(maximum, bottom + margin - view.height)
    }

    // Content data for child items
    default property alias contentData: contentLayout.data

    ScrollView {
        id: scrollView
        anchors.fill: parent
        clip: true
        // The viewport is infrastructure; Tab belongs to its controls.
        focusPolicy: Qt.NoFocus

        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: ScrollBar.AsNeeded

        // Content container
        Item {
            width: scrollView.availableWidth
            implicitHeight: contentLayout.implicitHeight + root.contentPadding * 2

            ColumnLayout {
                id: contentLayout
                onImplicitHeightChanged: Qt.callLater(root._revealFocus)
                anchors.fill: parent
                anchors.margins: root.contentPadding
                spacing: root.spacing
            }
        }
    }
}
