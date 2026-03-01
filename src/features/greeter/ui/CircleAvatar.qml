import QtQuick
import QtQuick.Effects
import qs.config

Rectangle {
    id: root

    property string size: "medium"
    property int customSize: 0

    property string imageSource: ""
    property string fallbackText: ""
    property string fallbackIcon: ""

    property color backgroundColor: GreeterTheme.primaryContainer
    property color foregroundColor: GreeterTheme.onPrimaryContainer

    property int customRadius: -1

    readonly property int avatarSize: {
        if (customSize > 0) return customSize
        switch (size) {
            case "small": return 32
            case "large": return 48
            case "extraLarge": return 56
            default: return 40
        }
    }

    implicitWidth: avatarSize
    implicitHeight: avatarSize
    width: avatarSize
    height: avatarSize
    radius: customRadius >= 0 ? customRadius : avatarSize / 2
    color: root.backgroundColor

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

        Item {
            id: maskItem
            anchors.fill: parent
            layer.enabled: true
            visible: false

            Rectangle {
                anchors.fill: parent
                radius: root.radius
                color: "white"
            }
        }
    }

    MaterialIcon {
        visible: root.imageSource === "" && root.fallbackIcon !== ""
        anchors.centerIn: parent
        iconName: root.fallbackIcon
        fontSize: root.avatarSize * 0.5
        iconColor: root.foregroundColor
        backgroundColor: "transparent"
    }

    MaterialText {
        visible: root.imageSource === "" && root.fallbackIcon === "" && root.fallbackText !== ""
        anchors.centerIn: parent
        text: root.fallbackText.substring(0, 2).toUpperCase()
        textStyle: "titleMedium"
        color: Qt.rgba(
            root.foregroundColor.r,
            root.foregroundColor.g,
            root.foregroundColor.b,
            0.87
        )
        font.weight: Font.Bold
    }
}
