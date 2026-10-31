import QtQuick
import Quickshell
import qs.src.core.config
import qs.src.core.services

// Explicit shell actions; the prefix never evaluates a command line.
BaseProvider {
    id: root
    name: "Shell actions"
    priority: 80
    prefixes: [":"]
    readonly property var applications: DesktopEntries.applications.values
    readonly property var entriesById: {
        const entries = Object.create(null)
        for (const entry of applications) entries[entry.id] = entry
        return entries
    }
    onEntriesByIdChanged: invalidateVisible()
    readonly property Connections stateWatch: Connections {
        target: AppConfig
        function onStateDataChanged() { root.invalidateVisible() }
        function onDataChanged() { root.invalidateVisible() }
    }
    readonly property Connections recorderWatch: Connections {
        target: RecorderService
        function onActiveChanged() { root.invalidateVisible() }
        function onAvailableChanged() { root.invalidateVisible() }
        function onStartingChanged() { root.invalidateVisible() }
        function onPausedChanged() { root.invalidateVisible() }
    }
    readonly property Connections nightLightWatch: Connections {
        target: NightLightService
        function onAvailableChanged() { root.invalidateVisible() }
        function onEnabledChanged() { root.invalidateVisible() }
    }
    readonly property Connections gamingWatch: Connections {
        target: GamingModeService
        function onGamingModeActiveChanged() { root.invalidateVisible() }
    }
    readonly property Connections dndWatch: Connections {
        target: NotificationDND
        function onEnabledChanged() { root.invalidateVisible() }
        function onStatusTextChanged() { root.invalidateVisible() }
    }
    readonly property Connections caffeineWatch: Connections {
        target: IdleInhibitorService
        function onInhibitChanged() { root.invalidateVisible() }
        function onStatusTextChanged() { root.invalidateVisible() }
    }
    readonly property Connections timerWatch: Connections {
        target: TimerService
        function onStatusChanged() { root.invalidateVisible() }
    }
    function invalidateVisible() {
        if (GlobalStates.launcherOpen && LauncherService.mode === "actions") resultsInvalidated()
    }
    function timedCommand(mode, minutes) {
        if (mode === "timer") return {id:"timer-"+minutes+"m",text:"Timer · "+minutes+" min",
            description:"Start a countdown",aliases:"countdown",icon:"appointment-soon",
            unavailable:!AppConfig.timersEnabled ? "Enable timers in config.json" : TimerService.active ? "Stop the current timer before starting another" : "",
            run:()=>TimerService.start(minutes)}
        const dnd = mode === "dnd"
        return {id:mode+"-"+minutes+"m",module:dnd ? "notifications" : "",
            text:(dnd ? "Do not disturb" : "Caffeine")+" · "+minutes+" min",
            description:dnd ? "Silence normal popups temporarily" : "Keep the session awake temporarily",
            icon:dnd ? "notifications-disabled" : "preferences-desktop-screensaver",
            run:()=>{if(dnd) NotificationDND.setForMinutes(minutes);else IdleInhibitorService.setForMinutes(minutes)}}
    }
    function customCommands() {
        const commands = []
        const actions = AppConfig.launcherActions
        for (const key of Object.keys(actions)) {
            const action = actions[key]
            if (action.enabled === false) continue
            const entry = action.desktopEntry ? entriesById[action.desktopEntry] : null
            const argv = action.command
            const validCommand = Array.isArray(argv) && argv.length > 0
                && typeof argv[0] === "string" && argv[0].trim() !== ""
                && argv.every(arg => typeof arg === "string" && !arg.includes("\u0000"))
            const unavailable = action.desktopEntry
                ? (entry ? "" : "Desktop entry not found: " + action.desktopEntry)
                : validCommand ? "" : "Command needs an executable and literal arguments"
            commands.push({id:"custom:"+key,text:action.name,
                description:action.description ? "Custom action · " + action.description : "Custom action",
                aliases:[key].concat(action.keywords || []).join(" "),
                icon:action.icon || entry?.icon || "system-run",unavailable:unavailable,
                revision:JSON.stringify([action.command,action.desktopEntry]),
                run:()=>{if(entry) AppLaunchService.launchEntry(entry);else AppLaunchService.launchCommand(argv)}})
        }
        return commands
    }
    function catalogue() {
        let commands = [
            {id:"audio",module:"audio",text:"Audio",description:"Output, input and application volumes",icon:"audio-volume-high",run:()=>GlobalStates.openAudio(null)},
            {id:"connections",module:"connections",text:"Connections",description:"Wi-Fi, Bluetooth and VPN",icon:"network-wireless",run:()=>GlobalStates.openConnections("",null)},
            {id:"quick",module:"dashboard",text:"Quick overview",description:"Modes, brightness and system statistics",icon:"view-grid",run:()=>GlobalStates.openDashboardTab(0)},
            {id:"weather",module:"dashboard",text:"Weather",description:"Current conditions and forecast",icon:"weather-clear",run:()=>GlobalStates.openDashboardTab(1)},
            {id:"calendar",module:"dashboard",text:"Calendar",description:"Dates and events",icon:"view-calendar",run:()=>GlobalStates.openDashboardTab(2)},
            {id:"notifications",module:"notifications",text:"Notifications",description:"Open notification history",icon:"preferences-system-notifications",run:()=>GlobalStates.openPanel("notificationCenter")},
            {id:"dnd",module:"notifications",text:NotificationDND.enabled ? "Turn off do not disturb" : "Turn on do not disturb",description:NotificationDND.enabled ? "Notifications silenced"+(NotificationDND.temporary ? " · "+NotificationDND.statusText : "") : "Allowing notifications",aliases:"quiet silence focus",icon:"notifications-disabled",run:()=>NotificationDND.toggle()},
            {id:"shortcuts",module:"cheatsheet",text:"Keyboard shortcuts",description:"Show available shortcuts and IPC actions",icon:"input-keyboard",run:()=>GlobalStates.openPanel("cheatsheet")},
            {id:"power",module:"powerMenu",text:"Power menu",description:"Review session and power actions",icon:"system-shutdown",run:()=>GlobalStates.openPanel("powermenu")},
            {id:"lock",module:"lockscreen",text:"Lock screen",description:"Lock the current session",icon:"system-lock-screen",run:()=>GlobalStates.lockSession()}
        ]
        commands.push(
            {id:"overview",module:"overview",text:"Workspace overview",description:"Find, switch and move windows",aliases:"windows workspaces expose",icon:"view-grid",run:()=>OverviewService.showWorkspace(0,null)},
            {id:"screenshot",module:"screenshot",text:"Copy screenshot",description:"Select a region and copy it to the clipboard",aliases:"capture image screen region",icon:"camera-photo",run:()=>ScreenshotService.takeScreenshot()},
            {id:"screenshot-edit",module:"screenshot",text:"Edit screenshot",description:"Select a region and open it in Swappy",aliases:"capture image screen region annotate",icon:"camera-photo",run:()=>ScreenshotService.takeScreenshotSwappy()},
            {id:"night-light",module:"",text:NightLightService.enabled ? "Turn off night light" : "Turn on night light",
                description:NightLightService.enabled ? "Warm display colours enabled" : "Warm display colours disabled",aliases:"nightlight blue light temperature sunset",icon:"weather-clear-night",
                unavailable:NightLightService.available ? "" : "Install hyprsunset to use night light",run:()=>NightLightService.toggle()},
            {id:"gaming",module:"",text:GamingModeService.gamingModeActive ? "Turn off gaming mode" : "Turn on gaming mode",
                description:GamingModeService.gamingModeActive ? "Gaming mode enabled" : "Gaming mode disabled",aliases:"game performance",icon:"applications-games",run:()=>GamingModeService.toggleGamingMode()},
            {id:"record",module:"recorder",text:RecorderService.active ? "Stop screen recording" : "Start screen recording",
                description:RecorderService.active ? (RecorderService.paused ? "Recording paused" : "Recording in progress") : "Use the configured capture target",
                aliases:"recorder video capture screen",icon:"media-record",unavailable:RecorderService.starting ? "Waiting for the recorder to start" : !RecorderService.active && !RecorderService.available ? "Install gpu-screen-recorder to record the screen" : "",run:()=>RecorderService.toggle()})
        if (RecorderService.active) commands.push({id:"record-pause",module:"recorder",text:RecorderService.paused ? "Resume screen recording" : "Pause screen recording",
            description:"Keep the current recording session",aliases:"recorder video capture",icon:"media-playback-pause",run:()=>RecorderService.togglePause()})
        commands.push({id:"caffeine",module:"",text:IdleInhibitorService.inhibit ? "Turn off caffeine" : "Turn on caffeine",aliases:"awake sleep idle inhibit",
            description:IdleInhibitorService.inhibit ? "Allow idle sleep"+(IdleInhibitorService.temporary ? " · "+IdleInhibitorService.statusText : "") : "Keep the session awake",
            icon:"preferences-desktop-screensaver",run:()=>IdleInhibitorService.toggleInhibit()})
        for (const minutes of Array.from(AppConfig.temporaryModeDurations)) {
            commands.push(timedCommand("dnd",minutes),timedCommand("caffeine",minutes))
        }
        if (AppConfig.timersEnabled) {
            commands.push({id:"timer",text:"Timer controls",description:"Countdown and automatic Pomodoro cycle",
                aliases:"focus work break",icon:"appointment-soon",run:()=>GlobalStates.openDashboardTab(0)})
            for (const minutes of Array.from(AppConfig.timerPresetsMinutes)) commands.push(timedCommand("timer",minutes))
            if (!TimerService.active) commands.push({id:"pomodoro",text:"Start Pomodoro",description:"Automatic work and break intervals",
                aliases:"timer focus work break",icon:"appointment-soon",run:()=>TimerService.pomodoro()})
            else {
                commands.push({id:"timer-pause",text:TimerService.paused ? "Resume timer" : "Pause timer",
                    description:TimerService.phaseLabel,icon:"media-playback-pause",run:()=>{if(TimerService.paused) TimerService.resume();else TimerService.pause()}})
                commands.push({id:"timer-stop",text:"Stop timer",description:"End the current countdown or Pomodoro cycle",
                    icon:"media-playback-stop",run:()=>TimerService.stop()})
            }
        }
        return commands.concat(customCommands())
    }
    function execute(id, expectedText, expectedRevision) {
        let command = catalogue().find(item => item.id === id)
        const timed = id.match(/^(dnd|caffeine|timer)-(\d+)m$/)
        if (!command && timed && Number(timed[2]) >= 1 && Number(timed[2]) <= 1440)
            command = timedCommand(timed[1],Number(timed[2]))
        // The query can outlive its state snapshot. Never turn a stale Start
        // into Stop, or invoke an action whose dependency/module disappeared.
        if (!command || command.text !== expectedText || command.revision !== expectedRevision || command.unavailable
            || (command.module && !AppConfig.moduleEnabled(command.module))) return
        command.run()
    }
    function search(query) {
        let terms = removePrefix(query).toLowerCase().split(/\s+/).filter(term => term !== "")
        let commands = catalogue()
        const explicit = removePrefix(query).toLowerCase().match(/^(dnd|caffeine|timer)\s+(\d+)$/)
        if (explicit) {
            const minutes = Number(explicit[2])
            commands = Number.isInteger(minutes) && minutes >= 1 && minutes <= 1440
                && (explicit[1] !== "timer" || AppConfig.timersEnabled) ? [timedCommand(explicit[1],minutes)] : []
            terms = []
        }
        return commands.filter(command => (!command.module || AppConfig.moduleEnabled(command.module))
            && terms.every(term => (command.id+" "+command.text+" "+command.description+" "+(command.aliases || "")).toLowerCase().includes(term)))
            .map(command => ({id:"action:"+command.id,type:"action",text:command.text,
                description:command.unavailable || command.description,icon:command.icon,
                score:terms.length && terms.every(term => (command.id+" "+command.text).toLowerCase().includes(term)) ? 2 : 0,
                action:command.unavailable ? null : () => root.execute(command.id,command.text,command.revision)}))
            .sort((a,b) => b.score-a.score)
    }
}
