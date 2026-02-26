pragma Singleton
import QtQuick
import Quickshell
import SystemMonitor 1.0

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

    // History arrays (4 min @ 2s interval = 120 samples)
    property var cpuHistory: []
    property var gpuHistory: []
    property var ramHistory: []
    property var netRxHistory: []
    property var netTxHistory: []
    readonly property int _maxHistory: 120

    function _push(arr, val) {
        arr.push(val);
        if (arr.length > _maxHistory) arr.shift();
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
            root._push(root.cpuHistory, root.cpuUsage / 100);
            root._push(root.gpuHistory, root.gpuUsage / 100);
            root._push(root.ramHistory, root.ramUsage / 100);
            root._push(root.netRxHistory, Math.min(root.netRxSpeed / 104857600, 1.0));
            root._push(root.netTxHistory, Math.min(root.netTxSpeed / 104857600, 1.0));

            // Trigger binding notifications by reassignment
            root.cpuHistory = root.cpuHistory;
            root.gpuHistory = root.gpuHistory;
            root.ramHistory = root.ramHistory;
            root.netRxHistory = root.netRxHistory;
            root.netTxHistory = root.netTxHistory;
        }

        function onErrorOccurred(message) {
            console.warn("SystemMonitor error:", message)
        }
    }
}
