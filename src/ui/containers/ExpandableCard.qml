import QtQuick
import QtQuick.Layouts
import qs.src.core.config
import qs.src.ui.base

// A widget that works while collapsed and grows to show more.
//
// Not an accordion. An accordion collapses to a header -- a title bar that does
// nothing until opened. Here the compact form IS the widget doing its job (a
// player still plays, its transport still works) and expanding adds the second
// tier: queue, secondary actions, detail. So the default is compact and staying
// compact costs the user nothing.
//
// `expanded` is VIEW state and is deliberately not persisted. It describes what
// this panel looks like right now, not a preference, and a panel that reopened
// half-unfolded from last week would be surprising rather than helpful. This is
// the same call check.sh already exempts for notification group expansion.
Item {
    id: root

    // Always visible. Default slot, so the compact form reads as the component's
    // own content at the call site.
    default property alias compactContent: compactSlot.data
    property alias expandedContent: expandedSlot.data

    property bool expanded: false
    // Nothing to unfold into -- a player with no queue, a tile with no detail.
    // The control disappears rather than opening onto emptiness.
    property bool expandable: true
    property bool showToggle: true
    property int spacing: Tokens.spacing.small

    // Height this card is asking for beyond its collapsed size. A window sized
    // from a fixed table has to be told, or an unfolding section is simply
    // clipped -- and a hand-kept constant in the caller drifts the moment the
    // expanded content changes.
    readonly property int expandedDelta: (root.expanded && root.expandable)
                                         ? expandedSlot.implicitHeight + root.spacing
                                         : 0

    function toggle() {
        if (root.expandable)
            root.expanded = !root.expanded
    }

    function collapse() {
        root.expanded = false
    }

    implicitWidth: Math.max(compactRow.implicitWidth, expandedSlot.implicitWidth)
    implicitHeight: compactRow.implicitHeight
                    + (root.expanded && root.expandable
                       ? expandedSlot.implicitHeight + root.spacing
                       : 0)

    // Clipped, or the unfolding content spills past the animating height.
    clip: true

    Behavior on implicitHeight {
        MotionAnimation {
            duration: Tokens.motion.duration.medium2
            curve: "emphasizedDecelerate"
        }
    }

    RowLayout {
        id: compactRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Tokens.spacing.extraSmall

        Item {
            id: compactSlot
            Layout.fillWidth: true
            implicitWidth: childrenRect.width
            implicitHeight: childrenRect.height
        }

        IconButton {
            visible: root.showToggle && root.expandable
            iconName: root.expanded ? "expand_less" : "expand_more"
            iconSize: Tokens.iconSize.medium
            containerSize: Tokens.iconSize.extraLarge
            touchTargetSize: Tokens.iconSize.extraLarge
            colorRole: "onSurfaceVariant"
            onClicked: root.toggle()
        }
    }

    Item {
        id: expandedSlot
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: compactRow.bottom
        anchors.topMargin: root.spacing
        implicitHeight: childrenRect.height
        visible: root.expanded && root.expandable
        opacity: visible ? 1 : 0

        Behavior on opacity {
            MotionAnimation {
                duration: Tokens.motion.duration.short4
                curve: "standard"
            }
        }
    }
}
