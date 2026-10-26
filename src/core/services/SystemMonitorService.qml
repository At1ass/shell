pragma Singleton
import QtQuick
import Quickshell
import SystemMonitor 1.0
import qs.src.core.config

// Thin wrapper around C++ SystemMonitor singleton
// All heavy lifting is done in C++ for performance and reliability
Singleton {
    id: root

    // Re-export all properties from C++ SystemMonitor

    // CPU
    readonly property real cpuUsage: SystemMonitor.cpuUsage
    readonly property int cpuTemp: SystemMonitor.cpuTemp
    readonly property string cpuModel: SystemMonitor.cpuModel
    readonly property real cpuFreqGHz: SystemMonitor.cpuFreqGHz
    readonly property real loadAvg1: SystemMonitor.loadAvg1
    readonly property real loadAvg5: SystemMonitor.loadAvg5
    readonly property real loadAvg15: SystemMonitor.loadAvg15

    // RAM
    readonly property real ramUsage: SystemMonitor.ramUsage
    readonly property string ramUsed: SystemMonitor.ramUsed
    readonly property string ramTotal: SystemMonitor.ramTotal

    // Swap
    readonly property real swapUsage: SystemMonitor.swapUsage
    readonly property string swapUsed: SystemMonitor.swapUsed
    readonly property string swapTotal: SystemMonitor.swapTotal
    readonly property bool hasSwap: SystemMonitor.hasSwap

    // GPU
    readonly property int gpuUsage: SystemMonitor.gpuUsage
    readonly property int gpuTemp: SystemMonitor.gpuTemp
    readonly property string gpuModel: SystemMonitor.gpuModel
    readonly property bool hasGpuStats: SystemMonitor.hasGpuStats
    readonly property real gpuMemUsage: SystemMonitor.gpuMemUsage
    readonly property string gpuMemUsed: SystemMonitor.gpuMemUsed
    readonly property string gpuMemTotal: SystemMonitor.gpuMemTotal
    readonly property int gpuClockMHz: SystemMonitor.gpuClockMHz
    readonly property int gpuFanSpeed: SystemMonitor.gpuFanSpeed
    readonly property int gpuPowerWatts: SystemMonitor.gpuPowerWatts

    // Disk
    readonly property real diskUsage: SystemMonitor.diskUsage
    readonly property string diskUsed: SystemMonitor.diskUsed
    readonly property string diskTotal: SystemMonitor.diskTotal
    readonly property double diskReadSpeed: SystemMonitor.diskReadSpeed
    readonly property double diskWriteSpeed: SystemMonitor.diskWriteSpeed
    readonly property string diskReadFormatted: SystemMonitor.diskReadFormatted
    readonly property string diskWriteFormatted: SystemMonitor.diskWriteFormatted
    readonly property bool hasDiskIo: SystemMonitor.hasDiskIo

    // Capability lookup keeps the QML usable before the packaged plugin is upgraded.
    function _nativeProperty(name, fallback) { return SystemMonitor[name] ?? fallback }
    function _nativeBackend() { return SystemMonitor }
    readonly property bool storageAvailable: _nativeProperty("storageApiVersion", 0) >= 1
    readonly property var storageVolumes: _nativeProperty("storageVolumes", [])
    readonly property var storageDrives: _nativeProperty("storageDrives", [])
    readonly property var storageSummary: _nativeProperty("storageSummary", ({
        available: true, name: "System", mountPoint: "/",
        severity: 100 - diskUsage <= Math.min(AppConfig.storageCriticalFreePercent, AppConfig.storageWarningFreePercent) ? 2
            : 100 - diskUsage <= AppConfig.storageWarningFreePercent ? 1 : 0
    }))
    readonly property int storageSeverity: storageSummary.severity ?? 0
    readonly property string storageFreeText: storageAvailable
        ? `${storageSummary.availableFormatted ?? "—"} free`
        : `${Math.max(0, 100 - diskUsage).toFixed(1)}% free`
    readonly property int storageOtherAlerts: Math.max(0,
        (storageSummary.warningCount ?? 0) + (storageSummary.criticalCount ?? 0) - 1)
    readonly property string storageAlertText: storageSeverity > 0
        ? `${storageSeverity === 2 ? "Critical space" : "Low space"} · ${storageSummary.name ?? "Storage"}: ${storageFreeText}${storageOtherAlerts > 0 ? ` (+${storageOtherAlerts} more)` : ""}` : ""
    Binding {
        target: root.storageAvailable ? root._nativeBackend() : null
        property: "storageOptions"
        value: ({warningFreePercent: AppConfig.storageWarningFreePercent,
            criticalFreePercent: AppConfig.storageCriticalFreePercent,
            excludedMounts: Array.from(AppConfig.storageExcludedMounts),
            order: Array.from(AppConfig.storageOrder), labels: AppConfig.storageLabels})
    }

    // Network
    readonly property double netRxSpeed: SystemMonitor.netRxSpeed
    readonly property double netTxSpeed: SystemMonitor.netTxSpeed
    readonly property string netRxFormatted: SystemMonitor.netRxFormatted
    readonly property string netTxFormatted: SystemMonitor.netTxFormatted
    readonly property string netInterface: SystemMonitor.netInterface
    readonly property bool hasNet: SystemMonitor.hasNet

    // System info
    readonly property string userName: SystemMonitor.userName
    readonly property string osName: SystemMonitor.osName
    readonly property string wmName: SystemMonitor.wmName
    readonly property bool hasCpuTemp: SystemMonitor.hasCpuTemp

    readonly property bool isMonitoring: SystemMonitor.isMonitoring

    // Started by ServiceBootstrap, independently of lazy panel lifetimes.
    // The native worker owns polling; visibility only gates rendering.
    function init() { SystemMonitor.isMonitoring = true }

    // History arrays (4 min @ 2s interval = 120 samples)
    property var cpuHistory: []
    property var gpuHistory: []
    property var ramHistory: []
    property var cpuTempHistory: []
    property var gpuTempHistory: []
    readonly property bool hasGpuTemp: hasGpuStats && gpuTemp > 0
    property var netRxHistory: []
    property var netTxHistory: []
    readonly property int _maxHistory: 120

    // Immutable append: returns a NEW array. Mutating in place and
    // self-assigning does not work — writing the same JS array reference
    // back into a `var` property is dropped by the engine (strictlyEquals
    // short-circuit), so no change signal fires and every consumer binding
    // (delegates, Sparkline.values) stays frozen on the old snapshot.
    function _pushed(arr, val) {
        const next = arr.length >= _maxHistory ? arr.slice(arr.length - _maxHistory + 1) : arr.slice();
        next.push(val);
        return next;
    }

    // Re-export methods
    function setUpdateInterval(milliseconds) {
        SystemMonitor.setUpdateInterval(milliseconds)
    }

    function refresh() {
        SystemMonitor.refresh()
    }

    // Forward signals declaratively (auto-disconnect on destroy)
    Connections {
        target: SystemMonitor

        function onStatsUpdated() {
            root.cpuHistory = root._pushed(root.cpuHistory, root.cpuUsage / 100);
            root.gpuHistory = root._pushed(root.gpuHistory, root.gpuUsage / 100);
            root.ramHistory = root._pushed(root.ramHistory, root.ramUsage / 100);
            // A missing sensor starts a new series; never plot it as 0 °C.
            root.cpuTempHistory = root.hasCpuTemp
                ? root._pushed(root.cpuTempHistory, Math.max(0, Math.min(root.cpuTemp / 120, 1))) : [];
            root.gpuTempHistory = root.hasGpuTemp
                ? root._pushed(root.gpuTempHistory, Math.max(0, Math.min(root.gpuTemp / 120, 1))) : [];
            root.netRxHistory = root._pushed(root.netRxHistory, Math.min(root.netRxSpeed / 104857600, 1.0));
            root.netTxHistory = root._pushed(root.netTxHistory, Math.min(root.netTxSpeed / 104857600, 1.0));
        }

        function onErrorOccurred(message) {
            console.warn("SystemMonitor error:", message)
        }
    }
}
