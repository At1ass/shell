import QtQuick
import Quickshell.Services.Pipewire
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

    readonly property var sink: Pipewire.defaultAudioSink

    function formatVolume(value) {
        const numeric = Number(value);
        if (!isFinite(numeric) || numeric < 0)
            return "--%";
        const safe = Math.min(1, numeric);
        return Math.round(safe * 100) + "%";
    }

    nonVisualChildren: [
        PwObjectTracker {
            objects: root.sink ? [root.sink] : []
        }
    ]

    wheelHandler: function (event) {
        if (!root.scrollable) {
            event.accepted = false;
            return;
        }

        if (!root.sink || !root.sink.audio) {
            event.accepted = false;
            return;
        }

        event.accepted = true;
        const step = (event.angleDelta.y / 120) * 0.04;
        const current = (root.sink.audio.volume !== undefined) ? root.sink.audio.volume : 0;
        root.sink.audio.volume = Math.max(0, Math.min(1, current + step));
    }

    clickHandler: function(mouse) {
        if (mouse.button === Qt.LeftButton) {
            const action = root.widgetConfig?.clickAction ?? "audio"
            if (action === "audio" || action === "dashboard-audio") GlobalStates.toggleAudio(root.actionAnchor)
            else GlobalStates.handleClickAction(action)
            mouse.accepted = true
        } else if (mouse.button === Qt.RightButton && root.sink?.audio) {
            root.sink.audio.muted = !root.sink.audio.muted
            mouse.accepted = true
        } else mouse.accepted = false
    }

    Row {
        spacing: Tokens.spacing.small

        MaterialIcon {
            id: volumeIcon
            iconName: {
                if (!root.sink || !root.sink.audio)
                    return "volume_up";
                if (root.sink.audio.muted || root.sink.audio.volume <= 0.001)
                    return "no_sound";
                const v = root.sink.audio.volume;
                return (v < 0.34 ? "volume_mute" : v < 0.67 ? "volume_down" : "volume_up");
            }
            fontSize: Tokens.typography.titleLarge.size
            iconColor: Theme.onSurface
        }

        MaterialText {
            id: volumeLabel
            anchors.verticalCenter: parent.verticalCenter
            text: root.formatVolume(root.sink && root.sink.audio ? root.sink.audio.volume : null)
            textStyle: "titleMedium"
            colorRole: "onSurface"
            visible: root.showPercentage && !root.compactPresentation
        }
    }
}
