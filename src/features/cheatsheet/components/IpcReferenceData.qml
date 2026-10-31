pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Signatures come from the running shell. Descriptions enrich that surface;
// they never create commands or override parameters reported by the engine.
QtObject {
    id: root
    property var handlers: []
    property bool busy: false
    property string errorMessage: ""
    property string _output: ""
    property bool _stdoutDone: false
    property bool _exited: false
    property int _exitCode: 0
    property bool _timedOut: false
    property int _generation: 0
    readonly property var descriptions: ({
        "globalstates.openAudio": "Open output, microphone and application volume controls",
        "globalstates.toggleAudio": "Toggle the audio panel",
        "globalstates.closeAudio": "Close the audio panel",
        "globalstates.toggleDashboard": "Toggle dashboard visibility",
        "globalstates.openDashboardTab": "Open dashboard (0=Quick, 1=Weather, 2=Calendar; legacy 3 opens Audio, 4 opens Connections / Wi-Fi)",
        "globalstates.toggleLauncher": "Toggle app launcher",
        "globalstates.openLauncher": "Open app launcher",
        "globalstates.closeLauncher": "Close app launcher",
        "globalstates.closeAll": "Close all open panels",
        "globalstates.toggleNotificationCenter": "Toggle notification center",
        "globalstates.openNotificationCenter": "Open notification center",
        "globalstates.closeNotificationCenter": "Close notification center",
        "globalstates.screenshot": "Take area screenshot",
        "globalstates.screenshotSwappy": "Take annotated screenshot (swappy)",
        "globalstates.toggleGamingMode": "Toggle gaming mode",
        "globalstates.enableGamingMode": "Enable gaming mode",
        "globalstates.disableGamingMode": "Disable gaming mode",
        "globalstates.toggleNightLight": "Toggle night light (hyprsunset)",
        "globalstates.setNightLightTemperature": "Set night light temperature (K)",
        "globalstates.nightLight": "Whether night light is on (persisted)",
        "globalstates.toggleIdleInhibitor": "Toggle caffeine mode, returns the new state",
        "globalstates.setIdleInhibitor": "Set caffeine mode (persisted)",
        "globalstates.idleInhibitor": "Whether caffeine mode is on",
        "globalstates.togglePowerMenu": "Toggle power menu",
        "globalstates.openPowerMenu": "Open power menu",
        "globalstates.closePowerMenu": "Close power menu",
        "globalstates.lockScreen": "Lock the session",
        "globalstates.toggleCheatsheet": "Toggle cheatsheet overlay",
        "globalstates.openCheatsheet": "Open cheatsheet overlay",
        "globalstates.closeCheatsheet": "Close cheatsheet overlay",
        "audio.volumeUp": "Increase master volume",
        "audio.volumeDown": "Decrease master volume",
        "audio.toggleMute": "Toggle master mute",
        "audio.setVolume": "Set master volume (0.0-1.0)",
        "audio.getMasterVolume": "Get current master volume",
        "audio.isMuted": "Check if master is muted",
        "mpris.play": "Start playback",
        "mpris.pause": "Pause playback",
        "mpris.stop": "Stop playback",
        "mpris.togglePlaying": "Toggle play/pause",
        "mpris.next": "Skip to next track",
        "mpris.previous": "Go to previous track",
        "mpris.seek": "Seek by offset in seconds",
        "mpris.listPlayers": "Every available player, the active one marked",
        "mpris.switchPlayer": "Make the named player active (prefix match)",
        "mpris.cyclePlayer": "Switch to the next player",
        "mpris.setPosition": "Set playback position",
        "mpris.setVolume": "Set player volume",
        "mpris.volumeUp": "Increase player volume",
        "mpris.volumeDown": "Decrease player volume",
        "mpris.toggleShuffle": "Toggle shuffle mode",
        "mpris.toggleLoop": "Cycle loop mode",
        "mpris.raise": "Raise player window",
        "mpris.quit": "Quit the player",
        "mpris.getPosition": "Get current position",
        "mpris.getLength": "Get track length",
        "mpris.getVolume": "Get player volume",
        "mpris.isPlaying": "Check if playing",
        "mpris.getCurrentTrack": "Get current track info",
        "wallpaper.set": "Set wallpaper for monitor",
        "wallpaper.setAll": "Set wallpaper for all monitors",
        "wallpaper.setSource": "Bind monitor to a wallpaper source",
        "wallpaper.next": "Next wallpaper",
        "wallpaper.previous": "Previous wallpaper",
        "wallpaper.setAutoChange": "Configure auto-change for monitor",
        "wallpaper.setFillMode": "Set fill mode for monitor",
        "wallpaper.setFillModeAll": "Set fill mode for all monitors",
        "wallpaper.refreshSource": "Re-scan / re-query a wallpaper source",
        "wallpaper.loadMore": "Fetch the next page of a remote source",
        "wallpaper.status": "Get wallpaper status",
        "wallpaper-cache.status": "Cache statistics",
        "wallpaper-cache.evict": "Trigger cache eviction",
        "timer.start": "Start a countdown for 1–1440 whole minutes",
        "timer.pomodoro": "Start automatic work and break intervals",
        "timer.pause": "Pause the current timer",
        "timer.resume": "Resume the paused timer",
        "timer.stop": "Stop the current timer or Pomodoro cycle",
        "timer.status": "JSON timer status and current phase",
        "weather.status": "JSON weather update state and diagnostics",
        "weather.retry": "Retry the last failed weather update",
        "vpn.status": "JSON VPN operation state and diagnostics",
        "vpn.retry": "Retry the failed VPN operation for its original profile",
        "recorder.start": "Start a recording using the recorder config block",
        "recorder.toggle": "Start a recording, or stop the running one",
        "recorder.pick": "Start a recording, choosing screen/window/region in the portal picker",
        "caffeine.status": "Requested and confirmed idle inhibition, pending state and errors",
        "caffeine.retry": "Retry an unconfirmed Caffeine request",
        "nightlight.status": "Requested and running night light state with diagnostics",
        "nightlight.retry": "Retry night light after a failure",
        "recorder.diagnostics": "Recording state, failed operation and retry availability",
        "recorder.retry": "Retry the failed recording operation when safe",
        "power.status": "Battery availability, percentage, remaining time and warning state",
        "recorder.status": "idle / recording MM:SS / paused MM:SS",
        "recorder.elapsed": "Seconds since the recording started",
        "recorder.pause": "Pause the running recording",
        "recorder.resume": "Resume the paused recording",
        "recorder.togglePause": "Pause or resume the running recording",
        "recorder.stop": "Stop and save the running recording",
        "polkit.registered": "Whether the shell's polkit agent is registered",
        "polkit.active": "Whether an authentication request is open",
        "polkit.actionId": "Action id of the open request",
        "polkit.prompt": "Prompt text of the open request",
        "polkit.error": "Last failure message, empty when none",
        "polkit.state": "One-line summary of the agent state",
        "polkit.cancel": "Cancel the open request",
        "config.validate": "Validate the current configuration file",
        "config.path": "Path of the configuration file",
        "config.schemaPath": "Path of config.schema.json",
        "config.statePath": "Path of state.json",
        "notifications.count": "Total notifications in history",
        "notifications.unread": "Unread notification count",
        "notifications.activeCount": "Currently shown popup count",
        "notifications.markAllRead": "Mark every notification read",
        "notifications.dismissAll": "Dismiss the visible popups",
        "notifications.clear": "Clear notification history",
        "notifications.isDnd": "Whether do-not-disturb is on",
        "notifications.dndActive": "Whether do-not-disturb is currently suppressing",
        "notifications.setDnd": "Set do-not-disturb",
        "notifications.toggleDnd": "Toggle do-not-disturb",
        "globalstates.openConnections": "Open connections with section wifi, bluetooth, vpn, or an empty string",
        "globalstates.toggleConnections": "Toggle the connections panel",
        "globalstates.closeConnections": "Close connections",
        "globalstates.locked": "Whether the shell currently holds the session lock"
    })

    function parseSurface(output) {
        if (output.length > 262144) return []
        const result = []
        let handler = null
        for (const line of output.split("\n")) {
            const target = /^target ([^\s]+)\s*$/.exec(line)
            if (target) {
                handler = {name: target[1], functions: []}
                result.push(handler)
                continue
            }
            const fn = /^\s+function (\w+)\(([^)]*)\)(?::\s*(.+))?\s*$/.exec(line)
            if (!fn || !handler) continue
            const key = handler.name + "." + fn[1]
            const words = fn[1].replace(/([a-z])([A-Z])/g, "$1 $2")
            handler.functions.push({name: fn[1], params: fn[2], returns: fn[3] || "void",
                description: root.descriptions[key] || words[0].toUpperCase() + words.slice(1)})
        }
        result.sort((a, b) => a.name.localeCompare(b.name))
        for (const entry of result) entry.functions.sort((a, b) => a.name.localeCompare(b.name))
        return result
    }
    function refresh() {
        if (root.busy || query.running) return
        root._generation++
        root._output = ""
        root._stdoutDone = false
        root._exited = false
        root._timedOut = false
        root.errorMessage = ""
        root.busy = true
        query.running = true
        deadline.restart()
    }
    function _finish() {
        if (!root._stdoutDone || !root._exited) return
        deadline.stop()
        const generation = root._generation
        const output = root._output
        const succeeded = !root._timedOut && root._exitCode === 0
        // Publish outside the Process callback, just like other service models.
        Qt.callLater(() => {
            if (generation !== root._generation) return
            root.busy = false
            if (!succeeded) {
                root.errorMessage = "Could not read IPC commands from the running shell. Try again."
                return
            }
            const parsed = root.parseSurface(output)
            if (parsed.length === 0) {
                root.errorMessage = "The shell reported no IPC commands. Try again."
                return
            }
            root.handlers = parsed
        })
    }
    property Process _query: Process {
        id: query
        command: ["qs", "-p", Quickshell.shellDir, "ipc", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                root._output = text
                root._stdoutDone = true
                root._finish()
            }
        }
        onExited: exitCode => {
            root._exitCode = exitCode
            root._exited = true
            root._finish()
        }
    }
    property Timer _deadline: Timer {
        id: deadline
        interval: 3000
        onTriggered: {
            root._timedOut = true
            query.running = false
            // Keep refresh disabled until stdout/exit from this process settle.
            root.errorMessage = "Reading IPC commands timed out. Try again."
        }
    }
}
