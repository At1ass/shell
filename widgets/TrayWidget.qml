import QtQuick

Column {
    id: trayWidget

    spacing: 2

    Rectangle {
        width: 40
        height: 32
        color: "#49454f"
        radius: 16

        // Placeholder tray icon
        Rectangle {
            anchors.centerIn: parent
            width: 8
            height: 8
            radius: 4
            color: "#938f99"
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                console.log("System tray clicked")
            }
        }
    }
}