pragma Singleton

import QtQuick

// The single authoritative description of the shell's IPC surface, rendered
// by the cheatsheet and referenced from README.md. Keep it in lockstep with
// the actual IpcHandler declarations — verify against a live shell with:
//   qs -p ~/.config/quickshell/shell ipc show
QtObject {
    readonly property var handlers: [
        {
            name: "globalstates",
            functions: [
                { name: "toggleDashboard", params: "", description: "Toggle dashboard visibility" },
                { name: "openDashboardTab", params: "tabIndex: int", description: "Open dashboard tab (0=Quick 1=Weather 2=Calendar 3=Audio 4=Network)" },
                { name: "toggleLauncher", params: "", description: "Toggle app launcher" },
                { name: "openLauncher", params: "", description: "Open app launcher" },
                { name: "closeLauncher", params: "", description: "Close app launcher" },
                { name: "closeAll", params: "", description: "Close all open panels" },
                { name: "toggleNotificationCenter", params: "", description: "Toggle notification center" },
                { name: "openNotificationCenter", params: "", description: "Open notification center" },
                { name: "closeNotificationCenter", params: "", description: "Close notification center" },
                { name: "screenshot", params: "", description: "Take area screenshot" },
                { name: "screenshotSwappy", params: "", description: "Take annotated screenshot (swappy)" },
                { name: "toggleGamingMode", params: "", description: "Toggle gaming mode" },
                { name: "enableGamingMode", params: "", description: "Enable gaming mode" },
                { name: "disableGamingMode", params: "", description: "Disable gaming mode" },
                { name: "toggleNightLight", params: "", description: "Toggle night light (hyprsunset)" },
                { name: "setNightLightTemperature", params: "temp: int", description: "Set night light temperature (K)" },
                { name: "nightLight", params: "", description: "Whether night light is on (persisted)" },
                { name: "toggleIdleInhibitor", params: "", description: "Toggle caffeine mode, returns the new state" },
                { name: "setIdleInhibitor", params: "enabled: bool", description: "Set caffeine mode (persisted)" },
                { name: "idleInhibitor", params: "", description: "Whether caffeine mode is on" },
                { name: "togglePowerMenu", params: "", description: "Toggle power menu" },
                { name: "openPowerMenu", params: "", description: "Open power menu" },
                { name: "closePowerMenu", params: "", description: "Close power menu" },
                { name: "lockScreen", params: "", description: "Lock the session" },
                { name: "toggleCheatsheet", params: "", description: "Toggle cheatsheet overlay" },
                { name: "openCheatsheet", params: "", description: "Open cheatsheet overlay" },
                { name: "closeCheatsheet", params: "", description: "Close cheatsheet overlay" }
            ]
        },
        {
            name: "audio",
            functions: [
                { name: "volumeUp", params: "", description: "Increase master volume" },
                { name: "volumeDown", params: "", description: "Decrease master volume" },
                { name: "toggleMute", params: "", description: "Toggle master mute" },
                { name: "setVolume", params: "value: real", description: "Set master volume (0.0-1.0)" },
                { name: "getMasterVolume", params: "", description: "Get current master volume" },
                { name: "isMuted", params: "", description: "Check if master is muted" }
            ]
        },
        {
            name: "mpris",
            functions: [
                { name: "play", params: "", description: "Start playback" },
                { name: "pause", params: "", description: "Pause playback" },
                { name: "stop", params: "", description: "Stop playback" },
                { name: "togglePlaying", params: "", description: "Toggle play/pause" },
                { name: "next", params: "", description: "Skip to next track" },
                { name: "previous", params: "", description: "Go to previous track" },
                { name: "seek", params: "offset: real", description: "Seek by offset in seconds" },
                { name: "setPosition", params: "position: real", description: "Set playback position" },
                { name: "setVolume", params: "volume: real", description: "Set player volume" },
                { name: "volumeUp", params: "", description: "Increase player volume" },
                { name: "volumeDown", params: "", description: "Decrease player volume" },
                { name: "toggleShuffle", params: "", description: "Toggle shuffle mode" },
                { name: "toggleLoop", params: "", description: "Cycle loop mode" },
                { name: "raise", params: "", description: "Raise player window" },
                { name: "quit", params: "", description: "Quit the player" },
                { name: "getPosition", params: "", description: "Get current position" },
                { name: "getLength", params: "", description: "Get track length" },
                { name: "getVolume", params: "", description: "Get player volume" },
                { name: "isPlaying", params: "", description: "Check if playing" },
                { name: "getCurrentTrack", params: "", description: "Get current track info" }
            ]
        },
        {
            name: "wallpaper",
            functions: [
                { name: "set", params: "monitor, path", description: "Set wallpaper for monitor" },
                { name: "setAll", params: "path", description: "Set wallpaper for all monitors" },
                { name: "setSource", params: "monitor, sourceId", description: "Bind monitor to a wallpaper source" },
                { name: "next", params: "monitor", description: "Next wallpaper" },
                { name: "previous", params: "monitor", description: "Previous wallpaper" },
                { name: "setAutoChange", params: "monitor, enabled, intervalMs", description: "Configure auto-change for monitor" },
                { name: "setFillMode", params: "monitor, fillMode", description: "Set fill mode for monitor" },
                { name: "setFillModeAll", params: "fillMode", description: "Set fill mode for all monitors" },
                { name: "refreshSource", params: "sourceId", description: "Re-scan / re-query a wallpaper source" },
                { name: "loadMore", params: "sourceId", description: "Fetch the next page of a remote source" },
                { name: "status", params: "", description: "Get wallpaper status" }
            ]
        },
        {
            name: "wallpaper-cache",
            functions: [
                { name: "status", params: "", description: "Cache statistics" },
                { name: "evict", params: "", description: "Trigger cache eviction" }
            ]
        },
        {
            name: "recorder",
            functions: [
                { name: "start", params: "", description: "Start a recording using the recorder config block" },
                { name: "toggle", params: "", description: "Start a recording, or stop the running one" },
                { name: "pick", params: "", description: "Start a recording, choosing screen/window/region in the portal picker" },
                { name: "status", params: "", description: "idle / recording MM:SS / paused MM:SS" },
                { name: "elapsed", params: "", description: "Seconds since the recording started" },
                { name: "pause", params: "", description: "Pause the running recording" },
                { name: "resume", params: "", description: "Resume the paused recording" },
                { name: "togglePause", params: "", description: "Pause or resume the running recording" },
                { name: "stop", params: "", description: "Stop and save the running recording" }
            ]
        },
        {
            name: "polkit",
            functions: [
                { name: "registered", params: "", description: "Whether the shell's polkit agent is registered" },
                { name: "active", params: "", description: "Whether an authentication request is open" },
                { name: "actionId", params: "", description: "Action id of the open request" },
                { name: "prompt", params: "", description: "Prompt text of the open request" },
                { name: "error", params: "", description: "Last failure message, empty when none" },
                { name: "state", params: "", description: "One-line summary of the agent state" },
                { name: "cancel", params: "", description: "Cancel the open request" }
            ]
        },
        {
            name: "config",
            functions: [
                { name: "validate", params: "", description: "Check config.json against the schema" },
                { name: "path", params: "", description: "Path of the active config.json" },
                { name: "schemaPath", params: "", description: "Path of config.schema.json" },
                { name: "statePath", params: "", description: "Path of state.json" }
            ]
        },
        {
            name: "notifications",
            functions: [
                { name: "count", params: "", description: "Total notifications in history" },
                { name: "unread", params: "", description: "Unread notification count" },
                { name: "activeCount", params: "", description: "Currently shown popup count" },
                { name: "markAllRead", params: "", description: "Mark every notification read" },
                { name: "dismissAll", params: "", description: "Dismiss the visible popups" },
                { name: "clear", params: "", description: "Clear notification history" },
                { name: "isDnd", params: "", description: "Whether do-not-disturb is on" },
                { name: "dndActive", params: "", description: "Whether do-not-disturb is currently suppressing" },
                { name: "setDnd", params: "enabled: bool", description: "Set do-not-disturb" },
                { name: "toggleDnd", params: "", description: "Toggle do-not-disturb" }
            ]
        }
    ]
}
