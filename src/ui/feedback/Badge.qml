import QtQuick
import qs.src.core.config
import qs.src.ui.base

// Material Design 3 Badge
Rectangle {
    id: root

    property string text: ""
    property bool showDot: false  // Small dot badge without text
    property color badgeColor: Theme.error
    property color textColor: Theme.onError

    // Overlay (default) pins the badge to the parent's top-right corner — the
    // MD3 "badge on an icon" case. `inline: true` drops those anchors so the
    // same pill can sit in a Row/RowLayout as a plain count chip; without it,
    // every inline counter in the shell was a hand-rolled Rectangle + Text.
    property bool inline: false

    // Positioning relative to parent (overlay mode only)
    property int offsetX: -Tokens.spacing.extraSmall
    property int offsetY: -Tokens.spacing.extraSmall

    // Auto-sizing based on content
    implicitWidth: {
        if (showDot || text === "") return Tokens.size.badgeDot
        return Math.max(implicitHeight, badgeLabel.implicitWidth + Tokens.spacing.extraSmall * 2)
    }
    implicitHeight: {
        if (showDot || text === "") return Tokens.size.badgeDot
        return Math.max(Tokens.size.badgeMinimum, badgeLabel.implicitHeight + Tokens.spacing.extraSmall)
    }

    radius: height / 2  // Full radius (pill shape)
    color: root.badgeColor

    // Position at top-right corner of parent (skipped when inline)
    anchors {
        top: (root.inline || !parent) ? undefined : parent.top
        right: (root.inline || !parent) ? undefined : parent.right
        topMargin: root.offsetY
        rightMargin: root.offsetX
    }

    // Badge text
    MaterialText {
        id: badgeLabel
        visible: !root.showDot && root.text !== ""
        anchors.centerIn: parent
        text: root.text
        textStyle: "labelSmall"
        color: root.textColor
        font.weight: Font.Bold
    }
}
