import QtQuick
import Quickshell
import FileSearch
import qs.src.core.services

// Провайдер для fuzzy поиска файлов через rapidfuzz
BaseProvider {
    id: root

    name: "Files"
    priority: 30  // Средне-низкий приоритет
    prefixes: ["?"]  // Fuzzy file search режим

    // Кэшированные результаты последнего успешного поиска
    property var lastResults: []
    property string lastQuery: ""
    property bool cacheInitStarted: false

    // Ссылка на LauncherService для триггера обновлений
    property var launcherService: null

    function search(query) {
        // Убираем префикс если есть
        let searchQuery = removePrefix(query).trim()

        // Минимум 1 символ для поиска
        if (searchQuery.length < 1) {
            lastResults = []
            lastQuery = ""
            return []
        }

        // Проверяем что кеш готов
        if (!FileSearcher.cacheReady) {
            // Инициализируем кеш если еще не начали
            if (!cacheInitStarted) {
                console.log("FileProvider: Initializing cache for HOME")
                cacheInitStarted = true
                FileSearcher.initCache(Quickshell.env("HOME"))
            }
            return []
        }

        // Если это тот же запрос - возвращаем кешированные результаты
        // (такое бывает когда FileSearcher завершил поиск и мы триггерим пересчет)
        if (searchQuery === lastQuery && lastResults.length > 0) {
            return lastResults
        }

        // Отменяем предыдущий поиск если он был
        FileSearcher.cancel()

        // Запускаем новый асинхронный fuzzy search
        FileSearcher.search(searchQuery, 10)

        // Сохраняем текущий запрос и очищаем старые результаты
        lastQuery = searchQuery
        lastResults = []

        // Возвращаем пустой массив - результаты придут асинхронно
        return []
    }

    // Открытие файла/директории через xdg-open
    function openPath(filePath, isDirectory) {
        console.log("FileProvider: Opening", filePath, "isDirectory:", isDirectory)
        Quickshell.execDetached(["xdg-open", filePath])
    }

    // Обработчик результатов от C++ FileSearcher
    function handleResults(results) {
        // Конвертируем C++ результаты в формат провайдера
        let providerResults = []

        for (let i = 0; i < results.length; i++) {
            let result = results[i]

            // Замыкание для action чтобы сохранить значения
            let capturedPath = result.path
            let capturedIsDir = result.isDirectory

            providerResults.push({
                text: result.name,
                description: result.path,
                icon: result.icon,
                type: result.isDirectory ? "directory" : "file",
                score: result.score,  // C++ уже посчитал fuzzy score
                data: {
                    path: result.path,
                    isDirectory: result.isDirectory
                },
                action: function() {
                    openPath(capturedPath, capturedIsDir)
                }
            })
        }

        // Сохраняем результаты
        lastResults = providerResults

        // Триггерим пересчет результатов в LauncherService
        // Проверяем что query не изменился пока мы искали
        if (launcherService &&
            lastQuery === removePrefix(launcherService.searchQuery).trim()) {
            launcherService.search(launcherService.searchQuery)
        }
    }

    // Обработчик готовности кеша
    function handleCacheReady() {
        console.log("FileProvider: Cache is ready, triggering search")
        // Когда кеш готов - перезапускаем поиск если был запрос
        if (launcherService && launcherService.searchQuery.startsWith("?")) {
            launcherService.search(launcherService.searchQuery)
        }
    }

    // Инициализация - подключаем сигналы и получаем ссылку на LauncherService
    Component.onCompleted: {
        // Подключаем обработчик результатов
        FileSearcher.resultsReady.connect(handleResults)

        // Подключаем обработчик готовности кеша
        FileSearcher.cacheReadyChanged.connect(handleCacheReady)

        // LauncherService - это singleton, доступен глобально
        launcherService = LauncherService
    }

    Component.onDestruction: {
        // Отключаем обработчики при уничтожении
        FileSearcher.resultsReady.disconnect(handleResults)
        FileSearcher.cacheReadyChanged.disconnect(handleCacheReady)
    }
}
