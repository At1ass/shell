import QtQuick
import qs.src.core.config
import qs.src.core.services

// Brightness OSD — service wiring around the shared OsdMeter surface.
OsdMeter {
    id: root

    property real currentBrightness: 0.5

    namespacePart: "brightnessosd"
    title: "Brightness"
    progress: currentBrightness
    iconName: {
        if (currentBrightness < 0.34) return "brightness_low"
        if (currentBrightness < 0.67) return "brightness_medium"
        return "brightness_high"
    }

    Timer {
        id: hideTimer
        interval: AppConfig.osdTimeout
        repeat: false
        onTriggered: root.shown = false
    }

    Connections {
        target: BrightnessService
        function onBrightnessAdjusted(value) {
            root.currentBrightness = value
            root.shown = true
            hideTimer.restart()
        }
    }
}
