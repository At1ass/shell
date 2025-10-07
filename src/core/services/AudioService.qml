import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pipewire

pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root

    // ===== PIPEWIRE NODES =====
    readonly property var pipewireNodes: (Pipewire.nodes && Pipewire.nodes.values) ? Pipewire.nodes.values : []
    readonly property var sinkNodes: pipewireNodes.filter(node => node && node.audio && node.isSink && !node.isStream)
    readonly property var sourceNodes: pipewireNodes.filter(node => node && node.audio && !node.isSink && !node.isStream)
    readonly property var streamNodes: pipewireNodes.filter(node => node && node.audio && node.isStream)

    // ===== DEFAULT DEVICES =====
    readonly property var defaultSink: Pipewire.defaultAudioSink
    readonly property var defaultSource: Pipewire.defaultAudioSource

    // ===== MASTER VOLUME (0.0 - 1.0) =====
    readonly property real masterVolume: defaultSink?.audio?.volume ?? 0
    readonly property bool masterMuted: defaultSink?.audio?.muted ?? false

    // ===== SIGNALS =====
    signal volumeChanged(real volume, bool muted)

    // Отслеживаем ЛЮБЫЕ изменения громкости (от любых источников)
    onMasterVolumeChanged: {
        volumeChanged(masterVolume, masterMuted)
    }

    onMasterMutedChanged: {
        volumeChanged(masterVolume, masterMuted)
    }

    // ===== MASTER VOLUME CONTROL =====
    function setMasterVolume(value) {
        if (defaultSink && defaultSink.audio) {
            const newVolume = Math.max(0, Math.min(1, value))
            defaultSink.audio.volume = newVolume
            // volumeChanged будет эмитен автоматически через onMasterVolumeChanged
        }
    }

    function toggleMasterMute() {
        if (defaultSink && defaultSink.audio) {
            defaultSink.audio.muted = !defaultSink.audio.muted
            // volumeChanged будет эмитен автоматически через onMasterMutedChanged
        }
    }

    function setMasterMute(muted) {
        if (defaultSink && defaultSink.audio) {
            defaultSink.audio.muted = muted
            // volumeChanged будет эмитен автоматически через onMasterMutedChanged
        }
    }

    // ===== DEVICE SELECTION =====
    function setDefaultSink(device) {
        if (device) {
            Pipewire.preferredDefaultAudioSink = device
        }
    }

    function setDefaultSource(device) {
        if (device) {
            Pipewire.preferredDefaultAudioSource = device
        }
    }

    // ===== STREAM CONTROL =====
    function setStreamVolume(stream, value) {
        if (stream && stream.audio) {
            stream.audio.volume = Math.max(0, Math.min(1, value))
        }
    }

    function toggleStreamMute(stream) {
        if (stream && stream.audio) {
            stream.audio.muted = !stream.audio.muted
        }
    }

    function setStreamMute(stream, muted) {
        if (stream && stream.audio) {
            stream.audio.muted = muted
        }
    }

    // ===== UTILITY FUNCTIONS =====
    function formatVolume(value) {
        const numeric = Number(value)
        if (!isFinite(numeric) || numeric < 0) return "--"
        return Math.round(Math.min(1, numeric) * 100)
    }

    function getAppIcon(stream) {
        if (!stream || !stream.properties) return ""

        // Try different property keys for application name
        const appName = stream.properties["application.name"] ||
                       stream.properties["application.process.binary"] ||
                       stream.properties["pipewire.access.portal.app_id"]

        if (!appName) return ""

        // Try to find desktop entry
        const entry = DesktopEntries.heuristicLookup(appName)
        if (entry && entry.icon) {
            return Quickshell.iconPath(entry.icon)
        }

        return ""
    }

    // ===== IPC COMMANDS =====
    IpcHandler {
        target: "audio"

        function volumeUp(): void {
            root.setMasterVolume(root.masterVolume + 0.05)
        }

        function volumeDown(): void {
            root.setMasterVolume(root.masterVolume - 0.05)
        }

        function toggleMute(): void {
            root.toggleMasterMute()
        }

        function setVolume(value: real): void {
            root.setMasterVolume(value)
        }

        function getMasterVolume(): real {
            return root.masterVolume
        }

        function isMuted(): bool {
            return root.masterMuted
        }
    }

    // ===== GLOBAL SHORTCUTS =====
    GlobalShortcut {
        name: "audioVolumeUp"
        description: "Increase master volume"
        onPressed: root.setMasterVolume(root.masterVolume + 0.05)
    }

    GlobalShortcut {
        name: "audioVolumeDown"
        description: "Decrease master volume"
        onPressed: root.setMasterVolume(root.masterVolume - 0.05)
    }

    GlobalShortcut {
        name: "audioToggleMute"
        description: "Toggle master mute"
        onPressed: root.toggleMasterMute()
    }
}
