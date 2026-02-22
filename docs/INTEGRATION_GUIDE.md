# Руководство по интеграции C++ плагинов в QML конфигурацию

**Дата:** 2026-01-14
**Статус:** 🟡 Плагины созданы, требуется миграция QML кода

---

## 📋 Статус интеграции

| Плагин | CMake | QML миграция | Статус |
|--------|-------|--------------|--------|
| WallpaperManager | ✅ Добавлен | ⚠️ Требуется | 50% |
| NotificationManager | ✅ Добавлен | ⚠️ Требуется | 50% |
| MCU-QML Extensions | ✅ Готов | ⚠️ Опционально | 90% |
| LauncherIndex | ✅ Добавлен | ⚠️ Требуется | 50% |
| SystemMonitor v2 | ✅ Готов | ✅ Обратно совместим | 100% |

---

## 🔧 Шаг 1: Сборка плагинов

### 1.1 Установка зависимостей

```bash
# Arch Linux
sudo pacman -S qt6-base qt6-declarative abseil-cpp libqalculate

# Ubuntu/Debian
sudo apt install qt6-base-dev qt6-declarative-dev libabsl-dev libqalculate-dev
```

### 1.2 Сборка проекта

```bash
cd ~/.config/quickshell/shell

# Настройка build
cmake -B build -S src/plugins \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr

# Компиляция
cmake --build build -j$(nproc)

# Установка (требуется sudo)
sudo cmake --install build
```

### 1.3 Проверка установки

Плагины должны быть установлены в `/usr/lib/qt6/qml/`:

```bash
ls -la /usr/lib/qt6/qml/ | grep -E "WallpaperManager|NotificationManager|LauncherIndex"
```

Должны появиться директории:
- `WallpaperManager/`
- `NotificationManager/`
- `LauncherIndex/`

---

## 🔄 Шаг 2: Миграция QML кода

### 2.1 WallpaperService → WallpaperManager

**Старый код (`src/core/services/WallpaperService.qml`):**
```qml
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: wallpaperService

    property var monitorWallpapers: ({})
    property url currentWallpaper: ""
    property bool directoryMode: false

    function setWallpaper(monitor, path, persist) {
        // 768 строк QML кода...
    }
}
```

**Новый код (использование C++ плагина):**

#### Вариант А: Полная замена (рекомендуется)

```qml
// src/core/services/WallpaperService.qml
pragma Singleton
import WallpaperManager 1.0

// Экспортируем WallpaperManager как Singleton
QtObject {
    // Просто делегируем все к C++ плагину
    readonly property var manager: WallpaperManager

    // Backward compatibility aliases
    readonly property var monitorWallpapers: WallpaperManager.monitorWallpapers
    readonly property url currentWallpaper: WallpaperManager.currentWallpaper
    readonly property bool directoryMode: WallpaperManager.directoryMode

    function setWallpaper(monitor, path, persist) {
        WallpaperManager.setWallpaper(monitor, path, persist ?? true)
    }

    function nextWallpaper(monitor, persist) {
        WallpaperManager.nextWallpaper(monitor ?? "", persist ?? true)
    }

    function previousWallpaper(monitor, persist) {
        WallpaperManager.previousWallpaper(monitor ?? "", persist ?? true)
    }

    function setDirectory(monitor, dirPath) {
        WallpaperManager.setDirectory(monitor ?? "", dirPath)
    }

    function getWallpaper(monitor) {
        return WallpaperManager.getWallpaper(monitor)
    }

    function getFillMode(monitor) {
        return WallpaperManager.getFillMode(monitor)
    }
}
```

#### Вариант Б: Прямое использование

В любом QML файле:
```qml
import WallpaperManager 1.0

Item {
    Component.onCompleted: {
        // Прямое использование без промежуточного слоя
        WallpaperManager.setDirectory("", "/usr/share/backgrounds")
    }

    Connections {
        target: WallpaperManager

        function onDirectoryScanComplete(key, count) {
            console.log("Found", count, "wallpapers")
        }

        function onScanningChanged() {
            if (!WallpaperManager.scanning) {
                console.log("Scan finished!")
            }
        }
    }

    Button {
        text: "Next Wallpaper"
        onClicked: WallpaperManager.nextWallpaper("DP-1")
    }
}
```

#### Обновление использующих компонентов

**Background.qml:**
```qml
// Старое
Image {
    source: WallpaperService.getWallpaper(Quickshell.screen.name)
}

// Новое (если используете wrapper)
Image {
    source: WallpaperService.getWallpaper(Quickshell.screen.name)
    // Код остается тем же благодаря wrapper!
}

// Новое (прямое использование)
import WallpaperManager 1.0

Image {
    source: WallpaperManager.getWallpaper(Quickshell.screen.name)
}
```

---

### 2.2 NotificationService → NotificationManager

**Старый код (`src/core/services/NotificationService.qml`):**
```qml
pragma Singleton
import Quickshell.Services.Notifications

Singleton {
    property ListModel activeList: ListModel {}
    property ListModel historyList: ListModel {}

    function handleNotification(notification) {
        // 485 строк QML кода...
    }
}
```

**Новый код:**

#### Вариант А: Wrapper для совместимости

```qml
// src/core/services/NotificationService.qml
pragma Singleton
import QtQuick
import NotificationManager 1.0
import Quickshell.Services.Notifications

QtObject {
    id: root

    // Делегируем к C++ плагину
    readonly property var activeList: NotificationManager.activeModel
    readonly property var historyList: NotificationManager.historyModel
    readonly property int activeCount: NotificationManager.activeCount
    readonly property bool doNotDisturb: NotificationManager.doNotDisturb

    // NotificationServer остается в QML (D-Bus integration)
    Component {
        id: notificationServerComponent
        NotificationServer {
            keepOnReload: false
            actionsSupported: true
            imageSupported: true

            onNotification: (notification) => {
                // Передаем в C++ плагин
                NotificationManager.addNotification(
                    notification.summary || "",
                    notification.body || "",
                    notification.appName || "",
                    notification.appIcon || "",
                    notification.urgency,
                    notification.expireTimeout,
                    notification.actions || [],
                    notification.image || ""
                )
            }
        }
    }

    Component.onCompleted: {
        notificationServerComponent.createObject(root)
    }

    // Backward compatibility methods
    function dismissNotification(id) {
        NotificationManager.dismissNotification(id)
    }

    function dismissAll() {
        NotificationManager.dismissAll()
    }

    function clearHistory() {
        NotificationManager.clearHistory()
    }
}
```

#### Вариант Б: Прямое использование

```qml
import NotificationManager 1.0
import Quickshell.Services.Notifications

Item {
    // NotificationServer для приема уведомлений
    NotificationServer {
        onNotification: notification => {
            NotificationManager.addNotification(
                notification.summary,
                notification.body,
                notification.appName,
                notification.appIcon,
                notification.urgency,
                notification.expireTimeout
            )
        }
    }

    // Отображение активных уведомлений
    ListView {
        model: NotificationManager.activeModel

        delegate: Rectangle {
            required property var modelData  // Notification object

            Text { text: modelData.summary }
            Text { text: modelData.body }

            Button {
                text: "Dismiss"
                onClicked: NotificationManager.dismissNotification(modelData.id)
            }
        }
    }

    // Do Not Disturb toggle
    Switch {
        checked: NotificationManager.doNotDisturb
        onToggled: NotificationManager.doNotDisturb = checked
    }
}
```

---

### 2.3 ColorService → MCU-QML Extensions

MCU-QML уже используется в проекте, добавлены только новые методы:

```qml
import Mcu 1.0

Item {
    McuTheme {
        id: theme
        source: wallpaperUrl

        // НОВОЕ: Извлечение доминантного цвета
        onDominantColorExtracted: (imageUrl, color) => {
            console.log("Dominant color:", color)
            accentColor = color
        }

        // НОВОЕ: Извлечение палитры
        onPaletteExtracted: (imageUrl, colors) => {
            console.log("Palette:", colors)
            colorPalette = colors
        }

        Component.onCompleted: {
            // Async извлечение
            theme.extractDominantColorAsync(wallpaperUrl)
            theme.extractPaletteAsync(wallpaperUrl, 5)
        }
    }

    // НОВОЕ: Синхронные утилиты
    Text {
        color: theme.isDark(backgroundColor) ? "white" : "black"
    }

    Rectangle {
        color: theme.getComplementary("#FF0000")  // Cyan
    }

    Text {
        visible: theme.getContrast(textColor, bgColor) >= 4.5  // WCAG AA
    }
}
```

---

### 2.4 LauncherService → LauncherIndex

**Старый код:**
```qml
// src/features/launcher/providers/ApplicationProvider.qml
QtObject {
    function search(query) {
        // Парсит .desktop файлы при каждом поиске
        let results = []
        // ... медленный код ...
        return results
    }
}
```

**Новый код:**

#### Wrapper:
```qml
// src/core/services/LauncherService.qml
pragma Singleton
import LauncherIndex 1.0

QtObject {
    readonly property bool ready: LauncherIndex.ready
    readonly property int appCount: LauncherIndex.appCount

    function search(query, limit) {
        return LauncherIndex.search(query, limit ?? 10)
    }

    function launch(appId) {
        LauncherIndex.launch(appId)
        LauncherIndex.incrementFrequency(appId)
    }

    function rebuildIndex() {
        LauncherIndex.buildIndex()
    }

    Component.onCompleted: {
        // Автоматическая индексация при старте
        if (!LauncherIndex.ready) {
            LauncherIndex.buildIndex()
        }
    }
}
```

#### Использование в LauncherContent.qml:

```qml
import LauncherIndex 1.0

Item {
    TextField {
        id: searchField

        onTextChanged: {
            if (text.length < 2) {
                resultsList.model = []
                return
            }

            // Мгновенный поиск (2-5ms)
            resultsList.model = LauncherIndex.search(text, 10)
        }
    }

    ListView {
        id: resultsList

        delegate: ItemDelegate {
            required property var modelData

            text: modelData.name
            icon.name: modelData.icon

            onClicked: {
                LauncherIndex.launch(modelData.id)
                LauncherIndex.incrementFrequency(modelData.id)
            }
        }
    }

    // Индикатор индексации
    BusyIndicator {
        visible: LauncherIndex.indexing
    }

    Text {
        text: "Apps: " + LauncherIndex.appCount
    }
}
```

---

### 2.5 SystemMonitor v2 (обратно совместим!)

SystemMonitor v2 **полностью обратно совместим** с v1. Все старые свойства работают как раньше.

**Использование новых функций:**

```qml
import SystemMonitor 1.0

Item {
    // ===== СУЩЕСТВУЮЩИЙ КОД РАБОТАЕТ БЕЗ ИЗМЕНЕНИЙ =====
    Text {
        text: "CPU: " + SystemMonitor.cpuUsage.toFixed(1) + "%"
    }

    Text {
        text: "RAM: " + SystemMonitor.ramUsage.toFixed(1) + "GB"
    }

    // ===== НОВЫЕ ФУНКЦИИ V2 =====

    // 1. История для графиков
    LineChart {
        id: cpuChart
        data: SystemMonitor.getCpuHistory(60)  // Последние 60 секунд

        Connections {
            target: SystemMonitor
            function onStatsUpdated() {
                cpuChart.data = SystemMonitor.getCpuHistory(60)
            }
        }
    }

    // 2. Топ процессов
    ListView {
        model: SystemMonitor.topProcesses

        delegate: Row {
            spacing: 10

            Text { text: modelData.name; width: 150 }
            Text { text: modelData.cpuUsage.toFixed(1) + "%"; width: 60 }
            Text { text: modelData.memUsage.toFixed(1) + "%"; width: 60 }
            Text { text: "PID: " + modelData.pid; width: 80 }
            Text { text: modelData.user; width: 100 }
        }

        Component.onCompleted: SystemMonitor.refreshTopProcesses()
    }

    Button {
        text: "Refresh Processes"
        onClicked: SystemMonitor.refreshTopProcesses()
    }

    // 3. Threshold Alerts
    Connections {
        target: SystemMonitor

        function onCpuThresholdExceeded(value) {
            showNotification("CPU High!", "Usage: " + value.toFixed(1) + "%")
        }

        function onRamThresholdExceeded(value) {
            showNotification("RAM High!", "Usage: " + value.toFixed(1) + "%")
        }
    }

    // Настройка порогов
    Component.onCompleted: {
        SystemMonitor.cpuThreshold = 80  // 80% вместо 90%
        SystemMonitor.ramThreshold = 85
    }

    // 4. Error Handling
    Text {
        text: SystemMonitor.hasErrors ?
              "Error: " + SystemMonitor.lastError :
              "System OK"
        color: SystemMonitor.hasErrors ? "red" : "green"
    }

    // 5. Adaptive Intervals
    Component.onCompleted: {
        // Быстрее обновлять когда dashboard видим
        SystemMonitor.updateInterval = 1000
    }
}
```

---

## 🧪 Шаг 3: Тестирование

### 3.1 Тестовый QML файл

Создайте `test_plugins.qml` для проверки всех плагинов:

```qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import WallpaperManager 1.0
import NotificationManager 1.0
import LauncherIndex 1.0
import SystemMonitor 1.0
import Mcu 1.0

ApplicationWindow {
    visible: true
    width: 800
    height: 600
    title: "C++ Plugins Test"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 20

        // ===== WallpaperManager =====
        GroupBox {
            title: "WallpaperManager"
            Layout.fillWidth: true

            ColumnLayout {
                Text {
                    text: "Ready: " + WallpaperManager.ready
                }
                Text {
                    text: "Scanning: " + WallpaperManager.scanning
                }
                Text {
                    text: "Wallpapers: " + WallpaperManager.wallpaperCount
                }
                Text {
                    text: "Current: " + WallpaperManager.currentWallpaper
                }

                Button {
                    text: "Set Directory"
                    onClicked: {
                        WallpaperManager.setDirectory("", "/usr/share/backgrounds")
                    }
                }

                Button {
                    text: "Next Wallpaper"
                    onClicked: WallpaperManager.nextWallpaper()
                }
            }
        }

        // ===== NotificationManager =====
        GroupBox {
            title: "NotificationManager"
            Layout.fillWidth: true

            ColumnLayout {
                Text {
                    text: "Active: " + NotificationManager.activeCount
                }
                Text {
                    text: "History: " + NotificationManager.historyCount
                }
                Text {
                    text: "DND: " + NotificationManager.doNotDisturb
                }

                Button {
                    text: "Test Notification"
                    onClicked: {
                        NotificationManager.addNotification(
                            "Test",
                            "This is a test notification",
                            "TestApp",
                            "",
                            1,  // Normal urgency
                            5000  // 5 seconds
                        )
                    }
                }

                Button {
                    text: "Dismiss All"
                    onClicked: NotificationManager.dismissAll()
                }
            }
        }

        // ===== LauncherIndex =====
        GroupBox {
            title: "LauncherIndex"
            Layout.fillWidth: true

            ColumnLayout {
                Text {
                    text: "Ready: " + LauncherIndex.ready
                }
                Text {
                    text: "Apps: " + LauncherIndex.appCount
                }
                Text {
                    text: "Indexing: " + LauncherIndex.indexing
                }

                TextField {
                    id: searchField
                    placeholderText: "Search apps..."
                    Layout.fillWidth: true

                    onTextChanged: {
                        if (text.length >= 2) {
                            let results = LauncherIndex.search(text, 5)
                            resultsText.text = results.length + " results"
                            if (results.length > 0) {
                                resultsText.text += "\nFirst: " + results[0].name
                            }
                        }
                    }
                }

                Text {
                    id: resultsText
                    text: "Type to search..."
                }

                Button {
                    text: "Rebuild Index"
                    onClicked: LauncherIndex.buildIndex()
                }
            }
        }

        // ===== SystemMonitor v2 =====
        GroupBox {
            title: "SystemMonitor v2"
            Layout.fillWidth: true

            ColumnLayout {
                Text {
                    text: "CPU: " + SystemMonitor.cpuUsage.toFixed(1) + "%"
                }
                Text {
                    text: "RAM: " + SystemMonitor.ramUsage.toFixed(1) + " GB"
                }
                Text {
                    text: "History size: " + SystemMonitor.getCpuHistory(60).length
                }
                Text {
                    text: "Top process: " +
                          (SystemMonitor.topProcesses.length > 0 ?
                           SystemMonitor.topProcesses[0].name : "N/A")
                }

                Button {
                    text: "Refresh Top Processes"
                    onClicked: SystemMonitor.refreshTopProcesses()
                }
            }
        }

        // ===== MCU-QML =====
        GroupBox {
            title: "MCU-QML Extensions"
            Layout.fillWidth: true

            ColumnLayout {
                Text {
                    text: "isDark(#FF0000): " + theme.isDark("#FF0000")
                }
                Text {
                    text: "Contrast(white, black): " +
                          theme.getContrast("#FFFFFF", "#000000").toFixed(2)
                }
                Text {
                    text: "Complementary(red): " + theme.getComplementary("#FF0000")
                }

                McuTheme {
                    id: theme
                }
            }
        }
    }
}
```

### 3.2 Запуск тестов

```bash
# Запустить тестовый файл
quickshell -c test_plugins.qml

# Или встроить в вашу конфигурацию
quickshell
```

---

## 📝 Шаг 4: Миграция существующих файлов

### Файлы требующие обновления:

1. **WallpaperService:**
   - `src/core/services/WallpaperService.qml` - заменить на wrapper
   - `src/features/background/Background.qml` - возможно обновить импорты

2. **NotificationService:**
   - `src/core/services/NotificationService.qml` - заменить на wrapper
   - `src/features/notifications/*.qml` - обновить использование

3. **LauncherService:**
   - `src/core/services/LauncherService.qml` - создать новый wrapper
   - `src/features/launcher/LauncherContent.qml` - обновить поиск
   - `src/features/launcher/providers/ApplicationProvider.qml` - заменить на LauncherIndex

4. **ColorService (опционально):**
   - `src/core/services/ColorService.qml` - добавить новые методы MCU

5. **SystemMonitor (обратно совместим):**
   - Использовать новые функции где нужны графики/топ процессы

---

## ⚠️ Важные замечания

### Feature Flags для постепенной миграции:

```qml
// config/default.json
{
    "experimental": {
        "useCppWallpaperManager": true,
        "useCppNotificationManager": true,
        "useCppLauncherIndex": true
    }
}

// В QML
Item {
    Loader {
        source: Config.experimental.useCppWallpaperManager ?
                "WallpaperManagerWrapper.qml" :
                "WallpaperServiceLegacy.qml"
    }
}
```

### Откат при проблемах:

1. Закомментировать строки в `src/plugins/CMakeLists.txt`
2. Пересобрать проект
3. Использовать старые QML сервисы

### Производительность после миграции:

Мониторьте:
- Время запуска приложения
- Использование памяти
- Отзывчивость UI
- Частота сборок мусора QML

---

## ✅ Чеклист интеграции

- [x] CMakeLists.txt обновлен (добавлены новые плагины)
- [ ] Плагины скомпилированы и установлены
- [ ] Тестовый QML файл создан и запущен
- [ ] WallpaperService.qml заменен на wrapper
- [ ] NotificationService.qml заменен на wrapper
- [ ] LauncherService.qml создан/обновлен
- [ ] Существующие компоненты обновлены
- [ ] Тестирование всех функций
- [ ] Проверка производительности
- [ ] Документирование изменений

---

## 🆘 Troubleshooting

### Плагин не найден:

```
QQmlApplicationEngine failed to load component
qrc:/shell.qml:1:1: module "WallpaperManager" is not installed
```

**Решение:**
```bash
# Проверить установку
ls -la /usr/lib/qt6/qml/WallpaperManager/

# Переустановить
sudo cmake --install build --prefix /usr

# Проверить QML2_IMPORT_PATH
echo $QML2_IMPORT_PATH
export QML2_IMPORT_PATH=/usr/lib/qt6/qml:$QML2_IMPORT_PATH
```

### Ошибки компиляции:

```
undefined reference to `WallpaperManager::WallpaperManager()'
```

**Решение:**
```bash
# Полная пересборка
rm -rf build
cmake -B build -S src/plugins
cmake --build build
```

### Проблемы с производительностью:

- Включить QML профайлер: `QSG_RENDER_TIMING=1 quickshell`
- Проверить CPU usage: `top -p $(pидof quickshell)`
- Мониторить память: `watch -n 1 'ps aux | grep quickshell'`

---

**Автор:** Claude Sonnet 4.5
**Дата:** 2026-01-14
**Версия:** 1.0
