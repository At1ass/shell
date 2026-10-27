import QtQuick
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.core.config
import qs.src.core.services

BarElement {
    id: root
    minWidth: Tokens.size.control
    preferredWidth: Math.max(minWidth, volumeIcon.implicitWidth + Tokens.spacing.medium
        + (showPercentage ? volumeLabel.implicitWidth + Tokens.spacing.small : 0))
    minimumWidth: preferredWidth
    compactWidth: Math.max(minWidth, volumeIcon.implicitWidth + Tokens.spacing.medium)
    clickable: true
    hoverable: true

    property var widgetConfig: null
    property var widgetSettings: widgetConfig?.settings ?? ({})
    property bool scrollable: widgetSettings.scrollable ?? true
    property bool showPercentage: widgetSettings.showPercentage ?? true

    property var tooltipManager: null

    readonly property var sink: AudioService.defaultSink
    readonly property bool audioAvailable: !!sink?.audio
    accessibleName: audioAvailable ? (AudioService.masterMuted ? "Output muted" : "Output " + formatVolume(AudioService.masterVolume)) : "No output device"

    function formatVolume(value) {
        if (value === null || value === undefined) return "--%";
        const numeric = Number(value);
        if (!isFinite(numeric) || numeric < 0)
            return "--%";
        const safe = Math.min(1, numeric);
        return Math.round(safe * 100) + "%";
    }

    wheelHandler: function (event) {
        if (!root.scrollable) {
            event.accepted = false;
            return;
        }

        if (!root.audioAvailable) {
            event.accepted = false;
            return;
        }

        event.accepted = true;
        const step = (event.angleDelta.y / 120) * 0.04;
        AudioService.setMasterVolume(AudioService.masterVolume + step);
    }

    clickHandler: function(mouse) {
        if (mouse.button === Qt.LeftButton) {
            const action = root.widgetConfig?.clickAction ?? "audio"
            if (action === "audio" || action === "dashboard-audio") GlobalStates.toggleAudio(root.actionAnchor)
            else GlobalStates.handleClickAction(action)
            mouse.accepted = true
        } else if (mouse.button === Qt.RightButton && root.audioAvailable) {
            AudioService.toggleMasterMute()
            mouse.accepted = true
        } else mouse.accepted = false
    }

    Row {
        spacing: Tokens.spacing.small

        MaterialIcon {
            id: volumeIcon
            iconName: {
                if (!root.audioAvailable)
                    return "volume_off";
                if (AudioService.masterMuted || AudioService.masterVolume <= 0.001)
                    return "no_sound";
                const v = AudioService.masterVolume;
                return (v < 0.34 ? "volume_mute" : v < 0.67 ? "volume_down" : "volume_up");
            }
            fontSize: Tokens.typography.titleLarge.size
            iconColor: Theme.onSurface
        }

        MaterialText {
            id: volumeLabel
            anchors.verticalCenter: parent.verticalCenter
            text: root.formatVolume(root.audioAvailable ? AudioService.masterVolume : null)
            textStyle: "bodyMedium"
            colorRole: "onSurface"
            visible: root.showPercentage && !root.compactPresentation
        }
    }
}
