pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.src.core.config

Singleton {
    id: root
    readonly property var device: UPower.displayDevice
    readonly property bool available: !!device && device.ready && device.isLaptopBattery
        && Number.isFinite(device.percentage) && device.percentage>=0 && device.percentage<=1
    readonly property int percentage: available ? Math.round(device.percentage*100) : 0
    readonly property bool charging: available && (device.state===UPowerDeviceState.Charging || device.state===UPowerDeviceState.PendingCharge)
    readonly property bool discharging: available && (device.state===UPowerDeviceState.Discharging
        || device.state===UPowerDeviceState.Empty || device.state===UPowerDeviceState.PendingDischarge)
    readonly property bool lowBattery: available && discharging && percentage<=AppConfig.batteryLowThreshold
    readonly property string remainingText: {
        const seconds=available ? Number(charging ? device.timeToFull : discharging ? device.timeToEmpty : 0) : 0
        if (!Number.isFinite(seconds) || seconds<=0) return ""
        const minutes=Math.ceil(seconds/60)
        return (minutes>=60 ? Math.floor(minutes/60)+"h " : "")+(minutes%60)+"m "+(charging ? "until full" : "remaining")
    }
    readonly property string statusText: !available ? "Battery unavailable" : percentage+"% · "+(charging ? "Charging" : discharging ? "On battery" : device.state===UPowerDeviceState.FullyCharged ? "Charged" : "State unavailable")
        +(remainingText ? " · "+remainingText : "")
    readonly property var warningState: AppConfig.stateData?.powerWarnings ?? ({})
    property int lastNotificationExitCode: 0
    function init() { reconcile() }
    onAvailableChanged: Qt.callLater(reconcile)
    onPercentageChanged: Qt.callLater(reconcile)
    onDischargingChanged: Qt.callLater(reconcile)
    Connections {
        target: AppConfig
        function onStateReadyChanged() { root.reconcile() }
        function onReadyChanged() { root.reconcile() }
        function onDataChanged() { Qt.callLater(root.reconcile) }
    }
    Connections { target:SessionMonitor;function onResumed() { root.reconcile() } }
    function reconcile() {
        if (!AppConfig.ready || !AppConfig.stateReady || !available || !AppConfig.batteryWarningsEnabled) {
            if (!available || !AppConfig.batteryWarningsEnabled) notice.cancelPending()
            return
        }
        const identity=device.nativePath || "display"
        let low=warningState.device===identity && warningState.lowNotified===true
        let critical=warningState.device===identity && warningState.criticalNotified===true
        const criticalThreshold=Math.min(AppConfig.batteryCriticalThreshold,AppConfig.batteryLowThreshold)
        let level=0
        if (charging || device.state===UPowerDeviceState.FullyCharged) { low=false;critical=false;notice.cancelPending() }
        else if (discharging) {
            notice.cancelAbove(percentage<=criticalThreshold ? 2 : percentage<=AppConfig.batteryLowThreshold ? 1 : 0)
            if (percentage>=AppConfig.batteryLowThreshold+AppConfig.batteryWarningHysteresis) low=false
            if (percentage>=criticalThreshold+AppConfig.batteryWarningHysteresis) critical=false
            if (percentage<=criticalThreshold && !critical) { level=2;critical=true;low=true }
            else if (percentage<=AppConfig.batteryLowThreshold && !low) { level=1;low=true }
        }
        else return
        if (warningState.device!==identity || warningState.lowNotified!==low || warningState.criticalNotified!==critical)
            AppConfig.updateState("powerWarnings",{device:identity,lowNotified:low,criticalNotified:critical})
        if (level) notice.send(level===2 ? "Battery critically low" : "Battery low",
            percentage+"% remaining. Connect a charger."+(remainingText ? " About "+remainingText+"." : ""),level)
    }
    DesktopNotification {
        id: notice
        objectName: "batteryNotification"
        appName: "Power"
        onDelivered: exitCode => root.lastNotificationExitCode=exitCode
    }
    IpcHandler {
        target:"power"
        function status(): string {
            return JSON.stringify({available:root.available,percentage:root.percentage,charging:root.charging,
                discharging:root.discharging,remaining:root.remainingText,low:root.lowBattery,notificationExitCode:root.lastNotificationExitCode})
        }
    }
}
