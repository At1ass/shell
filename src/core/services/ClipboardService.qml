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

        onExited: {
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
    function fuzzySearch(query) {
        if (!query || query.trim() === "") {
            return preparedEntries.slice(0, 20)
        }

        const contents = preparedEntries.map(e => e.content)
        const hits = FuzzySearch.match(query, contents, 20, 30.0)
        const results = []
        for (let i = 0; i < hits.length; i++) {
            const idx = hits[i].index
            results.push({
                entry: preparedEntries[idx].entry,
                content: preparedEntries[idx].content,
                score: hits[i].score
            })
        }
        return results
    }

    // Проверка, является ли запись изображением
    function entryIsImage(entry) {
        return /^\d+\t\[\[.*binary data.*\d+x\d+.*\]\]$/.test(entry)
    }

    // Инициализация при старте
    Component.onCompleted: {
        refresh()
    }
}
