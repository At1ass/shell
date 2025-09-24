import QtQuick

Item {
    id: clockWidget

    property string currentTime: ""
    property string currentDate: ""
    property bool expanded: false

    width: timeContainer.width
    height: timeContainer.height

    Timer {
        id: timeTimer
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            const now = new Date()
            clockWidget.currentTime = Qt.formatTime(now, "hh:mm")
            clockWidget.currentDate = Qt.formatDate(now, "dd MMM")
        }
    }

    // Time display
    Rectangle {
        id: timeContainer
        width: expanded ? 160 : 70
        height: 32
        color: expanded ? "#4f378b" : "#49454f"
        radius: 16

        Row {
            anchors.centerIn: parent
            spacing: 6

            Text {
                id: timeText
                text: clockWidget.currentTime
                font.pixelSize: 14
                font.weight: Font.Medium
                color: expanded ? "#eaddff" : "#e6e1e5"
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                id: separator
                text: "•"
                font.pixelSize: 14
                color: expanded ? "#eaddff" : "#cab6cf"
                anchors.verticalCenter: parent.verticalCenter
                visible: expanded
            }

            Text {
                id: dateText
                text: clockWidget.currentDate
                font.pixelSize: 14
                color: expanded ? "#eaddff" : "#cab6cf"
                anchors.verticalCenter: parent.verticalCenter
                visible: expanded
            }
        }

        Behavior on width {
            NumberAnimation {
                duration: 250
                easing.type: Easing.OutQuad
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: 250
                easing.type: Easing.OutQuad
            }
        }
    }

    // Mouse area for hover interaction
    MouseArea {
        anchors.fill: timeContainer
        anchors.margins: -8  // Expand hover area
        hoverEnabled: true

        onEntered: {
            clockWidget.expanded = true
        }
        onExited: {
            clockWidget.expanded = false
        }
    }
}