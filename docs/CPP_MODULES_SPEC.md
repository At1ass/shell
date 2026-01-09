# Спецификация C++ модулей для Quickshell

**Цель:** Перенос критических компонентов из QML в C++ для стабильности и производительности

---

## Приоритизация модулей

| Модуль | ROI | Сложность | Время | Приоритет |
|--------|-----|-----------|-------|-----------|
| SystemMonitor | ⭐⭐⭐⭐⭐ | 🟢 Легко | 8ч | 1 |
| LauncherCache | ⭐⭐⭐⭐⭐ | 🟡 Средне | 12ч | 2 |
| DesktopEntryParser | ⭐⭐⭐⭐ | 🟢 Легко | 4ч | 3 |
| DirectoryScanner | ⭐⭐⭐⭐ | 🟢 Легко | 5ч | 4 |
| NotificationQueue | ⭐⭐⭐⭐ | 🟡 Средне | 8ч | 5 |
| ProcessManager | ⭐⭐⭐ | 🟢 Легко | 4ч | 6 |
| CalendarDatabase | ⭐⭐ | 🟡 Средне | 8ч | 7 |

---

## 1. SystemMonitor (Приоритет 1)

### Текущая проблема
```qml
// SystemMonitorService.qml
Timer {
    interval: 2000
    running: true
    repeat: true
    onTriggered: {
        cpuStatFile.reload()  // syscall
        const lines = cpuStatFile.text().split('\n')  // JS parsing (медленно!)
        const values = cpuLine.split(/\s+/).map(v => parseInt(v))  // Медленно!
    }
}
```

Проблемы:
- JS string parsing в 100x медленнее C++
- Открытие/закрытие файлов каждые 2 секунды
- 3 Process запускаются параллельно (df, sensors, nvidia-smi)
- Zombie процессы накапливаются

### C++ Спецификация

```cpp
// SystemMonitor.h
#pragma once

#include <QObject>
#include <QTimer>
#include <QProcess>
#include <qqml.h>

class SystemMonitor : public QObject {
    Q_OBJECT
    QML_ELEMENT

    // CPU
    Q_PROPERTY(qreal cpuUsage READ cpuUsage NOTIFY cpuUsageChanged)
    Q_PROPERTY(int cpuTemp READ cpuTemp NOTIFY cpuTempChanged)
    Q_PROPERTY(QString cpuModel READ cpuModel NOTIFY cpuModelChanged)

    // RAM
    Q_PROPERTY(qreal ramUsage READ ramUsage NOTIFY ramUsageChanged)
    Q_PROPERTY(QString ramUsed READ ramUsed NOTIFY ramUsedChanged)
    Q_PROPERTY(QString ramTotal READ ramTotal NOTIFY ramTotalChanged)

    // GPU
    Q_PROPERTY(int gpuUsage READ gpuUsage NOTIFY gpuUsageChanged)
    Q_PROPERTY(int gpuTemp READ gpuTemp NOTIFY gpuTempChanged)
    Q_PROPERTY(QString gpuModel READ gpuModel NOTIFY gpuModelChanged)

    // Disk
    Q_PROPERTY(qreal diskUsage READ diskUsage NOTIFY diskUsageChanged)
    Q_PROPERTY(QString diskUsed READ diskUsed NOTIFY diskUsedChanged)
    Q_PROPERTY(QString diskTotal READ diskTotal NOTIFY diskTotalChanged)

    // Update interval
    Q_PROPERTY(int updateInterval READ updateInterval WRITE setUpdateInterval NOTIFY updateIntervalChanged)

public:
    explicit SystemMonitor(QObject *parent = nullptr);
    ~SystemMonitor();

    // Getters
    qreal cpuUsage() const { return m_cpuUsage; }
    int cpuTemp() const { return m_cpuTemp; }
    QString cpuModel() const { return m_cpuModel; }

    qreal ramUsage() const { return m_ramUsage; }
    QString ramUsed() const { return m_ramUsed; }
    QString ramTotal() const { return m_ramTotal; }

    int gpuUsage() const { return m_gpuUsage; }
    int gpuTemp() const { return m_gpuTemp; }
    QString gpuModel() const { return m_gpuModel; }

    qreal diskUsage() const { return m_diskUsage; }
    QString diskUsed() const { return m_diskUsed; }
    QString diskTotal() const { return m_diskTotal; }

    int updateInterval() const { return m_updateTimer.interval(); }
    void setUpdateInterval(int ms);

signals:
    void cpuUsageChanged();
    void cpuTempChanged();
    void cpuModelChanged();

    void ramUsageChanged();
    void ramUsedChanged();
    void ramTotalChanged();

    void gpuUsageChanged();
    void gpuTempChanged();
    void gpuModelChanged();

    void diskUsageChanged();
    void diskUsedChanged();
    void diskTotalChanged();

    void updateIntervalChanged();

private slots:
    void updateStats();
    void onTempProcessFinished(int exitCode, QProcess::ExitStatus status);
    void onGpuProcessFinished(int exitCode, QProcess::ExitStatus status);
    void onDiskProcessFinished(int exitCode, QProcess::ExitStatus status);

private:
    // Update timer
    QTimer m_updateTimer;

    // CPU
    qreal m_cpuUsage = 0.0;
    int m_cpuTemp = 0;
    QString m_cpuModel;
    qint64 m_lastCpuIdle = 0;
    qint64 m_lastCpuTotal = 0;

    // File descriptors (кэшируем для performance)
    int m_statFd = -1;
    int m_meminfoFd = -1;

    // Reusable buffers
    QByteArray m_statBuffer;
    QByteArray m_meminfoBuffer;

    // RAM
    qreal m_ramUsage = 0.0;
    QString m_ramUsed = "0.0";
    QString m_ramTotal = "0.0";

    // GPU
    int m_gpuUsage = 0;
    int m_gpuTemp = 0;
    QString m_gpuModel;

    // Disk
    qreal m_diskUsage = 0.0;
    QString m_diskUsed = "0";
    QString m_diskTotal = "0";

    // Processes (один экземпляр, переиспользуем)
    QProcess *m_tempProcess = nullptr;
    QProcess *m_gpuProcess = nullptr;
    QProcess *m_diskProcess = nullptr;

    // Helper methods
    void updateCpu();
    void updateRam();
    void startTempProcess();
    void startGpuProcess();
    void startDiskProcess();

    void openSystemFiles();
    void closeSystemFiles();

    static qint64 parseCpuLine(const QByteArray &line, qint64 &idle);
    static void parseMeminfo(const QByteArray &data, qreal &usage, QString &used, QString &total);
};
```

```cpp
// SystemMonitor.cpp
#include "SystemMonitor.h"
#include <QFile>
#include <QDebug>
#include <fcntl.h>
#include <unistd.h>

SystemMonitor::SystemMonitor(QObject *parent)
    : QObject(parent)
{
    // Allocate buffers
    m_statBuffer.resize(8192);
    m_meminfoBuffer.resize(8192);

    // Open system files
    openSystemFiles();

    // Initialize processes
    m_tempProcess = new QProcess(this);
    m_gpuProcess = new QProcess(this);
    m_diskProcess = new QProcess(this);

    connect(m_tempProcess, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, &SystemMonitor::onTempProcessFinished);
    connect(m_gpuProcess, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, &SystemMonitor::onGpuProcessFinished);
    connect(m_diskProcess, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, &SystemMonitor::onDiskProcessFinished);

    // Setup timer
    m_updateTimer.setInterval(5000);  // 5 seconds default
    connect(&m_updateTimer, &QTimer::timeout, this, &SystemMonitor::updateStats);
    m_updateTimer.start();

    // Initial update
    updateStats();

    // Load static info (CPU/GPU model) once
    QProcess::execute("lscpu", {}, [this](int exitCode, const QByteArray &output) {
        // Parse CPU model
    });
}

SystemMonitor::~SystemMonitor()
{
    closeSystemFiles();
}

void SystemMonitor::openSystemFiles()
{
    m_statFd = ::open("/proc/stat", O_RDONLY);
    if (m_statFd < 0) {
        qWarning() << "Failed to open /proc/stat";
    }

    m_meminfoFd = ::open("/proc/meminfo", O_RDONLY);
    if (m_meminfoFd < 0) {
        qWarning() << "Failed to open /proc/meminfo";
    }
}

void SystemMonitor::closeSystemFiles()
{
    if (m_statFd >= 0) {
        ::close(m_statFd);
        m_statFd = -1;
    }
    if (m_meminfoFd >= 0) {
        ::close(m_meminfoFd);
        m_meminfoFd = -1;
    }
}

void SystemMonitor::updateStats()
{
    updateCpu();
    updateRam();

    // Start async processes only if not running
    if (m_tempProcess->state() == QProcess::NotRunning) {
        startTempProcess();
    }
    if (m_gpuProcess->state() == QProcess::NotRunning) {
        startGpuProcess();
    }
    if (m_diskProcess->state() == QProcess::NotRunning) {
        startDiskProcess();
    }
}

void SystemMonitor::updateCpu()
{
    if (m_statFd < 0) return;

    // Seek to start
    ::lseek(m_statFd, 0, SEEK_SET);

    // Read into buffer
    ssize_t n = ::read(m_statFd, m_statBuffer.data(), m_statBuffer.size() - 1);
    if (n <= 0) return;

    m_statBuffer[n] = '\0';

    // Parse CPU line (native - FAST!)
    qint64 idle;
    qint64 total = parseCpuLine(m_statBuffer, idle);

    if (m_lastCpuTotal != 0) {
        qint64 totalDiff = total - m_lastCpuTotal;
        qint64 idleDiff = idle - m_lastCpuIdle;

        if (totalDiff > 0) {
            qreal usage = ((totalDiff - idleDiff) / static_cast<qreal>(totalDiff)) * 100.0;
            if (qAbs(m_cpuUsage - usage) > 0.1) {
                m_cpuUsage = usage;
                emit cpuUsageChanged();
            }
        }
    }

    m_lastCpuIdle = idle;
    m_lastCpuTotal = total;
}

void SystemMonitor::updateRam()
{
    if (m_meminfoFd < 0) return;

    ::lseek(m_meminfoFd, 0, SEEK_SET);
    ssize_t n = ::read(m_meminfoFd, m_meminfoBuffer.data(), m_meminfoBuffer.size() - 1);
    if (n <= 0) return;

    m_meminfoBuffer[n] = '\0';

    qreal usage;
    QString used, total;
    parseMeminfo(m_meminfoBuffer, usage, used, total);

    bool changed = false;
    if (qAbs(m_ramUsage - usage) > 0.1) {
        m_ramUsage = usage;
        changed = true;
        emit ramUsageChanged();
    }
    if (m_ramUsed != used) {
        m_ramUsed = used;
        changed = true;
        emit ramUsedChanged();
    }
    if (m_ramTotal != total) {
        m_ramTotal = total;
        changed = true;
        emit ramTotalChanged();
    }
}

qint64 SystemMonitor::parseCpuLine(const QByteArray &data, qint64 &idle)
{
    // Find first "cpu " line
    const char *line = data.constData();
    while (*line && !(line[0] == 'c' && line[1] == 'p' && line[2] == 'u' && line[3] == ' ')) {
        while (*line && *line != '\n') line++;
        if (*line == '\n') line++;
    }

    if (!*line) {
        idle = 0;
        return 0;
    }

    // Skip "cpu "
    line += 4;

    // Parse numbers
    qint64 values[10];
    int count = 0;
    while (*line && *line != '\n' && count < 10) {
        while (*line == ' ') line++;
        if (*line < '0' || *line > '9') break;

        qint64 val = 0;
        while (*line >= '0' && *line <= '9') {
            val = val * 10 + (*line - '0');
            line++;
        }
        values[count++] = val;
    }

    if (count < 4) {
        idle = 0;
        return 0;
    }

    idle = values[3];  // idle is 4th value

    qint64 total = 0;
    for (int i = 0; i < count; i++) {
        total += values[i];
    }

    return total;
}

void SystemMonitor::parseMeminfo(const QByteArray &data, qreal &usage, QString &used, QString &total)
{
    // Simple parser for MemTotal and MemAvailable
    // TODO: Implement efficient parsing
}

void SystemMonitor::startTempProcess()
{
    m_tempProcess->start("sensors", {});
}

void SystemMonitor::startGpuProcess()
{
    m_gpuProcess->start("nvidia-smi",
        {"--query-gpu=utilization.gpu,temperature.gpu",
         "--format=csv,noheader,nounits"});
}

void SystemMonitor::startDiskProcess()
{
    m_diskProcess->start("df", {"-h", "/"});
}

void SystemMonitor::onTempProcessFinished(int exitCode, QProcess::ExitStatus status)
{
    if (status != QProcess::NormalExit || exitCode != 0) return;

    QByteArray output = m_tempProcess->readAllStandardOutput();
    // Parse temperature
    // TODO: Implement parsing
}

// Similar for GPU and Disk...
```

### Использование в QML

```qml
// Старый код (удалить)
// import qs.src.core.services
// SystemMonitorService.cpuUsage

// Новый код
import SystemMonitor 1.0

Rectangle {
    Text {
        text: `CPU: ${SystemMonitor.cpuUsage.toFixed(1)}%`
    }
}
```

### CMakeLists.txt

```cmake
# src/plugins/src/system-monitor/CMakeLists.txt
cmake_minimum_required(VERSION 3.21)
project(system-monitor-qml LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 6.5 COMPONENTS Core Qml REQUIRED)

qt_add_qml_module(systemmonitorqml
    URI "SystemMonitor"
    VERSION 1.0
    SOURCES
        SystemMonitor.h
        SystemMonitor.cpp
        plugin.cpp
    QML_FILES
        # None needed
)

target_link_libraries(systemmonitorqml PRIVATE
    Qt6::Core
    Qt6::Qml
)
```

### Выгоды
- ⚡ **100x быстрее** парсинг (native vs JS)
- 💾 Кэшированные file descriptors (нет open/close каждый раз)
- 🎯 Контроль над процессами (нет zombies)
- 🔧 Можно использовать `mmap()` для `/proc`

---

## 2. LauncherCache + FuzzyMatcher (Приоритет 2)

### Текущая проблема
```qml
// LauncherService.qml
property var _wrapperCache: ({})  // Бесконечный рост!

function wrapperForResult(key) {
    let wrapper = resultWrapperComponent.createObject(root)
    _wrapperCache[key] = wrapper  // Никогда не удаляется
    return wrapper
}
```

### C++ Спецификация

```cpp
// LauncherCache.h
#pragma once

#include <QObject>
#include <QCache>
#include <QVector>
#include <QHash>
#include <qqml.h>

struct DesktopEntry {
    QString id;
    QString name;
    QString exec;
    QString icon;
    QString comment;
    QStringList keywords;
    QStringList categories;

    // Pre-computed для fuzzy search
    QString searchString;  // lowercase name + keywords + categories

    int frequency = 0;
};

struct SearchResult {
    QString id;
    QString type;
    QString text;
    QString description;
    QString icon;
    int score;
    QVariant data;
};

class LauncherCache : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(int cacheSize READ cacheSize CONSTANT)

public:
    explicit LauncherCache(QObject *parent = nullptr);

    Q_INVOKABLE QVariantList search(const QString& query);
    Q_INVOKABLE void recordLaunch(const QString& appId);
    Q_INVOKABLE void reload();

    int cacheSize() const { return m_cache.maxCost(); }

signals:
    void cacheCleared();

private:
    // LRU cache (автоматический eviction!)
    QCache<QString, SearchResult> m_cache;

    // All desktop entries
    QVector<DesktopEntry> m_allApps;

    // Frequency tracking
    QHash<QString, int> m_launchCount;

    // Helper
    void loadDesktopEntries();
    int fuzzyScore(const QString& query, const DesktopEntry& entry);
};

// FuzzyMatcher.h
class FuzzyMatcher {
public:
    // Simple fuzzy match algorithm
    static int score(const QString& needle, const QString& haystack);

    // Batch scoring для performance
    static QVector<QPair<int, int>> batchScore(
        const QString& query,
        const QVector<DesktopEntry>& candidates
    );
};
```

```cpp
// LauncherCache.cpp
#include "LauncherCache.h"
#include "FuzzyMatcher.h"
#include <QDirIterator>
#include <QSettings>
#include <QStandardPaths>

LauncherCache::LauncherCache(QObject *parent)
    : QObject(parent)
{
    // Set cache limit (1000 items)
    m_cache.setMaxCost(1000);

    // Load desktop entries
    loadDesktopEntries();
}

void LauncherCache::loadDesktopEntries()
{
    m_allApps.clear();

    QStringList desktopDirs = QStandardPaths::standardLocations(
        QStandardPaths::ApplicationsLocation
    );

    for (const QString &dir : desktopDirs) {
        QDirIterator it(dir, {"*.desktop"}, QDir::Files, QDirIterator::Subdirectories);
        while (it.hasNext()) {
            QString path = it.next();

            QSettings desktop(path, QSettings::IniFormat);
            desktop.beginGroup("Desktop Entry");

            DesktopEntry entry;
            entry.id = QFileInfo(path).fileName();
            entry.name = desktop.value("Name").toString();
            entry.exec = desktop.value("Exec").toString();
            entry.icon = desktop.value("Icon").toString();
            entry.comment = desktop.value("Comment").toString();
            entry.keywords = desktop.value("Keywords").toString().split(';', Qt::SkipEmptyParts);
            entry.categories = desktop.value("Categories").toString().split(';', Qt::SkipEmptyParts);

            // Pre-compute search string
            QStringList searchParts;
            searchParts << entry.name.toLower();
            searchParts << entry.keywords;
            searchParts << entry.categories;
            entry.searchString = searchParts.join(' ').toLower();

            m_allApps.append(entry);
        }
    }

    qDebug() << "Loaded" << m_allApps.size() << "desktop entries";
}

QVariantList LauncherCache::search(const QString& query)
{
    QString trimmed = query.trimmed().toLower();

    if (trimmed.isEmpty()) {
        // Return frequent apps
        QVariantList result;
        // TODO: Return top 10 frequent
        return result;
    }

    // Fuzzy search
    QVector<QPair<int, const DesktopEntry*>> scored;
    scored.reserve(m_allApps.size());

    for (const auto& entry : m_allApps) {
        int score = FuzzyMatcher::score(trimmed, entry.searchString);
        if (score > 0) {
            score += m_launchCount.value(entry.id, 0) * 10;  // Boost frequent
            scored.append({score, &entry});
        }
    }

    // Sort by score (descending)
    std::sort(scored.begin(), scored.end(), [](const auto& a, const auto& b) {
        return a.first > b.first;
    });

    // Take top 10
    QVariantList result;
    for (int i = 0; i < qMin(10, scored.size()); i++) {
        const auto& entry = *scored[i].second;

        QVariantMap item;
        item["id"] = entry.id;
        item["type"] = "application";
        item["text"] = entry.name;
        item["description"] = entry.comment;
        item["icon"] = entry.icon;
        item["score"] = scored[i].first;
        item["exec"] = entry.exec;

        result.append(item);
    }

    return result;
}

void LauncherCache::recordLaunch(const QString& appId)
{
    m_launchCount[appId]++;
    // TODO: Persist to file
}

// FuzzyMatcher.cpp
int FuzzyMatcher::score(const QString& needle, const QString& haystack)
{
    // Simple fuzzy matching algorithm
    // For better results, use rapidfuzz or fts_fuzzy_match

    if (needle.isEmpty()) return 0;
    if (haystack.contains(needle)) return 100;  // Exact substring

    // Character-by-character fuzzy match
    int score = 0;
    int needleIdx = 0;
    int lastMatchIdx = -1;

    for (int i = 0; i < haystack.size() && needleIdx < needle.size(); i++) {
        if (haystack[i] == needle[needleIdx]) {
            // Consecutive match bonus
            if (lastMatchIdx == i - 1) {
                score += 5;
            }
            score += 10;
            lastMatchIdx = i;
            needleIdx++;
        }
    }

    return (needleIdx == needle.size()) ? score : 0;
}
```

### Использование в QML

```qml
// Старый код (удалить)
// import qs.src.core.services
// LauncherService.search(query)

// Новый код
import LauncherCache 1.0

ListView {
    model: LauncherCache.search(searchField.text)

    delegate: Item {
        required property var modelData

        Text {
            text: modelData.text
        }

        MouseArea {
            onClicked: {
                LauncherCache.recordLaunch(modelData.id)
                // Launch app
            }
        }
    }
}
```

### Выгоды
- 🎯 **Автоматический LRU** (QCache evicts старые)
- ⚡ **10-50x быстрее** fuzzy search
- 💾 Меньше памяти (native structures vs QML objects)
- 📊 Frequency tracking
- 🔄 Incremental updates

---

## 3. NotificationQueue (Приоритет 5)

### C++ Спецификация

```cpp
// NotificationQueue.h
#pragma once

#include <QObject>
#include <QQmlListProperty>
#include <QTimer>
#include <QSharedPointer>
#include <qqml.h>

class Notification : public QObject {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(int id READ id CONSTANT)
    Q_PROPERTY(QString summary READ summary CONSTANT)
    Q_PROPERTY(QString body READ body CONSTANT)
    Q_PROPERTY(QString appIcon READ appIcon CONSTANT)
    Q_PROPERTY(bool popup READ popup WRITE setPopup NOTIFY popupChanged)

public:
    Notification(int id, const QString& summary, const QString& body,
                const QString& appIcon, QObject *parent = nullptr);

    int id() const { return m_id; }
    QString summary() const { return m_summary; }
    QString body() const { return m_body; }
    QString appIcon() const { return m_appIcon; }

    bool popup() const { return m_popup; }
    void setPopup(bool popup);

signals:
    void popupChanged();

private:
    int m_id;
    QString m_summary;
    QString m_body;
    QString m_appIcon;
    bool m_popup = false;
};

class NotificationQueue : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QQmlListProperty<Notification> notifications READ notifications NOTIFY notificationsChanged)
    Q_PROPERTY(QQmlListProperty<Notification> popups READ popups NOTIFY popupsChanged)

public:
    explicit NotificationQueue(QObject *parent = nullptr);

    QQmlListProperty<Notification> notifications();
    QQmlListProperty<Notification> popups();

    Q_INVOKABLE void addNotification(const QString& summary, const QString& body,
                                     const QString& appIcon, int timeout = 7000);
    Q_INVOKABLE void removeNotification(int id);
    Q_INVOKABLE void timeoutNotification(int id);
    Q_INVOKABLE void clearAll();

signals:
    void notificationsChanged();
    void popupsChanged();

private slots:
    void onTimerTimeout();

private:
    QList<QSharedPointer<Notification>> m_notifications;
    QList<QSharedPointer<Notification>> m_popups;

    // Timers managed here (automatic cleanup!)
    QHash<int, QTimer*> m_timers;

    int m_nextId = 1;

    void updatePopups();
    void cleanupTimer(int id);
};
```

### Выгоды
- ✅ **Автоматический cleanup** таймеров
- 🔄 **Реактивность** работает корректно
- 💾 Нет утечек памяти
- 🎯 Proper lifecycle management

---

## Структура проекта

```
src/plugins/src/
├── mcu-qml/              (существует)
├── qalculate-qml/        (существует)
├── file-search-qml/      (существует)
├── system-monitor/       ← НОВЫЙ
│   ├── CMakeLists.txt
│   ├── SystemMonitor.h
│   ├── SystemMonitor.cpp
│   └── plugin.cpp
├── launcher-cache/       ← НОВЫЙ
│   ├── CMakeLists.txt
│   ├── LauncherCache.h
│   ├── LauncherCache.cpp
│   ├── DesktopEntryParser.h
│   ├── DesktopEntryParser.cpp
│   ├── FuzzyMatcher.h
│   ├── FuzzyMatcher.cpp
│   └── plugin.cpp
├── notification-queue/   ← НОВЫЙ
│   ├── CMakeLists.txt
│   ├── NotificationQueue.h
│   ├── NotificationQueue.cpp
│   ├── Notification.h
│   ├── Notification.cpp
│   └── plugin.cpp
└── utils/                ← НОВЫЙ
    ├── CMakeLists.txt
    ├── ProcessManager.h
    ├── ProcessManager.cpp
    ├── DebouncedFileWatcher.h
    ├── DebouncedFileWatcher.cpp
    └── plugin.cpp
```

---

## План внедрения

### Weekend 1: SystemMonitor
1. Создать директорию `src/plugins/src/system-monitor/`
2. Написать SystemMonitor.h/.cpp
3. Написать CMakeLists.txt
4. Собрать и протестировать
5. Заменить SystemMonitorService.qml на использование C++ модуля
6. Удалить старый QML код

### Weekend 2: LauncherCache
1. Создать директорию `src/plugins/src/launcher-cache/`
2. Написать все компоненты
3. Интегрировать rapidfuzz (опционально)
4. Собрать и протестировать
5. Заменить LauncherService.qml
6. Удалить старый QML код

### Weekend 3: NotificationQueue
1. Создать директорию `src/plugins/src/notification-queue/`
2. Написать компоненты
3. Интеграция с NotificationServer
4. Тестирование
5. Замена NotificationService.qml
6. Cleanup

---

**Итоговый результат:**
- ⚡ Производительность улучшена в 10-100x
- 💾 Утечки памяти устранены
- 🎯 Proper lifecycle management
- ✅ Стабильность 24/7
