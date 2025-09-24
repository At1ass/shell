import QtQuick

Text {
    id: root

    renderType: Text.NativeRendering
    textFormat: Text.PlainText
    color: "#e6e1e5"
    font.family: "Inter, system-ui, sans-serif"
    font.pointSize: 10

    Behavior on color {
        ColorAnimation {
            duration: 300
            easing.type: Easing.OutQuad
        }
    }
}