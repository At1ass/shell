pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.src.ui.base
import qs.src.ui.containers
import qs.src.core.config
import qs.src.core.services

ColumnLayout {
    id: root
    spacing: Tokens.spacing.extraSmall
    visible: AppConfig.timersEnabled && AppConfig.timerShowInDashboard
    readonly property bool displayActive: visible && GlobalStates.dashboardOpen && GlobalStates.dashboardOpenIndex === 0
    property bool _registered: false
    function syncDisplay() {
        if (_registered === displayActive) return
        _registered = displayActive
        if (_registered) TimerService.addDisplayWatcher()
        else TimerService.removeDisplayWatcher()
    }
    onDisplayActiveChanged: syncDisplay()
    Component.onCompleted: syncDisplay()
    Component.onDestruction: if (_registered) TimerService.removeDisplayWatcher()
    ListItem {
        Layout.fillWidth: true
        clickable: false
        leadingIcon: "timer"
        headline: TimerService.status === "idle" ? "Timer" : TimerService.status === "finished" ? "Timer finished"
            : TimerService.timeText + " · " + TimerService.phaseLabel + (TimerService.paused ? " · Paused" : "")
        supportingText: TimerService.active && TimerService.view.mode === "pomodoro"
            ? "Work interval " + TimerService.view.round + " / " + TimerService.stored.longEvery + " · Automatic cycle"
            : TimerService.active ? "Countdown" : "Countdown or Pomodoro work/break cycle"
        headlineTextFormat: Text.PlainText
        supportingTextFormat: Text.PlainText
    }
    GridLayout {
        Layout.fillWidth: true
        columns: width < Math.max(startButton.implicitWidth,otherButton.implicitWidth) * 2 + columnSpacing ? 1 : 2
        columnSpacing: Tokens.spacing.small
        rowSpacing: Tokens.spacing.extraSmall
        MaterialButton {
            id: startButton
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: TimerService.active ? TimerService.paused ? "Resume" : "Pause" : AppConfig.timerDefaultMinutes + " min"
            Accessible.name: TimerService.active ? text : "Start a " + AppConfig.timerDefaultMinutes + " minute timer"
            onClicked: {
                if (TimerService.paused) TimerService.resume()
                else if (TimerService.running) TimerService.pause()
                else TimerService.start(AppConfig.timerDefaultMinutes)
            }
        }
        MaterialButton {
            id: otherButton
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: TimerService.active ? "Stop" : "Pomodoro"
            Accessible.name: TimerService.active ? "Stop timer" : "Start Pomodoro"
            onClicked: { if (TimerService.active) TimerService.stop(); else TimerService.pomodoro() }
        }
    }
}
