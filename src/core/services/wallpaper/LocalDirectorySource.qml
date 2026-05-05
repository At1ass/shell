import QtQuick
import Quickshell.Io

// Wallpaper source backed by a local filesystem directory. Scans for
// images via `find` (single subprocess per refresh, max-depth 1).
//
// Item.url is the absolute file path; resolveItem returns it directly.

BaseWallpaperSource {
    id: source

    iconName: "folder"

    // Directory to scan. Setting this triggers a refresh.
    property string directoryPath: ""
    onDirectoryPathChanged: {
        if (directoryPath && directoryPath.length > 0) {
            source.refresh()
        } else {
            source.items = []
            source.ready = false
        }
    }

    // Override of BaseWallpaperSource.refresh
    function refresh() {
        if (!directoryPath || directoryPath.length === 0) {
            source._setError("LocalDirectorySource: empty directoryPath")
            return
        }
        if (_scan.running) return
        source.loading = true
        _scan.command = [
            "find", directoryPath,
            "-maxdepth", "1",
            "-type", "f",
            "(",
            "-iname", "*.jpg",
            "-o", "-iname", "*.jpeg",
            "-o", "-iname", "*.png",
            "-o", "-iname", "*.webp",
            ")"
        ]
        _scan.running = true
    }

    // QtObject lacks default children list; attach Process via a
    // named property (same pattern used in NotifData).
    property Process _scan: Process {
        id: scanProc

        stdout: StdioCollector {
            id: scanCollector
            onStreamFinished: {
                const trimmed = text.trim()
                const files = trimmed.length > 0
                    ? trimmed.split("\n").filter(f => f.length > 0).sort()
                    : []
                source.items = files.map(p => ({
                    "id": p,                          // path is unique within this source
                    "name": p.substring(p.lastIndexOf("/") + 1),
                    "url": p,
                    "thumbnail": p,
                    "metadata": {}
                }))
                source.lastError = ""
                source.ready = true
                source.loading = false
                source.itemsRefreshed()
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const err = text.trim()
                if (err) source._setError("find: " + err)
            }
        }

        onExited: (exitCode) => {
            source.loading = false
            if (exitCode !== 0 && source.lastError === "") {
                source._setError("find exited with code " + exitCode)
            }
        }
    }
}
