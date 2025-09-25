import QtQuick
import qs.config

Rectangle {
    id: card

    property int padding: Config.spacing.medium
    property bool outlined: true

    // Allow direct children insertions
    default property alias content: contentItem.children

    radius: Config.shape.large
    color: Config.colors.surfaceContainerHigh
    border.width: outlined ? 1 : 0
    border.color: outlined ? Config.colors.outlineVariant : "transparent"

    implicitWidth: contentItem.childrenRect.width + padding * 2
    implicitHeight: contentItem.childrenRect.height + padding * 2

    Item {
        id: contentItem
        anchors.fill: parent
        anchors.margins: padding
    }
}
