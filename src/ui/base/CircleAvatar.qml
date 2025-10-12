import QtQuick
import QtQuick.Effects
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

    // Radius control
    property int customRadius: -1  // -1 = auto (circle), >= 0 = custom radius

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
    radius: customRadius >= 0 ? customRadius : avatarSize / 2  // Auto circle or custom
    color: root.backgroundColor

    // Image (if provided)
    Item {
        anchors.fill: parent
        visible: root.imageSource !== "" && avatarImage.status === Image.Ready
        Image {
            id: avatarImage
            anchors.fill: parent
            source: root.imageSource
            sourceSize.width: root.avatarSize
            sourceSize.height: root.avatarSize
            fillMode: Image.PreserveAspectCrop
            visible: false
            smooth: true
            asynchronous: true
            cache: true
        }

        MultiEffect {
            anchors.fill: parent
            source: avatarImage
            maskEnabled: true
            maskSource: maskItem
        }

        // Маска для скругления
        Item {
            id: maskItem
            anchors.fill: parent
            layer.enabled: true
            visible: false

            Rectangle {
                anchors.fill: parent
                radius: root.radius  // Использует тот же радиус (auto или custom)
                color: "white"
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
        // color: root.foregroundColor
        color: Qt.rgba (
            root.foregroundColor.r,
            root.foregroundColor.g,
            root.foregroundColor.b,
            0.87
        )
        font.weight: Font.Bold
    }
}
