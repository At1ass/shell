import QtQuick
import QtQuick.Layouts
import qs.src.ui.containers
import qs.src.ui.inputs
import qs.src.ui.feedback
import QtQuick.Controls
import Quickshell.Services.Pipewire
import qs.src.ui.base
import qs.src.ui.feedback
import qs.src.core.config
import qs.src.core.services

BarElement {
    id: root
    minWidth: 96
    clickable: true
    hoverable: true

    property var tooltipManager: null
    property bool mixerOpen: false

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var pipewireNodes: (Pipewire.nodes && Pipewire.nodes.values) ? Pipewire.nodes.values : []
    readonly property var sinkNodes: pipewireNodes ? pipewireNodes.filter(function (node) {
        return node && node.audio && node.isSink && !node.isStream;
    }) : []
    readonly property var sourceNodes: pipewireNodes ? pipewireNodes.filter(function (node) {
        return node && node.audio && !node.isSink && !node.isStream;
    }) : []
    readonly property var streamNodes: pipewireNodes ? pipewireNodes.filter(function (node) {
        return node && node.audio && node.isStream;
    }) : []

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
        if (!root.sink || !root.sink.audio) {
            event.accepted = false;
            return;
        }

        event.accepted = true;
        const step = (event.angleDelta.y / 120) * 0.04;
        const current = (root.sink.audio.volume !== undefined) ? root.sink.audio.volume : 0;
        root.sink.audio.volume = Math.max(0, Math.min(1, current + step));
    }

    clickHandler: function (mouse) {
        if (mouse.button === Qt.LeftButton) {
            if (!root.sink || !root.sink.audio) {
                mouse.accepted = false;
                return;
            }

            mouse.accepted = true;
            root.sink.audio.muted = !root.sink.audio.muted;
            root.mixerOpen = false;
            return;
        }

        if (mouse.button === Qt.RightButton) {
            GlobalStates.dashboardOpenIndex = 3
            GlobalStates.dashboardOpen = !GlobalStates.dashboardOpen
            // root.mixerOpen = !root.mixerOpen;
            // mouse.accepted = true;
            return;
        }

        mouse.accepted = false;
    }

    Row {
        spacing: Config.spacing.small

        MaterialIcon {
            iconName: {
                if (!root.sink || !root.sink.audio)
                    return "volume_up";
                if (root.sink.audio.muted || root.sink.audio.volume <= 0.001)
                    return "no_sound";
                const v = root.sink.audio.volume;
                return (v < 0.34 ? "volume_mute" : v < 0.67 ? "volume_down" : "volume_up");
            }
            fontSize: Config.typography.titleLarge.size
            enabled: (typeof MprisController !== 'undefined') && MprisController.canGoPrevious
            iconColor: Config.colors.onSurface
            color: "transparent"
        }


        MaterialText {
            anchors.verticalCenter: parent.verticalCenter
            text: formatVolume(root.sink && root.sink.audio ? root.sink.audio.volume : null)
            textStyle: "titleMedium"
            colorRole: "onSurface"
        }
    }
}
