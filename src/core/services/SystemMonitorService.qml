pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // CPU
    property real cpuUsage: 0
    property int cpuTemp: 0
    property string cpuModel: ""

    // RAM
    property real ramUsage: 0
    property string ramUsed: "0.0"
    property string ramTotal: "0.0"

    // GPU
    property int gpuUsage: 0
    property int gpuTemp: 0
    property string gpuModel: ""

    // Disk
    property real diskUsage: 0
    property string diskUsed: "0"
    property string diskTotal: "0"

    // System info
    property string userName: ""
    property string osName: "Arch Linux"
    property string wmName: "Hyprland"

    // CPU calculation
    property var lastCpuIdle: 0
    property var lastCpuTotal: 0

    Component.onCompleted: {
        updateCpu()
        updateRam()
        diskProcess.running = true
        tempProcess.running = true
        gpuProcess.running = true
        cpuInfoProcess.running = true
        gpuInfoProcess.running = true
        userInfoProcess.running = true
    }

    // Update timer
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            root.updateCpu()
            root.updateRam()
            diskProcess.running = true
            tempProcess.running = true
            gpuProcess.running = true
        }
    }

    // CPU monitoring
    FileView {
        id: cpuStatFile
        path: "/proc/stat"
    }

    function updateCpu() {
        cpuStatFile.reload()
        const lines = cpuStatFile.text().split('\n')
        const cpuLine = lines.find(line => line.startsWith('cpu '))

        if (!cpuLine) return

        const values = cpuLine.split(/\s+/).slice(1).map(v => parseInt(v))
        const idle = values[3] || 0
        const total = values.reduce((sum, val) => sum + val, 0)

        if (lastCpuTotal !== 0) {
            const totalDiff = total - lastCpuTotal
            const idleDiff = idle - lastCpuIdle
            cpuUsage = totalDiff > 0 ? ((totalDiff - idleDiff) / totalDiff) * 100 : 0
        }

        lastCpuIdle = idle
        lastCpuTotal = total
    }

    // RAM monitoring
    FileView {
        id: meminfoFile
        path: "/proc/meminfo"
    }

    function updateRam() {
        meminfoFile.reload()
        const lines = meminfoFile.text().split('\n')

        let memTotal = 0
        let memAvailable = 0

        lines.forEach(line => {
            if (line.startsWith('MemTotal:')) {
                memTotal = parseInt(line.split(/\s+/)[1]) / 1024 / 1024 // Convert to GB
            } else if (line.startsWith('MemAvailable:')) {
                memAvailable = parseInt(line.split(/\s+/)[1]) / 1024 / 1024 // Convert to GB
            }
        })

        const memUsed = memTotal - memAvailable
        ramUsage = memTotal > 0 ? (memUsed / memTotal) * 100 : 0
        ramUsed = memUsed.toFixed(1)
        ramTotal = memTotal.toFixed(1)
    }

    // Temperature monitoring - использует sensors для CPU (Tctl для AMD)
    Process {
        id: tempProcess
        command: ["sensors"]
        running: false

        stdout: StdioCollector {
            id: tempCollector
            onStreamFinished: {
                const text = tempCollector.text
                // Ищем Tctl (AMD) или Package/Core (Intel)
                const tctlMatch = text.match(/Tctl:\s+\+?([0-9.]+)°C/)
                const packageMatch = text.match(/Package id 0:\s+\+?([0-9.]+)°C/)

                if (tctlMatch) {
                    root.cpuTemp = Math.round(parseFloat(tctlMatch[1]))
                } else if (packageMatch) {
                    root.cpuTemp = Math.round(parseFloat(packageMatch[1]))
                }
            }
        }
    }

    // Disk monitoring
    Process {
        id: diskProcess
        command: ["df", "-h", "/"]
        running: false

        stdout: StdioCollector {
            id: diskCollector
            onStreamFinished: {
                const lines = diskCollector.text.split('\n')
                if (lines.length > 1) {
                    const parts = lines[1].split(/\s+/)
                    if (parts.length >= 5) {
                        root.diskUsed = parts[2] || "0"
                        root.diskTotal = parts[1] || "0"
                        const percent = parts[4] || "0%"
                        root.diskUsage = parseFloat(percent.replace('%', ''))
                    }
                }
            }
        }
    }

    // GPU monitoring (NVIDIA)
    Process {
        id: gpuProcess
        command: ["nvidia-smi", "--query-gpu=utilization.gpu,temperature.gpu", "--format=csv,noheader,nounits"]
        running: false

        stdout: StdioCollector {
            id: gpuCollector
            onStreamFinished: {
                const text = gpuCollector.text.trim()
                if (text.length > 0) {
                    const parts = text.split(',')
                    if (parts.length >= 2) {
                        root.gpuUsage = parseInt(parts[0].trim())
                        root.gpuTemp = parseInt(parts[1].trim())
                    }
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                // Fallback for non-NVIDIA GPUs or no GPU
                if (this.text.length > 0) {
                    root.gpuUsage = 0
                    root.gpuTemp = 0
                }
            }
        }
    }

    // CPU model info (static)
    Process {
        id: cpuInfoProcess
        command: ["lscpu"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const text = this.text
                const modelMatch = text.match(/Model name:\s*(.+)/)
                if (modelMatch) {
                    let model = modelMatch[1].trim()
                    // Сокращаем: "AMD Ryzen 7 7700X 8-Core Processor" -> "R7 7700X"
                    model = model.replace(/AMD Ryzen (\d) (\w+).*/i, 'R$1 $2')
                    model = model.replace(/Intel.*Core.*i(\d)-(\w+).*/i, 'i$1-$2')
                    root.cpuModel = model
                }
            }
        }
    }

    // GPU model info (static)
    Process {
        id: gpuInfoProcess
        command: ["lspci"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const text = this.text
                const gpuMatch = text.match(/VGA.*NVIDIA.*\[(.+?)\]/)
                const amdMatch = text.match(/VGA.*AMD.*\[(.+?)\]/)

                if (gpuMatch) {
                    let model = gpuMatch[1].trim()
                    // "GeForce RTX 4070 Ti" -> "RTX 4070 Ti"
                    model = model.replace(/GeForce\s*/i, '')
                    root.gpuModel = model
                } else if (amdMatch) {
                    root.gpuModel = amdMatch[1].trim()
                }
            }
        }
    }

    // Username (static)
    Process {
        id: userInfoProcess
        command: ["whoami"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                root.userName = this.text.trim()
            }
        }
    }
}
