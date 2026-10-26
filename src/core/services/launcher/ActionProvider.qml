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
    function search(query) {
        let terms = removePrefix(query).toLowerCase().split(/\s+/).filter(term => term !== "")
        let commands = [
            {id:"audio",module:"audio",text:"Audio",description:"Output, input and application volumes",icon:"audio-volume-high",run:()=>GlobalStates.openAudio(null)},
            {id:"connections",module:"connections",text:"Connections",description:"Wi-Fi, Bluetooth and VPN",icon:"network-wireless",run:()=>GlobalStates.openConnections("",null)},
            {id:"quick",module:"dashboard",text:"Quick overview",description:"Modes, brightness and system statistics",icon:"view-grid",run:()=>GlobalStates.openDashboardTab(0)},
            {id:"weather",module:"dashboard",text:"Weather",description:"Current conditions and forecast",icon:"weather-clear",run:()=>GlobalStates.openDashboardTab(1)},
            {id:"calendar",module:"dashboard",text:"Calendar",description:"Dates and events",icon:"view-calendar",run:()=>GlobalStates.openDashboardTab(2)},
            {id:"notifications",module:"notifications",text:"Notifications",description:"Open notification history",icon:"preferences-system-notifications",run:()=>GlobalStates.openPanel("notificationCenter")},
            {id:"dnd",module:"notifications",text:"Do not disturb",description:NotificationDND.enabled ? "Turn off do not disturb"+(NotificationDND.temporary ? " · "+NotificationDND.statusText : "") : "Turn on do not disturb",icon:"notifications-disabled",run:()=>NotificationDND.toggle()},
            {id:"shortcuts",module:"cheatsheet",text:"Keyboard shortcuts",description:"Show available shortcuts and IPC actions",icon:"input-keyboard",run:()=>GlobalStates.openPanel("cheatsheet")},
            {id:"power",module:"powerMenu",text:"Power menu",description:"Review session and power actions",icon:"system-shutdown",run:()=>GlobalStates.openPanel("powermenu")},
            {id:"lock",module:"lockscreen",text:"Lock screen",description:"Lock the current session",icon:"system-lock-screen",run:()=>GlobalStates.lockSession()}
        ]
        commands.push({id:"caffeine",module:"",text:"Caffeine",
            description:IdleInhibitorService.inhibit ? "Allow idle sleep"+(IdleInhibitorService.temporary ? " · "+IdleInhibitorService.statusText : "") : "Keep the session awake",
            icon:"preferences-desktop-screensaver",run:()=>IdleInhibitorService.toggleInhibit()})
        for (const minutes of Array.from(AppConfig.temporaryModeDurations)) {
            commands.push(timedCommand("dnd",minutes),timedCommand("caffeine",minutes))
        }
        const explicit = removePrefix(query).toLowerCase().match(/^(dnd|caffeine)\s+(\d+)$/)
        if (explicit) {
            const minutes = Number(explicit[2])
            commands = Number.isInteger(minutes) && minutes >= 1 && minutes <= 1440 ? [timedCommand(explicit[1],minutes)] : []
            terms = []
        }
        return commands.filter(command => (!command.module || AppConfig.moduleEnabled(command.module))
            && terms.every(term => (command.id+" "+command.text+" "+command.description).toLowerCase().includes(term)))
            .map(command => ({id:"action:"+command.id,type:"action",text:command.text,
                description:command.description,icon:command.icon,score:0,action:command.run}))
    }
}
