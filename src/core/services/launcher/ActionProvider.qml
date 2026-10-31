import QtQuick
import qs.src.core.config
import qs.src.core.services

// Explicit shell actions; the prefix never evaluates a command line.
BaseProvider {
    id: root
    name: "Shell actions"
    priority: 80
    prefixes: [":"]
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
    function invalidateVisible() {
        if (GlobalStates.launcherOpen && LauncherService.mode === "actions") resultsInvalidated()
    }
    function timedCommand(mode, minutes) {
        const dnd = mode === "dnd"
        return {id:mode+"-"+minutes+"m",module:dnd ? "notifications" : "",
            text:(dnd ? "Do not disturb" : "Caffeine")+" · "+minutes+" min",
            description:dnd ? "Silence normal popups temporarily" : "Keep the session awake temporarily",
            icon:dnd ? "notifications-disabled" : "preferences-desktop-screensaver",
            run:()=>{if(dnd) NotificationDND.setForMinutes(minutes);else IdleInhibitorService.setForMinutes(minutes)}}
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
        return commands
    }
    function execute(id, expectedText) {
        let command = catalogue().find(item => item.id === id)
        const timed = id.match(/^(dnd|caffeine)-(\d+)m$/)
        if (!command && timed && Number(timed[2]) >= 1 && Number(timed[2]) <= 1440)
            command = timedCommand(timed[1],Number(timed[2]))
        // The query can outlive its state snapshot. Never turn a stale Start
        // into Stop, or invoke an action whose dependency/module disappeared.
        if (!command || command.text !== expectedText || command.unavailable
            || (command.module && !AppConfig.moduleEnabled(command.module))) return
        command.run()
    }
    function search(query) {
        let terms = removePrefix(query).toLowerCase().split(/\s+/).filter(term => term !== "")
        let commands = catalogue()
        const explicit = removePrefix(query).toLowerCase().match(/^(dnd|caffeine)\s+(\d+)$/)
        if (explicit) {
            const minutes = Number(explicit[2])
            commands = Number.isInteger(minutes) && minutes >= 1 && minutes <= 1440 ? [timedCommand(explicit[1],minutes)] : []
            terms = []
        }
        return commands.filter(command => (!command.module || AppConfig.moduleEnabled(command.module))
            && terms.every(term => (command.id+" "+command.text+" "+command.description+" "+(command.aliases || "")).toLowerCase().includes(term)))
            .map(command => ({id:"action:"+command.id,type:"action",text:command.text,
                description:command.unavailable || command.description,icon:command.icon,score:0,
                action:command.unavailable ? null : () => root.execute(command.id,command.text)}))
    }
}
