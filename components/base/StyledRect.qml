import QtQuick

Rectangle {
    id: root

    color: "#1c1b1f"

    Behavior on color {
        ColorAnimation {
            duration: 300
            easing.type: Easing.OutQuad
        }
    }
}