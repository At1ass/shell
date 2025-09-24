import QtQuick

Column {
    id: systemWidget

    spacing: 2

    Rectangle {
        width: 80
        height: 32
        color: "#49454f"
        radius: 16

        Row {
            anchors.centerIn: parent
            spacing: 4

            // Network indicator (placeholder)
            Rectangle {
                width: 4
                height: 4
                radius: 2
                color: "#ccc2dc"
            }

            // Battery indicator (placeholder)
            Rectangle {
                width: 4
                height: 4
                radius: 2
                color: "#efb8c8"
            }

            // Audio indicator (placeholder)
            Rectangle {
                width: 4
                height: 4
                radius: 2
                color: "#d0bcff"
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                console.log("System widget clicked")
            }
        }
    }
}