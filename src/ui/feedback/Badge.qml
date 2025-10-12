import QtQuick
import qs.src.core.config
import qs.src.ui.base

// Material Design 3 Badge
Rectangle {
    id: root

    property string text: ""
    property bool showDot: false  // Small dot badge without text
    property color badgeColor: Config.colors.error
    property color textColor: Config.colors.onError

    // Positioning relative to parent
    property int offsetX: -4
    property int offsetY: -4

    // Auto-sizing based on content
    implicitWidth: {
        if (showDot || text === "") return 6
        return badgeLabel.width + 8  // 4dp padding on each side
    }
    implicitHeight: {
        if (showDot || text === "") return 6
        return 16
    }

    radius: width / 2  // Full radius (pill shape)
    color: root.badgeColor

    // Position at top-right corner of parent
    anchors {
        top: parent ? parent.top : undefined
        right: parent ? parent.right : undefined
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
