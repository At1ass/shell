import QtQuick
import qs.src.core.config
import qs.src.core.services

// One meter: the latest volume/brightness action wins, without overlapping cards.
OsdMeter {
    id: root
    property bool isVolume: true
    property bool muted: false
    namespacePart: "systemosd"
    title: isVolume ? (muted ? "Muted" : "Volume") : "Brightness"
    progressColor: isVolume && muted ? Theme.error : Theme.primary
    iconName: isVolume ? (muted ? "volume_off" : progress < 0.34 ? "volume_down" : "volume_up")
        : (progress < 0.34 ? "brightness_low" : progress < 0.67 ? "brightness_medium" : "brightness_high")
    function update(value, volume, mute) {
        if (GlobalStates.lockscreenActive) return
        progress = value
        isVolume = volume
        muted = mute
        present("")
        hideTimer.restart()
    }
    Timer { id: hideTimer; interval: AppConfig.osdTimeout; onTriggered: root.shown = false }
    Connections {
        target: AudioService
        function onVolumeChanged(volume, muted) { root.update(volume, true, muted) }
    }
    Connections {
        target: BrightnessService
        function onBrightnessAdjusted(value) { root.update(value, false, false) }
    }
    Connections {
        target: GlobalStates
        function onLockscreenActiveChanged() {
            if (GlobalStates.lockscreenActive) { root.shown = false; hideTimer.stop() }
        }
    }
}
