# План миграции QML → C++ по приоритетам

**Дата анализа:** 2026-01-14
**Объем проекта:** ~16,500 строк QML + 3 C++ плагина
**Текущие плагины:** MCU-QML, Qalculate-QML, System-Monitor-QML

---

## 🎯 Критерии приоритизации

1. **Влияние на производительность** - блокировка UI, частота вызовов
2. **Влияние на стабильность** - риски утечек памяти, race conditions
3. **Сложность реализации** - время разработки, зависимости
4. **Текущие проблемы** - баги, жалобы пользователей
5. **Переиспользование кода** - синергия с существующими плагинами

---

## 🔴 КРИТИЧЕСКИЙ ПРИОРИТЕТ

### 1. WallpaperService → WallpaperManager C++ Plugin
**Файл:** `src/core/services/WallpaperService.qml` (768 строк)

**Проблемы:**
- ❌ **Блокирует UI** при сканировании директорий с обоями
- ❌ Синхронное чтение файловой системы
- ❌ Синхронное сохранение JSON конфигурации
- ❌ Потенциальный freeze при 1000+ файлов
- ❌ Использует Process + StdioCollector (fork overhead)

**Решение:**
```cpp
class WallpaperManager : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QStringList wallpapers READ wallpapers NOTIFY wallpapersChanged)
    Q_PROPERTY(bool scanning READ scanning NOTIFY scanningChanged)
    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    Q_INVOKABLE void scanDirectories(const QStringList& dirs);
    Q_INVOKABLE void setWallpaper(const QString& monitor, const QString& path);
    Q_INVOKABLE void nextWallpaper(const QString& monitor);
    Q_INVOKABLE void previousWallpaper(const QString& monitor);
    Q_INVOKABLE void randomWallpaper(const QString& monitor);

signals:
    void wallpapersChanged();
    void scanningChanged();
    void scanComplete(int count);
    void error(const QString& message);

private:
    QThread* m_workerThread;
    QHash<QString, QStringList> m_wallpapersByDir;
    QHash<QString, QString> m_currentWallpapers;
    QFileSystemWatcher m_watcher;

    void scanDirectoryAsync(const QString& dir);
    void saveConfigAsync();
};
```

**Преимущества:**
- ✅ Асинхронное сканирование в worker thread
- ✅ QFileSystemWatcher для автообновления при добавлении файлов
- ✅ Кэширование списка в памяти (QHash)
- ✅ Debounced JSON saving (не сохранять при каждом изменении)
- ✅ Прямая работа с QDir (без Process fork)
- ✅ Поддержка фильтрации по расширениям на уровне C++

**Оценка:**
- **Влияние:** 🔥🔥🔥🔥🔥 (критично для UX)
- **Сложность:** ⭐⭐⭐ (средняя)
- **Время:** 3-4 дня
- **Прирост:** Устранение блокировок UI, ~500ms → 0ms

---

### 2. NotificationService → NotificationManager C++ Plugin
**Файл:** `src/core/services/NotificationService.qml` (485 строк)

**Проблемы:**
- ❌ **O(n) линейный поиск** дубликатов уведомлений
- ❌ Синхронное сохранение истории в JSON при каждом изменении
- ❌ Множественные таймеры в QML (управление lifecycle сложное)
- ❌ Потенциальные утечки памяти при большой истории
- ❌ Нет батчинга обновлений

**Решение:**
```cpp
class NotificationManager : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QList<Notification*> active READ active NOTIFY activeChanged)
    Q_PROPERTY(QList<Notification*> history READ history NOTIFY historyChanged)
    Q_PROPERTY(int activeCount READ activeCount NOTIFY activeCountChanged)
    Q_PROPERTY(bool doNotDisturb READ doNotDisturb WRITE setDoNotDisturb
               NOTIFY doNotDisturbChanged)

public:
    Q_INVOKABLE void addNotification(const QString& appName,
                                     const QString& summary,
                                     const QString& body,
                                     const QString& icon,
                                     int timeout = 5000);
    Q_INVOKABLE void dismissNotification(uint id);
    Q_INVOKABLE void dismissAll();
    Q_INVOKABLE void clearHistory();

signals:
    void activeChanged();
    void historyChanged();
    void notificationAdded(Notification* notification);
    void notificationDismissed(uint id);

private:
    QHash<uint, Notification*> m_activeNotifications;  // O(1) lookup
    QList<Notification*> m_history;
    QHash<QString, uint> m_appNotificationMap;  // Track duplicates O(1)
    QTimer m_saveTimer;  // Debounced save (5 seconds)

    void saveHistoryAsync();
    void loadHistory();
    void scheduleExpiry(Notification* notification);
};

class Notification : public QObject {
    Q_OBJECT
    Q_PROPERTY(uint id READ id CONSTANT)
    Q_PROPERTY(QString appName READ appName CONSTANT)
    Q_PROPERTY(QString summary READ summary CONSTANT)
    Q_PROPERTY(QString body READ body CONSTANT)
    Q_PROPERTY(QDateTime timestamp READ timestamp CONSTANT)
    Q_PROPERTY(bool dismissed READ dismissed WRITE setDismissed NOTIFY dismissedChanged)

    QTimer* m_expiryTimer = nullptr;
};
```

**Преимущества:**
- ✅ O(1) поиск вместо O(n) через QHash
- ✅ Debounced saving (не сохранять при каждом уведомлении)
- ✅ Централизованное управление таймерами в C++
- ✅ Лимит истории с автоочисткой старых
- ✅ Batch updates через dataChanged signals
- ✅ Интеграция с NotificationServer напрямую

**Оценка:**
- **Влияние:** 🔥🔥🔥🔥🔥 (критично для производительности)
- **Сложность:** ⭐⭐⭐ (средняя)
- **Время:** 4-5 дней
- **Прирост:** 10-100x на поиске, устранение блокировок I/O

---

### 3. Расширение MCU-QML для ColorService/WallpaperAnalyzer
**Файлы:**
- `src/core/services/ColorService.qml`
- `src/core/services/WallpaperAnalyzer.qml`

**Проблемы:**
- ❌ Дублирование функциональности с MCU-QML
- ❌ Анализ цветов изображений в QML (медленно)
- ❌ Нет кэширования результатов анализа
- ❌ Повторная обработка одного и того же изображения

**Решение:**
```cpp
// Расширить существующий McuTheme класс
class McuTheme : public QObject {
    // ... существующий код ...

    // ДОБАВИТЬ:

    // Извлечение доминантного цвета
    Q_INVOKABLE void extractDominantColorAsync(const QUrl& imageUrl);

    // Извлечение палитры (топ-N цветов)
    Q_INVOKABLE void extractPaletteAsync(const QUrl& imageUrl, int count = 5);

    // Синхронные версии для простых случаев
    Q_INVOKABLE QColor getDominantColor(const QColor& color);
    Q_INVOKABLE bool isDark(const QColor& color);
    Q_INVOKABLE double getContrast(const QColor& fg, const QColor& bg);

signals:
    void dominantColorExtracted(const QUrl& imageUrl, const QColor& color);
    void paletteExtracted(const QUrl& imageUrl, const QList<QColor>& palette);

private:
    // Кэш для избежания повторной обработки
    QCache<QUrl, QColor> m_dominantColorCache;
    QCache<QUrl, QList<QColor>> m_paletteCache;

    // Переиспользовать существующую квантизацию
    QColor extractDominantColorFromImage(const QImage& image);
    QList<QColor> extractPaletteFromImage(const QImage& image, int count);
};
```

**Преимущества:**
- ✅ Переиспользование квантизации из MCU
- ✅ Единая кодовая база для цветовых операций
- ✅ Кэширование результатов
- ✅ Асинхронная обработка (уже есть infrastructure)
- ✅ Меньше дублирования кода

**Оценка:**
- **Влияние:** 🔥🔥🔥🔥 (высокое)
- **Сложность:** ⭐⭐ (низкая, код уже есть)
- **Время:** 2-3 дня
- **Прирост:** 2-5x, кэширование избавляет от повторной обработки

---

## 🟠 ВЫСОКИЙ ПРИОРИТЕТ

### 4. LauncherService → LauncherIndex C++ Plugin
**Файлы:**
- `src/core/services/LauncherService.qml`
- `src/features/launcher/providers/*.qml`

**Проблемы:**
- ❌ Поиск по .desktop файлам при каждом запросе
- ❌ Нет индексации приложений
- ❌ Сортировка результатов в QML
- ❌ ApplicationProvider читает файлы синхронно

**Решение:**
```cpp
class LauncherIndex : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool ready READ ready NOTIFY readyChanged)
    Q_PROPERTY(int appCount READ appCount NOTIFY appCountChanged)

public:
    Q_INVOKABLE void buildIndex();
    Q_INVOKABLE void rebuildIndex();
    Q_INVOKABLE QList<SearchResult*> search(const QString& query,
                                             int limit = 10);
    Q_INVOKABLE void launch(const QString& appId);
    Q_INVOKABLE void incrementFrequency(const QString& appId);

signals:
    void readyChanged();
    void indexBuilt(int count);

private:
    struct DesktopEntry {
        QString id;
        QString name;
        QString genericName;
        QString comment;
        QString exec;
        QString icon;
        QStringList keywords;
        QStringList categories;
    };

    QHash<QString, DesktopEntry> m_apps;
    QHash<QString, int> m_frequency;  // Частота запусков
    QFileSystemWatcher m_watcher;

    QList<SearchResult*> fuzzyMatch(const QString& query);
    void loadDesktopFile(const QString& path);
    void watchApplicationDirs();
};

class SearchResult : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString id READ id CONSTANT)
    Q_PROPERTY(QString name READ name CONSTANT)
    Q_PROPERTY(QString description READ description CONSTANT)
    Q_PROPERTY(QString icon READ icon CONSTANT)
    Q_PROPERTY(float score READ score CONSTANT)
};
```

**Преимущества:**
- ✅ Предварительная индексация всех .desktop файлов
- ✅ Fuzzy search алгоритмы (fts_fuzzy_match или levenshtein)
- ✅ Кэширование иконок
- ✅ Сортировка по релевантности + частоте использования
- ✅ QFileSystemWatcher для автообновления индекса
- ✅ Мгновенный поиск (индекс в памяти)

**Оценка:**
- **Влияние:** 🔥🔥🔥🔥 (высокое)
- **Сложность:** ⭐⭐⭐⭐ (выше среднего)
- **Время:** 5-6 дней
- **Прирост:** 5-20x на поиске, мгновенные результаты

---

### 5. Улучшение SystemMonitor Plugin
**Файл:** `src/plugins/src/system-monitor-qml/`

**Текущие проблемы:**
- ⚠️ Нет обработки ошибок NVML API
- ⚠️ Отсутствие fallback при недоступности libsensors
- ⚠️ Нет защиты от race conditions при чтении /proc
- ⚠️ Фиксированные интервалы обновления
- ⚠️ Нет истории метрик для графиков

**Решение:**
```cpp
class SystemMonitor : public QObject {
    // ... существующий код ...

    // ДОБАВИТЬ:

    // Адаптивные интервалы
    Q_PROPERTY(int updateInterval READ updateInterval
               WRITE setUpdateInterval NOTIFY updateIntervalChanged)

    // Топ процессов
    Q_PROPERTY(QList<ProcessInfo*> topProcesses READ topProcesses
               NOTIFY topProcessesChanged)

    // История для графиков
    Q_INVOKABLE QList<float> getCpuHistory(int seconds = 60);
    Q_INVOKABLE QList<float> getRamHistory(int seconds = 60);
    Q_INVOKABLE QList<float> getGpuHistory(int seconds = 60);

    // Алерты
    Q_INVOKABLE void setCpuThreshold(float percent);
    Q_INVOKABLE void setRamThreshold(float percent);

signals:
    void cpuThresholdExceeded(float value);
    void ramThresholdExceeded(float value);

private:
    // Кольцевой буфер для истории
    QCircularBuffer<StatsSnapshot> m_history;

    // Кэш путей к сенсорам (найти один раз)
    QString m_cpuTempPath;
    QString m_gpuTempPath;

    // Обработка ошибок
    bool initNVML();
    void cleanupNVML();

    // Top processes
    void updateTopProcesses();
    QList<ProcessInfo*> parseTopProcesses();
};

class ProcessInfo : public QObject {
    Q_OBJECT
    Q_PROPERTY(int pid READ pid CONSTANT)
    Q_PROPERTY(QString name READ name CONSTANT)
    Q_PROPERTY(float cpuUsage READ cpuUsage CONSTANT)
    Q_PROPERTY(float memUsage READ memUsage CONSTANT)
};
```

**Преимущества:**
- ✅ Обработка ошибок и graceful degradation
- ✅ История метрик для красивых графиков
- ✅ Топ процессов (полезно для SystemTab)
- ✅ Настраиваемые интервалы (экономия CPU)
- ✅ Система алертов для высокой нагрузки
- ✅ Кэширование путей сенсоров

**Оценка:**
- **Влияние:** 🔥🔥🔥 (среднее, улучшение существующего)
- **Сложность:** ⭐⭐⭐ (средняя)
- **Время:** 3-4 дня
- **Прирост:** Стабильность +50%, новая функциональность

---

## 🟡 СРЕДНИЙ ПРИОРИТЕТ

### 6. CalendarService → CalendarManager C++ Plugin
**Файл:** `src/core/services/CalendarService.qml`

**Проблемы:**
- ⚠️ Парсинг .ics файлов в QML (потенциально медленно)
- ⚠️ Нет валидации формата
- ⚠️ Сложная логика повторяющихся событий

**Решение:**
```cpp
class CalendarManager : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QList<Event*> upcomingEvents READ upcomingEvents
               NOTIFY eventsChanged)

    Q_INVOKABLE void addCalendar(const QUrl& icsFile);
    Q_INVOKABLE void removeCalendar(const QString& calendarId);
    Q_INVOKABLE QList<Event*> getEvents(const QDate& from, const QDate& to);
    Q_INVOKABLE void addEvent(Event* event);
    Q_INVOKABLE void deleteEvent(const QString& eventId);

private:
    // Использовать libical или KCalendarCore
    QHash<QString, Calendar*> m_calendars;
};
```

**Оценка:**
- **Влияние:** 🔥🔥 (низкое-среднее)
- **Сложность:** ⭐⭐⭐⭐ (высокая, нужна libical)
- **Время:** 6-7 дней
- **Прирост:** Корректность парсинга, стабильность

---

### 7. NetworkService/BluetoothService → C++ Wrappers
**Файлы:**
- `src/core/services/NetworkService.qml`
- `src/core/services/BluetoothService.qml`

**Проблемы:**
- ⚠️ Прямая работа с D-Bus из QML
- ⚠️ Плохая типизация
- ⚠️ Сложная обработка сигналов

**Решение:**
```cpp
class NetworkManager : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QList<NetworkDevice*> devices READ devices NOTIFY devicesChanged)
    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)

    Q_INVOKABLE void connectToWifi(const QString& ssid, const QString& password);
    Q_INVOKABLE void disconnect();
};

class BluetoothManager : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QList<BluetoothDevice*> devices READ devices NOTIFY devicesChanged)
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)

    Q_INVOKABLE void startScan();
    Q_INVOKABLE void connectToDevice(const QString& address);
};
```

**Оценка:**
- **Влияние:** 🔥🔥 (низкое-среднее)
- **Сложность:** ⭐⭐⭐ (средняя)
- **Время:** 4-5 дней (каждый)
- **Прирост:** Типобезопасность, лучший API

---

### 8. Улучшение Qalculate Plugin
**Файл:** `src/plugins/src/qalculate-qml/`

**Текущие недостатки:**
- ⚠️ Синхронный API (блокирует при сложных вычислениях)
- ⚠️ Нет кэша результатов
- ⚠️ Нет истории
- ⚠️ Нет автодополнения

**Решение:**
```cpp
class QalculateWrapper : public QObject {
    // ... существующий код ...

    // ДОБАВИТЬ:

    // Асинхронная версия
    Q_INVOKABLE void evalAsync(const QString& expr);
    signal void resultReady(const QString& expr, const QString& result);

    // История вычислений
    Q_PROPERTY(QStringList history READ history NOTIFY historyChanged)
    Q_INVOKABLE void clearHistory();

    // Автодополнение функций
    Q_INVOKABLE QStringList suggestFunctions(const QString& partial);
    Q_INVOKABLE QStringList suggestUnits(const QString& partial);

private:
    QCache<QString, QString> m_cache;  // Кэш результатов
    QStringList m_history;
    QThread* m_workerThread;
};
```

**Оценка:**
- **Влияние:** 🔥🔥 (низкое-среднее)
- **Сложность:** ⭐⭐ (низкая)
- **Время:** 2-3 дня
- **Прирост:** UX улучшения, избежание блокировок

---

## 🟢 НИЗКИЙ ПРИОРИТЕТ

### 9. ClipboardService → ClipboardHistory Model
**Файл:** `src/core/services/ClipboardService.qml`

**Проблемы:**
- ⚠️ История в QML (потенциально неэффективно)
- ⚠️ Нет лимита размера истории

**Решение:**
```cpp
class ClipboardHistory : public QAbstractListModel {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(int maxItems READ maxItems WRITE setMaxItems)

    Q_INVOKABLE void clear();
    Q_INVOKABLE QString getItem(int index);
    Q_INVOKABLE void removeItem(int index);
};
```

**Оценка:**
- **Влияние:** 🔥 (низкое)
- **Сложность:** ⭐⭐ (низкая)
- **Время:** 2 дня
- **Прирост:** Эффективный рендеринг больших списков

---

### 10. WeatherService → C++ Plugin
**Файл:** `src/core/services/Weather.qml`

**Проблемы:**
- ⚠️ HTTP запросы из QML
- ⚠️ Парсинг JSON

**Решение:**
```cpp
class WeatherService : public QObject {
    Q_INVOKABLE void fetchWeather(const QString& location);

private:
    QNetworkAccessManager* m_network;
};
```

**Оценка:**
- **Влияние:** 🔥 (низкое)
- **Сложность:** ⭐⭐ (низкая)
- **Время:** 2-3 дня
- **Прирост:** Лучшая обработка ошибок сети

---

## 🏗️ АРХИТЕКТУРНЫЕ УЛУЧШЕНИЯ

### 11. BaseService Abstract Class
**Цель:** Унификация всех сервисов

```cpp
class BaseService : public QObject {
    Q_OBJECT
    QML_UNCREATABLE("Base class")

    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)

protected:
    QThread* m_workerThread = nullptr;

    void initWorkerThread();
    void runAsync(std::function<void()> task);

signals:
    void busyChanged();
    void errorChanged();
    void error(const QString& message);
};
```

**Оценка:**
- **Влияние:** 🔥🔥🔥 (архитектурное)
- **Сложность:** ⭐⭐ (низкая)
- **Время:** 1-2 дня
- **Прирост:** Консистентность API, переиспользование кода

---

### 12. ConfigManager C++ Singleton
**Цель:** Замена JSON на QSettings

```cpp
class ConfigManager : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_INVOKABLE QVariant get(const QString& key, const QVariant& defaultValue);
    Q_INVOKABLE void set(const QString& key, const QVariant& value);
    Q_INVOKABLE void sync();

signals:
    void changed(const QString& key, const QVariant& value);

private:
    QSettings m_settings;
    QHash<QString, QVariant> m_cache;
};
```

**Оценка:**
- **Влияние:** 🔥🔥🔥 (архитектурное)
- **Сложность:** ⭐⭐ (низкая)
- **Время:** 2-3 дня
- **Прирост:** Производительность, типобезопасность

---

### 13. ImageProcessor Pipeline
**Цель:** Унификация обработки изображений

```cpp
class ImageProcessor : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_INVOKABLE void processAsync(const QUrl& image);

signals:
    void imageProcessed(const QUrl& image, const ImageData& data);

private:
    QThreadPool m_pool;
};

struct ImageData {
    QColor dominantColor;
    QList<QColor> palette;
    SchemeContent scheme;
    QSize size;
    QString hash;  // Для кэширования
};
```

**Оценка:**
- **Влияние:** 🔥🔥🔥 (архитектурное)
- **Сложность:** ⭐⭐⭐ (средняя)
- **Время:** 3-4 дня
- **Прирост:** Переиспользование, кэширование

---

## 📊 ИТОГОВАЯ ТАБЛИЦА ПРИОРИТЕТОВ

| № | Компонент | Приоритет | Влияние | Сложность | Время | Прирост |
|---|-----------|-----------|---------|-----------|-------|---------|
| 1 | WallpaperManager | 🔴 КРИТИЧ | 🔥🔥🔥🔥🔥 | ⭐⭐⭐ | 3-4д | Устранение UI блокировок |
| 2 | NotificationManager | 🔴 КРИТИЧ | 🔥🔥🔥🔥🔥 | ⭐⭐⭐ | 4-5д | 10-100x поиск, I/O |
| 3 | MCU расширение | 🔴 КРИТИЧ | 🔥🔥🔥🔥 | ⭐⭐ | 2-3д | 2-5x, кэширование |
| 4 | LauncherIndex | 🟠 ВЫСОК | 🔥🔥🔥🔥 | ⭐⭐⭐⭐ | 5-6д | 5-20x поиск |
| 5 | SystemMonitor v2 | 🟠 ВЫСОК | 🔥🔥🔥 | ⭐⭐⭐ | 3-4д | Стабильность +50% |
| 6 | CalendarManager | 🟡 СРЕДН | 🔥🔥 | ⭐⭐⭐⭐ | 6-7д | Корректность |
| 7 | NetworkManager | 🟡 СРЕДН | 🔥🔥 | ⭐⭐⭐ | 4-5д | Типобезопасность |
| 8 | Qalculate v2 | 🟡 СРЕДН | 🔥🔥 | ⭐⭐ | 2-3д | UX, async |
| 9 | ClipboardHistory | 🟢 НИЗК | 🔥 | ⭐⭐ | 2д | Эффективность |
| 10 | WeatherService | 🟢 НИЗК | 🔥 | ⭐⭐ | 2-3д | Error handling |
| 11 | BaseService | 🏗️ АРХИТ | 🔥🔥🔥 | ⭐⭐ | 1-2д | Консистентность |
| 12 | ConfigManager | 🏗️ АРХИТ | 🔥🔥🔥 | ⭐⭐ | 2-3д | Производительность |
| 13 | ImageProcessor | 🏗️ АРХИТ | 🔥🔥🔥 | ⭐⭐⭐ | 3-4д | Переиспользование |

---

## 🚀 РЕКОМЕНДУЕМЫЙ ПЛАН РЕАЛИЗАЦИИ

### **Фаза 1: Критические улучшения** (9-12 дней)
1. ✅ WallpaperManager C++ plugin
2. ✅ NotificationManager C++ plugin
3. ✅ MCU-QML расширение для ColorService

**Результат:** Устранение всех UI блокировок, 10-100x прирост производительности

---

### **Фаза 2: Архитектурный фундамент** (6-9 дней)
4. ✅ BaseService abstract class
5. ✅ ConfigManager C++ singleton
6. ✅ ImageProcessor pipeline

**Результат:** Унифицированная архитектура для будущих плагинов

---

### **Фаза 3: Функциональные улучшения** (8-10 дней)
7. ✅ LauncherIndex C++ plugin
8. ✅ SystemMonitor v2 (улучшения)

**Результат:** Мгновенный поиск приложений, расширенный мониторинг

---

### **Фаза 4: Дополнительные плагины** (по необходимости)
9. CalendarManager
10. NetworkManager
11. Qalculate v2
12. ClipboardHistory
13. WeatherService

**Результат:** Полная миграция всех сервисов в C++

---

## 🎯 ОЖИДАЕМЫЕ РЕЗУЛЬТАТЫ

### **Производительность:**
- Устранение всех UI блокировок (0ms вместо 100-500ms)
- 10-100x прирост на операциях поиска
- 2-5x прирост на обработке изображений
- Снижение нагрузки на GUI thread на ~40%

### **Стабильность:**
- Лучшая обработка ошибок
- Graceful degradation при отсутствии зависимостей
- Защита от race conditions
- Предсказуемое управление памятью

### **Качество кода:**
- Типобезопасность
- Лучшая отладка
- Переиспользование кода
- Консистентный API

### **Пользовательский опыт:**
- Мгновенный отклик UI
- Плавные анимации
- Отсутствие freezes
- Расширенная функциональность

---

## 📝 ПРИМЕЧАНИЯ

1. **Обратная совместимость:** Все новые C++ плагины должны иметь тот же API что и QML версии для легкой миграции

2. **Тестирование:** Каждый плагин должен иметь unit tests на C++ стороне

3. **Документация:** Все публичные API должны быть задокументированы

4. **Fallback:** Критические плагины должны иметь fallback на QML версию если C++ недоступен

5. **Версионирование:** Использовать semver для плагинов (1.0.0)

---

**Автор анализа:** Claude Sonnet 4.5
**Дата:** 2026-01-14
**Версия документа:** 1.0
