pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

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

    // Процесс удаления записи (безопасный: без shell interpolation)
    Process {
        id: deleteProc
        property string pendingEntry: ""
        stdinEnabled: true

        command: [root.cliphistBinary, "delete"]

        onStarted: {
            // Отправляем entry через stdin - безопасно от injection
            deleteProc.write(deleteProc.pendingEntry)
        }

        onExited: (exitCode, exitStatus) => {
            deleteProc.pendingEntry = ""
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

    // Процесс копирования записи в clipboard (безопасный)
    Process {
        id: copyProc
        property string pendingEntry: ""
        stdinEnabled: true

        command: ["sh", "-c", root.cliphistBinary + " decode | wl-copy"]

        onStarted: {
            // Отправляем entry через stdin - безопасно от injection
            copyProc.write(copyProc.pendingEntry)
        }

        onExited: {
            copyProc.pendingEntry = ""
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

    // Простой fuzzy search
    function fuzzySearch(query) {
        if (!query || query.trim() === "") {
            return preparedEntries.slice(0, 20) // Top 20 recent
        }

        const queryLower = query.toLowerCase()
        const results = []

        for (let i = 0; i < preparedEntries.length; i++) {
            const item = preparedEntries[i]
            const contentLower = item.content.toLowerCase()

            // Substring match или fuzzy match
            if (contentLower.includes(queryLower)) {
                // Exact substring - высокий score
                const score = contentLower.startsWith(queryLower) ? 100 : 50
                results.push({
                    entry: item.entry,
                    content: item.content,
                    score: score
                })
            } else if (fuzzyMatch(contentLower, queryLower)) {
                // Fuzzy match - низкий score
                results.push({
                    entry: item.entry,
                    content: item.content,
                    score: 10
                })
            }
        }

        // Сортируем по score (descending)
        results.sort((a, b) => b.score - a.score)

        // Ограничиваем до 20 результатов
        return results.slice(0, 20)
    }

    // Fuzzy matching algorithm
    function fuzzyMatch(text, query) {
        let queryIndex = 0
        for (let i = 0; i < text.length && queryIndex < query.length; i++) {
            if (text[i] === query[queryIndex]) {
                queryIndex++
            }
        }
        return queryIndex === query.length
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
