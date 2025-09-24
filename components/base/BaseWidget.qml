import QtQuick

Rectangle {
    id: root

    property alias content: contentLoader.sourceComponent
    property bool hovered: mouseArea.containsMouse
    property bool pressed: mouseArea.pressed
    property int elevation: 1
    property bool animated: true

    width: implicitWidth
    height: implicitHeight
    implicitWidth: 56
    implicitHeight: contentLoader.implicitHeight + 16

    color: "#1c1b1f"
    radius: 8

    // Material Design state layer
    Rectangle {
        id: stateLayer
        anchors.fill: parent
        radius: parent.radius
        color: "#e6e1e5"
        opacity: {
            if (pressed) return 0.12
            if (hovered) return 0.08
            return 0.0
        }

        Behavior on opacity {
            enabled: root.animated
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutQuad
            }
        }
    }

    // Shadow effect for elevation
    Rectangle {
        anchors.fill: parent
        anchors.topMargin: elevation
        color: "#000000"
        opacity: 0.1 * elevation
        radius: parent.radius
        z: -1
        visible: elevation > 0
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
    }

    Loader {
        id: contentLoader
        anchors.centerIn: parent
        anchors.margins: 8
    }

    // Scale animation on press
    scale: pressed ? 0.95 : 1.0
    Behavior on scale {
        enabled: root.animated
        NumberAnimation {
            duration: 150
            easing.type: Easing.OutQuad
        }
    }
}