pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import FuzzySearch

// Сервис для работы с историей буфера обмена через cliphist
Singleton {
    id: root

    // Команда cliphist
    property string cliphistBinary: "cliphist"

    // История буфера обмена
    property list<string> entries: []

    // Подготовленные записи для поиска
    readonly property var preparedEntries: entries.map(entry => {
        // Убираем ID в начале (формат cliphist: "ID\tCONTENT")
        const content = entry.replace(/^\s*\S+\s+/, "")
        return {
            content: content,
            entry: entry
        }
    })

    // Обновление истории при изменении clipboard
    Connections {
        target: Quickshell
        function onClipboardTextChanged() {
            // Небольшая задержка для race condition с cliphist
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

    // Процесс чтения истории
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

    // Обновление истории
    function refresh() {
        readProc.buffer = []
        readProc.running = true
    }

    // Copy entry to clipboard via cliphist decode | wl-copy
    Process {
        id: copyProc
        property string pendingEntry: ""
        stdinEnabled: true

        command: ["sh", "-c", root.cliphistBinary + " decode | wl-copy"]

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

    // Копирование записи в clipboard
    function copy(entry) {
        if (copyProc.running) {
            console.warn("[ClipboardService] Copy already in progress")
            return
        }
        copyProc.pendingEntry = entry
        copyProc.running = true
    }

    // Удаление записи
    function deleteEntry(entry) {
        safeDeleteEntry(entry)
    }

    // Fuzzy search через C++ rapidfuzz
    // Фильтрует записи, но сохраняет порядок cliphist (по времени, свежие первые)
    function fuzzySearch(query) {
        if (!query || query.trim() === "") {
            return preparedEntries.slice(0, 20)
        }

        const contents = preparedEntries.map(e => e.content)
        const hits = FuzzySearch.match(query, contents, 20, 30.0)

        // Собираем совпавшие индексы и сортируем по оригинальной позиции
        const matched = []
        for (let i = 0; i < hits.length; i++) {
            matched.push({ originalIndex: hits[i].index, score: hits[i].score })
        }
        matched.sort((a, b) => a.originalIndex - b.originalIndex)

        const results = []
        for (let i = 0; i < matched.length; i++) {
            const idx = matched[i].originalIndex
            results.push({
                entry: preparedEntries[idx].entry,
                content: preparedEntries[idx].content,
                score: matched[i].score
            })
        }
        return results
    }

    // Проверка, является ли запись изображением
    function entryIsImage(entry) {
        return /^\d+\t\[\[.*binary data.*\d+x\d+.*\]\]$/.test(entry)
    }

    // Извлечение ID из записи cliphist (формат: "ID\tCONTENT")
    function _extractEntryId(entry) {
        const match = entry.match(/^(\d+)\t/)
        return match ? match[1] : ""
    }

    // === Thumbnail cache для изображений ===
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
        // Не добавлять дубли в очередь
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
        thumbDecodeProc.command = ["sh", "-c", "mkdir -p '" + root._thumbnailDir + "' && " + root.cliphistBinary + " decode > '" + thumbDecodeProc._outPath + "'"]
        thumbDecodeProc.running = true
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

    // Инициализация при старте
    Component.onCompleted: {
        refresh()
    }
}
