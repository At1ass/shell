pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.src.core.config
import "TimerTimeline.js" as Timeline

Singleton {
    id: root
    readonly property var stored: AppConfig.stateData?.timer ?? ({status:"idle"})
    property real _now: Date.now()
    readonly property var view: Timeline.snapshot(stored,_now)
    readonly property string status: AppConfig.stateReady ? view.status : "idle"
    readonly property bool running: status === "running"
    readonly property bool paused: status === "paused"
    readonly property bool active: running || paused
    readonly property string phaseLabel: view.phase === "work" ? "Work" : view.phase === "shortBreak"
        ? "Short break" : view.phase === "longBreak" ? "Long break" : "Timer"
    readonly property string timeText: {
        const seconds = Math.ceil(view.remainingMs/1000)
        return Math.floor(seconds/60)+":"+String(seconds%60).padStart(2,"0")
    }
    property int displayWatchers: 0
    function addDisplayWatcher() { ++displayWatchers; refresh() }
    function removeDisplayWatcher() { displayWatchers = Math.max(0,displayWatchers-1) }
    function init() { refresh() }
    onStoredChanged: Qt.callLater(refresh)
    Connections {
        target: AppConfig
        function onStateReadyChanged() { root.refresh() }
        function onReadyChanged() { root.refresh() }
        function onTimersEnabledChanged() { root.refresh() }
    }
    Connections {
        target: SessionMonitor
        function onResumed() { root.refresh() }
    }
    Connections {
        target: DateTime.clock
        enabled: root.running
        function onDateChanged() { root.refresh() }
    }
    Timer {
        id: boundary
        onTriggered: root.refresh()
    }
    Timer {
        interval: 1000
        repeat: true
        running: root.running && root.displayWatchers > 0
        onTriggered: root.refresh()
    }
    function start(minutes) {
        if (!AppConfig.ready || !AppConfig.stateReady || !AppConfig.timersEnabled || active
            || !Number.isInteger(minutes) || minutes < 1 || minutes > 1440) return false
        AppConfig.updateState("timer",{mode:"timer",status:"running",startedAt:Date.now(),elapsedMs:0,
            durationMs:minutes*60000,notifiedStage:0})
        refresh()
        return true
    }
    function pomodoro() {
        if (!AppConfig.ready || !AppConfig.stateReady || !AppConfig.timersEnabled || active) return false
        AppConfig.updateState("timer",{mode:"pomodoro",status:"running",startedAt:Date.now(),elapsedMs:0,
            workMs:AppConfig.pomodoroWorkMinutes*60000,shortMs:AppConfig.pomodoroShortBreakMinutes*60000,
            longMs:AppConfig.pomodoroLongBreakMinutes*60000,longEvery:AppConfig.pomodoroLongEvery,notifiedStage:0})
        refresh()
        return true
    }
    function pause() {
        if (!AppConfig.stateReady || !running) return false
        const current = Timeline.snapshot(stored,Date.now())
        // Resolve a deadline before pausing; an expired countdown stays finished.
        if (current.status === "finished") { refresh(); return false }
        AppConfig.updateState("timer",{status:"paused",elapsedMs:current.elapsedMs,startedAt:0})
        refresh()
        return true
    }
    function resume() {
        if (!AppConfig.ready || !AppConfig.stateReady || !AppConfig.timersEnabled || !paused) return false
        AppConfig.updateState("timer",{status:"running",startedAt:Date.now()})
        refresh()
        return true
    }
    function stop() {
        if (!AppConfig.stateReady || status === "idle") return false
        AppConfig.updateState("timer",{status:"idle",elapsedMs:0,startedAt:0})
        refresh()
        return true
    }
    function refresh() {
        boundary.stop()
        _now = Date.now()
        if (!AppConfig.ready || !AppConfig.stateReady || view.status === "idle") return
        if (!AppConfig.timersEnabled) {
            if (stored.status === "running") {
                if (view.status === "finished") AppConfig.updateState("timer",{status:"finished",elapsedMs:view.elapsedMs,startedAt:0})
                else pause()
            }
            return
        }
        if (stored.status !== "running") return
        if (view.status === "finished") {
            AppConfig.updateState("timer",{status:"finished",elapsedMs:view.elapsedMs,startedAt:0})
            notify("Timer finished", "The countdown is complete.")
            return
        }
        if (view.mode === "pomodoro" && view.stage !== stored.notifiedStage) {
            const label = phaseLabel
            const remaining = Math.ceil(view.remainingMs/60000)
            AppConfig.updateState("timer",{notifiedStage:view.stage})
            notify("Pomodoro: "+label, remaining+" min remaining in the current stage.")
        }
        boundary.interval = Math.min(2147483647,Math.max(1,view.remainingMs))
        boundary.start()
    }
    function notify(summary, body) {
        if (AppConfig.timerNotify) notification.send(summary,body,1)
    }
    DesktopNotification {
        id: notification
        objectName: "timerNotification"
        onDelivered: exitCode => { if (exitCode !== 0) ToastService.warning("Timer notification could not be delivered. Check the dashboard.") }
    }
    IpcHandler {
        target: "timer"
        function start(minutes: int): bool { return root.start(minutes) }
        function pomodoro(): bool { return root.pomodoro() }
        function pause(): bool { return root.pause() }
        function resume(): bool { return root.resume() }
        function stop(): bool { return root.stop() }
        function status(): string { root.refresh(); return JSON.stringify(root.view) }
    }
}
