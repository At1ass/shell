pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.src.ui.base
import qs.src.ui.containers
import qs.src.ui.inputs
import qs.src.core.config
import qs.src.core.services

ColumnLayout {
    id: root
    spacing: Tokens.spacing.extraSmall
    visible: AppConfig.timersEnabled && AppConfig.timerShowInDashboard
    readonly property bool displayActive: visible && GlobalStates.dashboardOpen && GlobalStates.dashboardOpenIndex === 0
    property bool _registered: false
    property int selectedMinutes: AppConfig.timerDefaultMinutes
    property bool customDuration: false
    readonly property var durationValues: [AppConfig.timerDefaultMinutes, selectedMinutes].concat(AppConfig.timerPresetsMinutes).filter((value, index, values) => values.indexOf(value) === index).sort((a, b) => a - b)
    readonly property int durationMinutes: customDuration ? Number(durationInput.text) : selectedMinutes
    readonly property bool durationValid: (!customDuration || durationInput.inputItem.acceptableInput)
        && Number.isInteger(durationMinutes) && durationMinutes >= 1 && durationMinutes <= 1440
    function startCountdown() {
        if (durationValid && TimerService.start(durationMinutes)) {
            Qt.callLater(() => startButton.forceActiveFocus())
        }
    }
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
    MaterialComboBox {
        objectName: "timerDurationPreset"
        Layout.fillWidth: true
        visible: !TimerService.active
        label: "Timer duration"
        model: root.durationValues.map(minutes => minutes + " min").concat(["Custom…"])
        controlled: true
        currentIndex: root.customDuration ? root.durationValues.length : root.durationValues.indexOf(root.selectedMinutes)
        onActivated: index => {
            root.customDuration = index === root.durationValues.length
            if (!root.customDuration) root.selectedMinutes = root.durationValues[index]
            else Qt.callLater(() => durationInput.inputItem.forceActiveFocus())
        }
    }
    MaterialTextField {
        id: durationInput
        objectName: "timerCustomMinutes"
        Layout.fillWidth: true
        visible: !TimerService.active && root.customDuration
        label: "Minutes"
        placeholderText: "Minutes"
        supportingText: "Minutes · 1–1440"
        text: String(root.selectedMinutes)
        validator: IntValidator { bottom: 1; top: 1440 }
        errorText: text !== "" && !root.durationValid ? "Enter a whole number from 1 to 1440" : ""
        onAccepted: root.startCountdown()
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
            text: TimerService.active ? TimerService.paused ? "Resume" : "Pause" : "Start timer"
            Accessible.name: TimerService.active ? text : "Start a " + root.durationMinutes + " minute timer"
            enabled: TimerService.active || root.durationValid
            onClicked: {
                if (TimerService.paused) TimerService.resume()
                else if (TimerService.running) TimerService.pause()
                else root.startCountdown()
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
