import QtQuick
import qs.src.core.config
import qs.src.core.services

// Volume OSD — service wiring around the shared OsdMeter surface.
OsdMeter {
    id: root

    property real currentVolume: 0
    property bool currentMuted: false

    namespacePart: "volumeosd"
    title: currentMuted ? "Muted" : "Volume"
    progress: currentVolume
    badgeColor: currentMuted ? Theme.errorContainer : Theme.primaryContainer
    badgeContentColor: currentMuted ? Theme.onErrorContainer : Theme.onPrimaryContainer
    progressColor: currentMuted ? Theme.error : Theme.primary
    iconName: {
        if (currentMuted) return "volume_off"
        if (currentVolume <= 0.001) return "volume_mute"
        if (currentVolume < 0.34) return "volume_down"
        return "volume_up"
    }

    Timer {
        id: hideTimer
        interval: AppConfig.osdTimeout
        repeat: false
        onTriggered: root.shown = false
    }

    Connections {
        target: AudioService
        function onVolumeChanged(volume, muted) {
            root.currentVolume = volume
            root.currentMuted = muted
            root.shown = true
            hideTimer.restart()
        }
    }
}
