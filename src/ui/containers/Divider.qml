import QtQuick
import qs.src.core.config

// Material Design 3 Divider
Rectangle {
    id: root

    property int insetStart: 0
    property int insetEnd: 0
    property bool vertical: false

    implicitWidth: vertical ? 1 : parent ? parent.width : 0
    implicitHeight: vertical ? (parent ? parent.height : 0) : 1

    // Positioning with insets
    x: vertical ? 0 : insetStart
    width: vertical ? 1 : (parent ? parent.width - insetStart - insetEnd : 0)
    height: vertical ? (parent ? parent.height : 0) : 1

    // MD3 spec: outlineVariant color, no additional opacity
    color: Config.colors.outlineVariant
    opacity: 1.0
}
