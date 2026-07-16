pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import FuzzySearch

// Clipboard history service backed by cliphist
Singleton {
    id: root

    // cliphist command
    property string cliphistBinary: "cliphist"

    // Clipboard history
    property list<string> entries: []

    // Entries prepared for search
    readonly property var preparedEntries: entries.map(entry => {
        // Strip the leading ID (cliphist format: "ID\tCONTENT")
        const content = entry.replace(/^\s*\S+\s+/, "")
        return {
            content: content,
            entry: entry
        }
    })

    // Refresh history when the clipboard changes
    Connections {
        target: Quickshell
        function onClipboardTextChanged() {
            // Small delay to avoid a race condition with cliphist
            delayedUpdateTimer.restart()
        }
    }

    Timer {
        id: delayedUpdateTimer
        interval: 100
        repeat: false
        onTriggered: {
            root.refresh()
        }
    }

    // History read process
    Process {
        id: readProc
        property list<string> buffer: []

        command: [root.cliphistBinary, "list"]

        stdout: SplitParser {
            onRead: (line) => {
                readProc.buffer.push(line)
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.entries = readProc.buffer
            } else {
                console.error("[ClipboardService] Failed to refresh with code", exitCode, "and status", exitStatus)
            }
        }
    }

    // Delete entry via cliphist delete (stdin, no shell interpolation)
    Process {
        id: deleteProc
        property string pendingEntry: ""
        stdinEnabled: true

        command: [root.cliphistBinary, "delete"]

        onStarted: {
            deleteProc.write(deleteProc.pendingEntry + "\n")
            deleteProc.stdinEnabled = false
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                console.warn("[ClipboardService] Delete failed with code", exitCode)
            deleteProc.pendingEntry = ""
            deleteProc.stdinEnabled = true
            root.refresh()
        }
    }

    function safeDeleteEntry(entry) {
        if (deleteProc.running) {
            console.warn("[ClipboardService] Delete already in progress")
            return
        }
        deleteProc.pendingEntry = entry
        deleteProc.running = true
    }

    // Refresh history
    function refresh() {
        readProc.buffer = []
        readProc.running = true
    }

    // Copy entry to clipboard via cliphist decode | wl-copy
    Process {
        id: copyProc
        property string pendingEntry: ""
        stdinEnabled: true

        // Positional argv — never concatenate variables into the script
        // (AGENTS ban 25). $1 is the cliphist binary path.
        command: ["sh", "-c", '"$1" decode | wl-copy', "sh", root.cliphistBinary]

        onStarted: {
            copyProc.write(copyProc.pendingEntry + "\n")
            copyProc.stdinEnabled = false // close stdin → EOF for cliphist decode
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                ToastService.error("Failed to copy to clipboard")
            copyProc.pendingEntry = ""
            copyProc.stdinEnabled = true // re-enable for next invocation
        }
    }

    // Copy an entry to the clipboard
    function copy(entry) {
        if (copyProc.running) {
            console.warn("[ClipboardService] Copy already in progress")
            return
        }
        copyProc.pendingEntry = entry
        copyProc.running = true
    }

    // Delete an entry
    function deleteEntry(entry) {
        safeDeleteEntry(entry)
    }

    // Trace fuzzySearch input/output to console.
    property bool debug: false

    // Empty query → raw cliphist order (newest first), no sorting/filtering,
    // including binary/image entries so the user can scroll to a screenshot.
    // Non-empty query → fuzzy match against text entries only; binary entries
    // are dropped since their placeholder text would never match meaningfully.
    function fuzzySearch(query) {
        if (debug) {
            console.info("[ClipboardService.fuzzySearch] entries:", entries.length,
                        "query:", JSON.stringify(query))
            for (let k = 0; k < Math.min(entries.length, 10); k++)
                console.info("  cliphist[" + k + "]:",
                            entries[k].substring(0, 60).replace(/\n/g, "\\n"))
        }
        if (!query || query.trim() === "") {
            return preparedEntries.map(e => ({
                entry: e.entry, content: e.content, score: 0
            }))
        }

        // Build a parallel array of text-only entries, remembering each
        // entry's original cliphist index so results can be re-ordered by it.
        const textIndices = []
        const textContents = []
        for (let i = 0; i < preparedEntries.length; i++) {
            if (root.entryIsImage(preparedEntries[i].entry)) continue
            textIndices.push(i)
            textContents.push(preparedEntries[i].content)
        }

        const hits = FuzzySearch.match(query, textContents, 50, 30.0)

        // Map hit's text-array index back to the original cliphist index.
        const matched = hits.map(h => ({
            originalIndex: textIndices[h.index],
            score: h.score
        }))
        matched.sort((a, b) => a.originalIndex - b.originalIndex)

        return matched.map(m => ({
            entry: preparedEntries[m.originalIndex].entry,
            content: preparedEntries[m.originalIndex].content,
            score: m.score
        }))
    }

    // Check whether an entry is an image
    function entryIsImage(entry) {
        return /^\d+\t\[\[.*binary data.*\d+x\d+.*\]\]$/.test(entry)
    }

    // Extract the ID from a cliphist entry (format: "ID\tCONTENT")
    function _extractEntryId(entry) {
        const match = entry.match(/^(\d+)\t/)
        return match ? match[1] : ""
    }

    // === Thumbnail cache for images ===
    readonly property string _thumbnailDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/quickshell-clipboard-thumbs"
    property var _thumbnailCache: ({})
    property int _thumbnailVersion: 0
    property var _thumbQueue: []

    function thumbnailFor(entry) {
        const id = _extractEntryId(entry)
        return _thumbnailCache[id] || ""
    }

    function requestThumbnail(entry) {
        const id = _extractEntryId(entry)
        if (!id || _thumbnailCache[id]) return
        // Do not queue duplicates
        for (let i = 0; i < _thumbQueue.length; i++) {
            if (_thumbQueue[i].id === id) return
        }
        _thumbQueue.push({ id: id, entry: entry })
        _processNextThumb()
    }

    function _processNextThumb() {
        if (thumbDecodeProc.running || _thumbQueue.length === 0) return
        const item = _thumbQueue.shift()
        thumbDecodeProc._entryId = item.id
        thumbDecodeProc._entry = item.entry
        thumbDecodeProc._outPath = root._thumbnailDir + "/" + item.id
        // Paths as positional argv ($1, $2) — script string is a literal so
        // there's no shell-concat injection surface.
        thumbDecodeProc.command = ["sh", "-c",
            'exec "$1" decode > "$2"',
            "sh", root.cliphistBinary, thumbDecodeProc._outPath]
        thumbDecodeProc.running = true
    }

    Process {
        id: thumbDirInitProc
        command: ["mkdir", "-p", root._thumbnailDir]
        running: true
    }

    Process {
        id: thumbDecodeProc
        property string _entryId: ""
        property string _entry: ""
        property string _outPath: ""
        stdinEnabled: true

        onStarted: {
            thumbDecodeProc.write(thumbDecodeProc._entry + "\n")
            thumbDecodeProc.stdinEnabled = false
        }

        onExited: (exitCode) => {
            if (exitCode === 0 && thumbDecodeProc._entryId) {
                let cache = Object.assign({}, root._thumbnailCache)
                cache[thumbDecodeProc._entryId] = thumbDecodeProc._outPath
                root._thumbnailCache = cache
                root._thumbnailVersion++
            }
            thumbDecodeProc.stdinEnabled = true
            root._processNextThumb()
        }
    }

    // Initialize on startup
    Component.onCompleted: {
        refresh()
    }
}
