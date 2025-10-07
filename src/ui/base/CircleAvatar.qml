import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import qs.src.core.config
import qs.src.ui.base

// Material Design 3 Circle Avatar
Rectangle {
    id: root

    // Size variants
    property string size: "medium"  // small, medium, large, extraLarge
    property int customSize: 0  // Override with custom size

    // Content
    property string imageSource: ""
    property string fallbackText: ""
    property string fallbackIcon: ""

    // Colors
    property color backgroundColor: Config.colors.primaryContainer
    property color foregroundColor: Config.colors.onPrimaryContainer

    // Calculate size
    readonly property int avatarSize: {
        if (customSize > 0) return customSize
        switch (size) {
            case "small": return 32
            case "large": return 48
            case "extraLarge": return 56
            default: return 40  // medium
        }
    }

    implicitWidth: avatarSize
    implicitHeight: avatarSize
    width: avatarSize
    height: avatarSize
    radius: avatarSize / 2
    color: root.backgroundColor

    // Image (if provided)
    Image {
        id: avatarImage
        visible: root.imageSource !== "" && status === Image.Ready
        anchors.fill: parent
        source: root.imageSource
        sourceSize.width: root.avatarSize
        sourceSize.height: root.avatarSize
        fillMode: Image.PreserveAspectCrop
        smooth: true

        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: avatarImage.width
                height: avatarImage.height
                radius: avatarImage.width / 2
            }
        }
    }

    // Fallback icon (if provided and no image)
    MaterialIcon {
        visible: root.imageSource === "" && root.fallbackIcon !== ""
        anchors.centerIn: parent
        iconName: root.fallbackIcon
        fontSize: root.avatarSize * 0.5
        iconColor: root.foregroundColor
        backgroundColor: "transparent"
    }

    // Fallback text (if provided and no image/icon)
    MaterialText {
        visible: root.imageSource === "" && root.fallbackIcon === "" && root.fallbackText !== ""
        anchors.centerIn: parent
        text: root.fallbackText.substring(0, 2).toUpperCase()
        textStyle: "titleMedium"
        color: root.foregroundColor
        font.weight: Font.Bold
    }
}
