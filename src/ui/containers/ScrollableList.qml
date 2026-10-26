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
    readonly property Item _focusedItem: root.Window.window?.activeFocusItem ?? null
    on_FocusedItemChanged: Qt.callLater(root._revealFocus)
    // Font scaling and panel clamping can move the same focused control
    // outside the viewport without producing another focus event.
    onHeightChanged: Qt.callLater(root._revealFocus)
    onWidthChanged: Qt.callLater(root._revealFocus)
    onVisibleChanged: if (visible) Qt.callLater(root._revealFocus)

    function _revealFocus() {
        if (!root.visible || !root._focusedItem) return
        let owner = root._focusedItem
        while (owner && owner !== contentLayout) owner = owner.parent
        if (!owner) return
        const view = scrollView.contentItem as Flickable
        if (!view) return
        const top = root._focusedItem.mapToItem(contentLayout, 0, 0).y + root.contentPadding
        const bottom = top + root._focusedItem.height
        const margin = Tokens.spacing.small
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
