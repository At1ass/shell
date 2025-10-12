import QtQuick
import qs.src.core.config
import qs.src.ui.containers

// Material Design 3 Dialog
Rectangle {
    id: root
    anchors.fill: parent

    // MD3 Scrim (backdrop) - RGBA(0,0,0,0.32)
    color: Qt.rgba(0, 0, 0, 0.32)

    visible: false
    opacity: 0

    // Properties
    property int dialogWidth: 400
    property int dialogHeight: 400  // Default height
    default property alias content: contentWrapper.children

    // Signals
    signal opened()
    signal closed()

    // MD3 animation
    Behavior on opacity {
        NumberAnimation {
            duration: Config.motion.duration.short4
            easing.type: Config.motion.easing.emphasizedDecelerate
        }
    }

    // Scrim click to close
    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    // Dialog container
    MaterialCard {
        id: dialogCard
        anchors.centerIn: parent
        width: root.dialogWidth
        height: root.dialogHeight

        color: Config.colors.surfaceContainerHigh
        radius: Config.shape.extraLarge

        // Scale animation (MD3 spec: 0.8 → 1.0)
        scale: root.opacity * 0.2 + 0.8

        Behavior on scale {
            NumberAnimation {
                duration: Config.motion.duration.short4
                easing.type: Config.motion.easing.emphasizedDecelerate
            }
        }

        // Block clicks from propagating to scrim
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        // Content wrapper
        Item {
            id: contentWrapper
            width: parent.width
            height: parent.height
        }
    }

    // Public API
    function open() {
        root.visible = true
        root.opacity = 1
        opened()
    }

    function close() {
        root.opacity = 0
        closeTimer.start()
    }

    Timer {
        id: closeTimer
        interval: Config.motion.duration.short4
        onTriggered: {
            root.visible = false
            closed()
        }
    }
}
