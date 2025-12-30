pragma Singleton
import QtQuick
import SystemMonitor 1.0

// Thin wrapper around C++ SystemMonitor singleton
// All heavy lifting is done in C++ for performance and reliability
QtObject {
    id: root

    // Re-export all properties from C++ SystemMonitor
    readonly property real cpuUsage: SystemMonitor.cpuUsage
    readonly property int cpuTemp: SystemMonitor.cpuTemp
    readonly property string cpuModel: SystemMonitor.cpuModel

    readonly property real ramUsage: SystemMonitor.ramUsage
    readonly property string ramUsed: SystemMonitor.ramUsed
    readonly property string ramTotal: SystemMonitor.ramTotal

    readonly property int gpuUsage: SystemMonitor.gpuUsage
    readonly property int gpuTemp: SystemMonitor.gpuTemp
    readonly property string gpuModel: SystemMonitor.gpuModel
    readonly property bool hasGpuStats: SystemMonitor.hasGpuStats

    readonly property real diskUsage: SystemMonitor.diskUsage
    readonly property string diskUsed: SystemMonitor.diskUsed
    readonly property string diskTotal: SystemMonitor.diskTotal

    readonly property string userName: SystemMonitor.userName
    readonly property string osName: SystemMonitor.osName
    readonly property string wmName: SystemMonitor.wmName
    readonly property bool hasCpuTemp: SystemMonitor.hasCpuTemp

    readonly property bool isMonitoring: SystemMonitor.isMonitoring

    // Re-export methods
    function setUpdateInterval(milliseconds) {
        SystemMonitor.setUpdateInterval(milliseconds)
    }

    function refresh() {
        SystemMonitor.refresh()
    }

    // Forward signals
    Component.onCompleted: {
        SystemMonitor.statsUpdated.connect(function() {
            // Can add custom logic here if needed
        })

        SystemMonitor.errorOccurred.connect(function(message) {
            console.warn("SystemMonitor error:", message)
        })
    }
}
