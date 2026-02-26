# Полный аудит проекта QuickShell

> Дата последнего обновления: 2026-02-22
> Ветка: `dashboard-refactor`
> Статус: C++ плагины исправлены и протестированы. Архитектурный анализ завершён.

---

## Содержание

1. [Структура проекта](#1-структура-проекта)
2. [Аудит C++ плагинов (безопасность)](#2-аудит-c-плагинов-безопасность)
3. [Архитектурные проблемы](#3-архитектурные-проблемы)
4. [Система конфигурации](#4-система-конфигурации)
5. [Хардкод и негибкость](#5-хардкод-и-негибкость)
6. [Проблемы производительности](#6-проблемы-производительности)
7. [Проблемы корректности и качества кода](#7-проблемы-корректности-и-качества-кода)
8. [Мёртвый код и пустые директории](#8-мёртвый-код-и-пустые-директории)
9. [Приоритезированный план действий](#9-приоритезированный-план-действий)
10. [Сводная таблица всех проблем](#10-сводная-таблица-всех-проблем)

---

## 1. Структура проекта

```
shell/
├── shell.qml                    # Точка входа (ShellRoot + Variants по экранам)
├── config.json                  # Пользовательский конфиг
├── config/
│   ├── default.json             # Конфиг по умолчанию (fallback)
│   └── wallpaper.json           # Конфигурация обоев
│
├── src/
│   ├── core/
│   │   ├── config/
│   │   │   └── Config.qml       # God object: токены + конфиг + тема (469 строк)
│   │   └── services/            # 22 синглтона-сервиса
│   │       ├── AppFrequencyService.qml   # SQLite статистика запусков
│   │       ├── AudioService.qml          # PipeWire/PulseAudio
│   │       ├── BluetoothService.qml      # Bluetooth (polling 2s)
│   │       ├── CalendarService.qml       # Календарь
│   │       ├── ClipboardService.qml      # Буфер обмена + fuzzy search
│   │       ├── ColorService.qml          # M3 палитра с transparency layers
│   │       ├── DateTime.qml              # Дата/время
│   │       ├── GlobalStates.qml          # Центральный хаб UI-состояния (197 строк)
│   │       ├── HyprlandWindowService.qml # Интеграция с Hyprland IPC
│   │       ├── IconCategoryResolver.qml  # Иконки приложений
│   │       ├── IdleInhibitorService.qml  # Запрет простоя
│   │       ├── LauncherService.qml       # Обёртки приложений + LRU кэш
│   │       ├── MprisController.qml       # Медиа-плеер (D-Bus MPRIS)
│   │       ├── NetworkService.qml        # Wi-Fi (nmcli polling 10s)
│   │       ├── NotificationService.qml   # Уведомления (489 строк)
│   │       ├── PopoutsState.qml          # Состояние всплывающих панелей
│   │       ├── SystemMonitorService.qml  # QML обёртка C++ SystemMonitor
│   │       ├── VPNService.qml            # VPN (nmcli polling 5s)
│   │       ├── WallpaperAnalyzer.qml     # Luminance обоев (Canvas на main thread!)
│   │       ├── WallpaperService.qml      # Обои (768 строк, god object)
│   │       ├── Weather.qml               # Погода (Open-Meteo API)
│   │       └── WeatherIcons.qml          # Маппинг кодов погоды → иконки
│   │
│   ├── features/
│   │   ├── background/
│   │   │   └── Wallpaper.qml
│   │   ├── dashboard/           # Дашборд (20+ файлов)
│   │   │   ├── Dashboard.qml              # Окно + Loader
│   │   │   ├── DashboardContent.qml       # TabBar + StackLayout
│   │   │   ├── components/
│   │   │   │   ├── AudioTab.qml           # ВОЗМОЖНЫЙ ДУБЛИКАТ tabs/
│   │   │   │   ├── CalendarTab.qml        # МЁРТВЫЙ КОД (374 строки)
│   │   │   │   ├── DeviceSelectionDialog.qml
│   │   │   │   ├── EventDialog.qml
│   │   │   │   ├── MainTab.qml
│   │   │   │   ├── MediaTab.qml           # ВОЗМОЖНЫЙ ДУБЛИКАТ tabs/
│   │   │   │   ├── TabButton.qml
│   │   │   │   ├── audiotab_elements/
│   │   │   │   │   └── MediaPlayer.qml
│   │   │   │   ├── maintab_elements/
│   │   │   │   │   ├── CavaElement.qml
│   │   │   │   │   ├── ClockElement.qml
│   │   │   │   │   ├── MediaPlayerElement.qml
│   │   │   │   │   ├── QuickActionsElement.qml
│   │   │   │   │   ├── SheduleElement.qml
│   │   │   │   │   ├── SystemMonitoringElement.qml  # Shape + MSAA
│   │   │   │   │   ├── SystemTrayElement.qml
│   │   │   │   │   ├── TrayMenu.qml
│   │   │   │   │   ├── TrayMenuOverlay.qml
│   │   │   │   │   ├── TrayTooltip.qml
│   │   │   │   │   ├── UserInfoElement.qml  # hardcoded ~/.face
│   │   │   │   │   └── WeatherElement.qml
│   │   │   │   └── weathertab_elements/
│   │   │   │       ├── DetailCard.qml
│   │   │   │       ├── DetailRow.qml
│   │   │   │       └── ForecastCard.qml
│   │   │   └── tabs/
│   │   │       ├── CalendarTab.qml        # Актуальная версия
│   │   │       ├── MediaTab.qml
│   │   │       ├── QuickTab.qml
│   │   │       ├── SystemTab.qml
│   │   │       └── WeatherTab.qml
│   │   ├── launcher/
│   │   │   ├── Launcher.qml
│   │   │   ├── LauncherContent.qml
│   │   │   ├── components/
│   │   │   │   └── AppListItem.qml
│   │   │   └── providers/
│   │   │       ├── ApplicationProvider.qml  # JS fuzzy search per-keystroke
│   │   │       ├── BaseProvider.qml
│   │   │       ├── CalculatorProvider.qml
│   │   │       └── ClipboardProvider.qml
│   │   ├── notifications/
│   │   │   ├── NotificationCenter.qml
│   │   │   ├── NotificationHistoryItem.qml
│   │   │   ├── NotificationItem.qml        # x: 400 hardcoded
│   │   │   └── NotificationPopup.qml       # visible: true всегда
│   │   ├── osd/
│   │   │   └── VolumeOSD.qml
│   │   ├── popouts/
│   │   │   ├── Popouts.qml
│   │   │   └── PopoutsScrim.qml
│   │   ├── statusbar/
│   │   │   ├── StatusBar.qml              # 3 Repeater с JS filter
│   │   │   ├── BarWidgetLoader.qml        # Динамическая загрузка виджетов
│   │   │   ├── BatteryWidget.qml
│   │   │   ├── ClockWidget.qml
│   │   │   ├── LayoutWidget.qml
│   │   │   ├── MPRISWidget.qml            # FrameAnimation 60fps
│   │   │   ├── NetworkWidget.qml
│   │   │   ├── NotificationWidget.qml
│   │   │   ├── TrayMenu.qml
│   │   │   ├── TrayWidget.qml
│   │   │   ├── VolumeWidget.qml
│   │   │   └── WeatherWidget.qml
│   │   └── system/              # ПУСТАЯ ДИРЕКТОРИЯ
│   │
│   ├── plugins/                 # C++ QML плагины
│   │   ├── CMakeLists.txt
│   │   ├── external/
│   │   │   ├── material-color-utilities/  # Google MCU reference impl
│   │   │   └── mcu-cpp/
│   │   └── src/
│   │       ├── mcu-qml/                   # Material Color Utilities
│   │       │   ├── McuTheme.h
│   │       │   ├── McuTheme.cpp
│   │       │   ├── plugin.cpp
│   │       │   ├── CMakeLists.txt
│   │       │   └── qmldir
│   │       ├── qalculate-qml/             # Калькулятор (libqalculate)
│   │       │   ├── QalculateWrapper.h
│   │       │   ├── QalculateWrapper.cpp
│   │       │   ├── CMakeLists.txt
│   │       │   └── qmldir
│   │       └── system-monitor-qml/        # Мониторинг системы
│   │           ├── SystemMonitor.h
│   │           ├── SystemMonitor.cpp
│   │           ├── CMakeLists.txt
│   │           └── qmldir
│   │
│   └── ui/                      # Библиотека компонентов MD3
│       ├── animations/
│       │   └── StandardAnimations.qml
│       ├── base/
│       │   ├── AnimatedProperty.qml
│       │   ├── CircleAvatar.qml
│       │   ├── ClickableIcon.qml
│       │   ├── IconButton.qml
│       │   ├── MaterialButton.qml
│       │   ├── MaterialIcon.qml
│       │   ├── MaterialIndicator.qml
│       │   ├── MaterialMarqueeText.qml
│       │   ├── MaterialText.qml           # pointSize vs pixelSize
│       │   └── SectionHeader.qml
│       ├── containers/
│       │   ├── BarElement.qml
│       │   ├── BarSection.qml
│       │   ├── CenterBarSection.qml
│       │   ├── Divider.qml
│       │   ├── ListItem.qml
│       │   ├── MaterialCard.qml           # Двойное alpha
│       │   └── ScrollableList.qml
│       ├── display/             # ПУСТАЯ
│       ├── feedback/
│       │   ├── Badge.qml
│       │   ├── Dialog.qml
│       │   ├── EmptyState.qml
│       │   ├── LazyPopup.qml
│       │   ├── MaterialMenu.qml
│       │   ├── StateLayer.qml
│       │   ├── TooltipItem.qml
│       │   └── TooltipManager.qml
│       ├── inputs/
│       │   ├── MaterialCheckBox.qml
│       │   └── MaterialSlider.qml         # debug console.log
│       ├── layout/              # ПУСТАЯ
│       └── navigation/          # ПУСТАЯ
│
└── docs/                        # Документация (24 файла)
```

### Статистика
- **QML файлов**: ~80+
- **C++ плагинов**: 3 (McuTheme, SystemMonitor, QalculateWrapper)
- **Сервисов-синглтонов**: 22
- **UI компонентов**: ~28
- **Фич (features)**: 7 (dashboard, statusbar, launcher, notifications, osd, popouts, background)
- **Суммарный объём кода**: ~8000+ строк QML, ~1200 строк C++

---

## 2. Аудит C++ плагинов (безопасность)

> Все критические исправления применены и протестированы. Коммит: `3e854bdd`

### 2.1 McuTheme — КРИТИЧЕСКИЕ ИСПРАВЛЕНИЯ (СДЕЛАНО)

**Файлы**: `src/plugins/src/mcu-qml/McuTheme.h`, `McuTheme.cpp`

**Найденные проблемы:**

1. **Use-after-free в `applySeed()`** — лямбда в `QtConcurrent::run` захватывала сырой `this`. При множественных вызовах `applySeed()` старые futures продолжали работать с висячим указателем. Деструктор вызывал `waitForFinished()` только для последнего future.

2. **qDebug() из thread pool → краш** — вызовы логирования из потоков пула Qt приводили к крашу в `QUtf8::compareUtf8` внутри quickshell'овского `ThreadLogging`. Стек-трейс:
   ```
   Thread 9 "QThreadPool Thr" received signal SIGSEGV
   #0  QUtf8::compareUtf8 (...)
   #1  QAnyStringView::compare (...)
   #2  QLoggingRule::pass (...)
   #3  QLoggingRegistry::shouldChange (...)
   ```
   Это была **прямая причина крашей** после замены процессора (изменение тайминга гонок).

3. **Аналогичная проблема в `setSource()` для URL** — та же лямбда с raw `this` в коде извлечения seed из изображения.

**Примененные исправления:**
```cpp
// 1. QPointer guard вместо raw this во всех лямбдах
m_future = QtConcurrent::run([guard = QPointer<McuTheme>(this), requestId, seed, dark, variant, contrast]() {
    const QVariantMap colors = buildScheme(seed, dark, variant, contrast);
    auto* app = QCoreApplication::instance();
    if (!app) return;
    QMetaObject::invokeMethod(app, [guard, requestId, colors]() {
        if (!guard) return;  // объект уже уничтожен
        if (requestId != guard->m_generation) return;  // устаревший запрос
        guard->m_colors = colors;
        // ...
    }, Qt::QueuedConnection);
});

// 2. buildScheme сделан static — не обращается к this

// 3. Деструктор инвалидирует generation counters ДО ожидания
McuTheme::~McuTheme() {
    m_generation = UINT64_MAX;
    m_seedRequest = UINT64_MAX;
    if (m_future.isRunning()) m_future.waitForFinished();
    if (m_seedFuture.isRunning()) m_seedFuture.waitForFinished();
}

// 4. Удалены все qDebug/qWarning из thread pool кода
```

### 2.2 SystemMonitor — исправление shutdown (СДЕЛАНО)

**Файл**: `src/plugins/src/system-monitor-qml/SystemMonitor.cpp`

**Проблема**: `stopWorker()` имел таймаут 1 секунда. Если рабочий поток не успевал завершиться, объект уничтожался, а поток продолжал работать с висячими указателями.

**Исправление**:
```cpp
void SystemMonitor::stopWorker() {
    m_workerThread.requestInterruption();
    m_workerThread.quit();
    if (!m_workerThread.wait(3000)) {
        qWarning("SystemMonitor: worker thread did not stop in 3s, waiting indefinitely");
        m_workerThread.wait();  // fallback — ждём бесконечно
    }
}
```

### 2.3 QalculateWrapper — race condition (СДЕЛАНО)

**Файл**: `src/plugins/src/qalculate-qml/QalculateWrapper.cpp`

**Проблема**: `if (!CALCULATOR)` — не потокобезопасная проверка при инициализации.

**Исправление**:
```cpp
static std::once_flag s_calcInitFlag;

QalculateWrapper::QalculateWrapper(QObject* parent) : QObject(parent) {
    std::call_once(s_calcInitFlag, []() {
        static std::unique_ptr<Calculator> s_calculator(new Calculator());
        CALCULATOR = s_calculator.get();
        CALCULATOR->loadExchangeRates();
        CALCULATOR->loadGlobalDefinitions();
        CALCULATOR->loadLocalDefinitions();
    });
}
```

### 2.4 Остающиеся замечания по C++ плагинам

| Проблема | Файл | Приоритет |
|---|---|---|
| `plugin.cpp` двойная регистрация (QML_ELEMENT + qmlRegisterType) | `mcu-qml/plugin.cpp` | P2 |
| `sscanf %lu` вместо `SCNu64` для `uint64_t` | `SystemMonitor.cpp:486` | P3 |
| `emitIfChanged` для qreal без epsilon | `SystemMonitor.cpp:609` | P3 |
| `eval()` блокирует GUI до 100ms | `QalculateWrapper.cpp:22` | P3 |
| Hardcoded `"Arch Linux"` и `"Hyprland"` | `SystemMonitor.h:100-101` | P2 |
| `SENSORS_LIB` может быть пустой | `system-monitor-qml/CMakeLists.txt` | P3 |

---

## 3. Архитектурные проблемы

### 3.1 Config.qml — God Object (469 строк)

**Путь**: `src/core/config/Config.qml`

Config.qml совмещает **3 разные ответственности** в одном файле:

| Ответственность | Строки | Описание |
|---|---|---|
| Design tokens | 171-426 | MD3 spacing, shape, typography, motion, elevation — чистые константы |
| Runtime конфигурация | 21-90 | Загрузка JSON, FileView, парсинг, weather settings |
| Тема/цвета | 23-29, 91-170, 459-468 | McuTheme, colors QtObject, apply() |

**Количество вложенных QtObject**: ~30+ (каждый = отдельный QObject в куче)
- 15 стилей типографики × 4 свойства
- spacing (8), shape (7), elevation (6), stateLayer (4), iconSize (4)
- motion с duration (16) и easing (8)
- bar, colors, weather, ripple, touchTarget

**Импортируется**: 80+ файлов — любое изменение потенциально затрагивает весь проект.

### 3.2 Рассинхронизация Config.qml и config.json

`config.json` определяет `bar.widgets[]` (массив с type, section, settings, clickAction, monitors). StatusBar **корректно** читает из `Config.data.bar?.widgets`.

Но `Config.bar.entries` (строки 245-276) содержит **отдельный хардкоженный массив**, не связанный с JSON — это **мёртвый код**, создающий путаницу.

### 3.3 GlobalStates — центральный хаб UI-состояния

**Путь**: `src/core/services/GlobalStates.qml` (197 строк)

Содержит:
- 8 boolean-флагов открытия/закрытия панелей
- 6 обработчиков `onChanged` для автозакрытия
- Маршрутизацию `clickAction` (switch с 7 ветками)
- 3 GlobalShortcut определения
- 16 IPC-функций (toggleDashboard, openLauncher, closeAll и т.д.)

### 3.4 WallpaperService — God Object (768 строк)

Совмещает:
- Файловый I/O (сканирование директорий, кэширование)
- Управление обоями (смена, auto-change)
- Конфигурация (чтение/запись wallpaper.json)
- Управление процессами (Process для внешних команд)
- IPC обработчики
- postScriptQueue (не-реактивная мутация массива)

### 3.5 22 синглтона — чрезмерная связанность

Все сервисы — `pragma Singleton`, доступные глобально:
- **Неявные зависимости**: любой компонент обращается к любому сервису напрямую
- **Невозможность тестирования**: нельзя мокнуть синглтон
- **Все загружаются при старте**: нет ленивой инициализации
- **Порядок инициализации**: зависит от порядка импорта в QML

### 3.6 Polling-тяжёлая архитектура

| Сервис | Интервал | Метод |
|---|---|---|
| BluetoothService | 2s | Итерация устройств |
| SystemMonitor (fast) | 2s | /proc/stat, /proc/meminfo |
| SystemMonitor (slow) | 5s | температура, диски, uptime |
| VPNService | 5s | 2× nmcli |
| NetworkService | 10s | 2× nmcli |
| NotificationService | 250ms | Проверка expiration |
| Weather | 15min | HTTP API |

**Итого**: ~6 subprocess fork/exec в секунду + 3 таймера на main thread.

### 3.7 LazyLoader — загружает всё немедленно

**Файл**: `shell.qml:56-83`

Все LazyLoader имеют `loading: true`, что нивелирует их пользу:
```qml
LazyLoader { loading: true; Dashboard {} }
LazyLoader { loading: true; VolumeOSD {} }
LazyLoader { loading: true; Launcher {} }
LazyLoader { loading: true; NotificationPopup {} }
LazyLoader { loading: true; NotificationCenter {} }
```

### 3.8 StackLayout создаёт все вкладки

**Файл**: `src/features/dashboard/DashboardContent.qml:77-103`

StackLayout инстанцирует все дочерние элементы, даже невидимые:
```qml
StackLayout {
    QuickTab {}     // Всегда создан, MediaPlayer с blur работает
    WeatherTab {}   // Всегда создан, обновляется
    CalendarTab {}  // Всегда создан
    SystemTab {}    // Всегда создан, PipewireTracker работает
}
```

---

## 4. Система конфигурации

### 4.1 Текущая схема

```
config.json → FileView (watchChanges) → Config.data (QVariant)
                                            ↓
                                  доступ через optional chaining:
                                  Config.data.bar?.widgets || []
```

**Проблемы:**
- Нет валидации схемы JSON
- Нет типизации — все значения `var`
- Нет централизованных defaults — каждый потребитель пишет свой fallback (`?? defaultValue`)
- `config/default.json` используется только при ошибке загрузки основного конфига

### 4.2 Что читается из config.json, а что — нет

| Секция config.json | Используется? | Где |
|---|---|---|
| `appearance.theme.darkMode` | Да | `Config.qml:26` → McuTheme |
| `appearance.theme.variant` | Да | `Config.qml:27` → McuTheme |
| `appearance.theme.source` | **Нет** | Всегда wallpaper |
| `appearance.spacing/rounding/animations/colors` | **Нет** | Константы в Config |
| `bar.enabled` | **Нет** | StatusBar всегда виден |
| `bar.widgets[]` | Да | `StatusBar.qml:17` |
| `bar.height/margin/position` | **Нет** | Хардкод в `Config.bar` |
| `dashboard.width/height` | **Нет** | Хардкод в `Dashboard.qml` (причём другие значения!) |
| `dashboard.tabs[]` | **Нет** | Хардкод в `DashboardContent.qml` |
| `dashboard.defaultTab` | **Нет** | Хардкод |
| `notifications.panel.*` | **Нет** | Хардкод в NotificationService |
| `notifications.popup.*` | **Нет** | Хардкод в NotificationPopup |
| `launcher.fuzzy` | **Нет** | Хардкод |
| `launcher.maxResults` | **Нет** | Хардкод |
| `launcher.providers` | **Нет** | Все провайдеры всегда активны |
| `osd.*` | **Нет** | Хардкод в VolumeOSD |
| `services.weather.location` | Да | `Config.weather.location` |
| `services.weather.refreshMinutes` | Да | `Config.weather.refreshMinutes` |
| `services.calendar.*` | **Нет** | Хардкод |
| `services.vpn.name` | **Нет** | Хардкод `"diasoft_VPN"` |
| `wallpaper.*` | **Нет** | WallpaperService имеет свой конфиг |
| `hyprland.*` | **Нет** | Хардкод |

**Вывод**: Из ~30+ настроек config.json реально используются только **5**:
1. `appearance.theme.darkMode`
2. `appearance.theme.variant`
3. `bar.widgets[]`
4. `services.weather.location`
5. `services.weather.refreshMinutes`

---

## 5. Хардкод и негибкость

### 5.1 Пользовательские данные в коде

| Файл | Строка | Хардкод | Должно быть |
|---|---|---|---|
| `Config.qml` | 428 | `vpnName: "nikuznetsov\(2\)"` | `config.json → services.vpn.name` |
| `VPNService.qml` | 15 | `primaryVPN: "diasoft_VPN"` | `config.json → services.vpn.name` |
| `Weather.qml` | 12-13 | `latitude: 53.2, longitude: 45.0` | Геокодинг по location |
| `UserInfoElement.qml` | ~24 | `"file:///home/at1ass/.face"` | `$HOME/.face` или конфиг |
| `SystemMonitor.h` | 100-101 | `"Arch Linux"`, `"Hyprland"` | Автодетект из `/etc/os-release` |

### 5.2 Магические числа в UI

| Файл | Что | Значение | Проблема |
|---|---|---|---|
| `Dashboard.qml` | sidebarWidth/Height | 900×640 | config.json говорит 420×600 |
| `DashboardContent.qml` | Высоты вкладок | 640, 660, 600, 700 | Не из конфига |
| `DashboardContent.qml` | Высота TabBar | 92 | Не из Config.spacing |
| `NotificationService.qml` | maxVisible | 5 | config.json → 3 |
| `NotificationService.qml` | defaultExpireTimeout | 7000ms | Не конфигурируемо |
| `NotificationItem.qml` | Начальная позиция | x: 400 | Не привязана к экрану |
| `LauncherService.qml` | Макс. кэш | 1000 | Не конфигурируемо |
| `StatusBar.qml` | Прозрачность фона | 0.90 | Не из config.json |
| `StatusBar.qml` | Primary tint opacity | 0.12 | Не из токенов |

### 5.3 Привязка к внешним утилитам

| Файл | Утилита | Альтернативы |
|---|---|---|
| `VPNService.qml` | `nmcli` | iwd, connmanctl |
| `NetworkService.qml` | `nmcli` | iwd, wpa_supplicant |
| `BluetoothService.qml` | `blueman-manager` | blueberry, gnome-bluetooth |
| `VPNService.qml` | `nm-connection-editor` | KDE настройки |

### 5.4 Несоответствия config.json ↔ код

| Параметр | config.json | Код | Файл |
|---|---|---|---|
| Dashboard width | 420 | 900 | Dashboard.qml:14 |
| Dashboard height | 600 | 640 | Dashboard.qml:15 |
| Dashboard tabs | 4 вкладки с id/name/icon/keybind | Хардкоженный массив | DashboardContent.qml:40-57 |
| Notification popup maxVisible | 3 | 5 | NotificationService.qml |
| Bar widgets | Массив из 10 виджетов | Массив из 6 | Config.bar.entries (мёртвый код) |

---

## 6. Проблемы производительности

### 6.1 КРИТИЧНО: WallpaperAnalyzer — Canvas на главном потоке

**Путь**: `src/core/services/WallpaperAnalyzer.qml`

```qml
Canvas {
    onPaint: {
        const ctx = getContext("2d")
        ctx.drawImage(sampleImage, 0, 0, width, height)
        const data = ctx.getImageData(0, 0, width, height).data  // БЛОКИРУЕТ!
        // JS цикл по пикселям
        for (let i = 0; i < data.length; i += 4) { ... }
    }
}
```

`getImageData()` + JS-цикл по пикселям **блокируют главный поток**. McuTheme уже делает аналогичную работу в C++ (квантизация цветов из изображения) — можно расширить его API методом `luminance()`.

### 6.2 СРЕДНЕ: Поиск в лаунчере — JS per-keystroke

**Путь**: `src/features/launcher/providers/ApplicationProvider.qml`

На каждый ввод символа:
1. Итерация по **всем** desktop entries
2. `toLowerCase()` на каждой строке
3. Fuzzy match в JavaScript
4. Создание QML wrapper объектов (LRU-кэш на 1000 в LauncherService)

### 6.3 СРЕДНЕ: SystemMonitoringElement — Shape + MSAA

**Путь**: `src/features/dashboard/components/maintab_elements/SystemMonitoringElement.qml`

4 элемента `Shape` с `CurveRenderer` + `layer.enabled: true` + MSAA, обновление каждые 250ms. Каждый Shape создаёт offscreen framebuffer для антиалиасинга.

### 6.4 СРЕДНЕ: ColorService — каскадные пересчёты

**Путь**: `src/core/services/ColorService.qml`

При смене палитры `Config.colors.apply()` последовательно меняет ~45 свойств. Каждое изменение триггерит пересчёт всех зависимых свойств. Итого: ~9000 операций при каждой смене обоев.

### 6.5 НИЗКО: MPRISWidget — FrameAnimation 60fps

**Путь**: `src/features/statusbar/MPRISWidget.qml:236-240`

`FrameAnimation` при hover генерирует D-Bus запрос к плееру ~60 раз/с, хотя `MprisController` уже имеет Timer 1s.

### 6.6 НИЗКО: NotificationService — Timer 250ms

Timer итерирует все активные уведомления каждые 250ms для проверки expiration. Лучше: один Timer на ближайшее событие или Timer на каждое уведомление.

### 6.7 Потенциальные оптимизации через C++

| Что | Текущее | Рекомендация | Ожидаемый эффект |
|---|---|---|---|
| Wallpaper luminance | Canvas JS | McuTheme.luminance() | ~100x ускорение |
| App search | JS fuzzy match | C++ fuzzy search плагин | ~10-50x ускорение |
| Clipboard search | JS search | Тот же C++ плагин | ~10-50x ускорение |
| Design tokens | 30+ QObject | C++ singleton | Меньше памяти при старте |

---

## 7. Проблемы корректности и качества кода

### 7.1 LauncherService — destroy обёртки в использовании

**Файл**: `src/core/services/LauncherService.qml:44-67`

`_evictOldestCacheEntry()` вызывает `wrapper.destroy()`, но wrapper может ещё быть в `filteredApps` и отображаться через ListView → use-after-free.

### 7.2 MaterialText — pointSize вместо pixelSize

**Файл**: `src/ui/base/MaterialText.qml:20`

Config.typography определяет размеры в пикселях (57, 45, 36...), но они назначаются как `font.pointSize`. При 96 DPI весь текст на ~33% крупнее MD3 спецификации.

### 7.3 MaterialCard — двойное alpha

**Файл**: `src/ui/containers/MaterialCard.qml:23`

MaterialCard применяет `Qt.alpha(color, 0.85)`, а вызывающие компоненты часто передают цвет уже с alpha. Результат: `0.80 × 0.85 = 0.68` эффективная прозрачность.

### 7.4 Theme source fallback

**Файл**: `src/core/config/Config.qml:25`

```qml
source: WallpaperService.currentWallpaper !== "" ? WallpaperService.currentWallpaper : Qt.alpha("#6200EE", 0)
```

`Qt.alpha(..., 0)` создаёт полностью прозрачный цвет — неожиданный seed для McuTheme.

### 7.5 NotificationPopup — окно всегда visible

**Файл**: `src/features/notifications/NotificationPopup.qml:17`

```qml
PanelWindow { visible: true; implicitHeight: count > 0 ? listHeight : 0 }
```

Окно рендерится (с нулевой высотой) на каждом мониторе, даже без уведомлений.

### 7.6 Debug logging в production

| Файл | Строки |
|---|---|
| `MaterialSlider.qml` | 99-103 — console.log при каждом движении слайдера |
| `Popouts.qml` | 43, 57, 78, 155 — console.log при открытии/закрытии |
| `Dashboard.qml` | 46 — console.log при потере фокуса |

### 7.7 IdleInhibitorService — PanelWindow 0x0

**Файл**: `src/core/services/IdleInhibitorService.qml:25-38`

Некоторые Wayland-композиторы некорректно обрабатывают поверхности 0×0.

### 7.8 Notification hash — 32-bit коллизии

**Файл**: `src/core/services/NotificationService.qml:279-286`

DJB2-подобный хеш с 32-bit range для дедупликации уведомлений. При активном использовании возможны ложные коллизии.

---

## 8. Мёртвый код и пустые директории

### 8.1 Дубликаты файлов

| Файл | Дубликат/Заметка | Действие |
|---|---|---|
| `components/CalendarTab.qml` (374 строки) | Дубликат `tabs/CalendarTab.qml` | Удалить |
| `components/MediaTab.qml` | Возможный дубликат `tabs/MediaTab.qml` | Проверить и удалить |
| `components/AudioTab.qml` | Не используется в DashboardContent | Проверить |

### 8.2 Пустые директории

- `src/features/system/` — пустая
- `src/ui/display/` — пустая
- `src/ui/layout/` — пустая
- `src/ui/navigation/` — пустая

### 8.3 Мёртвый код в Config.qml

- `Config.bar.entries` (строки 245-276) — StatusBar читает из `Config.data.bar?.widgets`, entries не используется
- `Config.radius` (строка 232) — алиас на shape, legacy
- `Config.animations` (строка 426) — алиас на motion, legacy

### 8.4 Закомментированный код

| Файл | Что |
|---|---|
| `WallpaperAnalyzer.qml:1` | `// pragma Singleton` |
| `ColorService.qml` | Закомментированный `pragma Singleton` |
| `shell.qml:32-34` | PopoutsScrim |
| `Config.qml:238-239` | Закомментированный height |

---

## 9. Приоритезированный план действий

### P0 — Критично (стабильность)

- [x] McuTheme: QPointer, static buildScheme, деструктор
- [x] SystemMonitor: stopWorker fallback
- [x] QalculateWrapper: std::call_once
- [ ] LauncherService: не destroy'ить обёртки в использовании

### P1 — Высокий приоритет (архитектура + конфиг)

- [ ] **Разделить Config.qml** на DesignTokens + Theme + AppConfig
- [ ] **Привязать config.json к реальному поведению** — dashboard, notifications, launcher, osd
- [ ] **LazyLoader**: привязать loading к visibility вместо `true`
- [ ] **StackLayout → Loader**: ленивая загрузка вкладок dashboard
- [ ] **MaterialText**: pixelSize вместо pointSize
- [ ] **MaterialCard**: убрать двойное alpha
- [ ] **Удалить мёртвый код**: Config.bar.entries, дубликаты, пустые директории

### P2 — Средний приоритет (производительность + хардкод)

- [ ] **WallpaperAnalyzer → C++**: luminance в McuTheme или отдельный плагин
- [ ] **Fuzzy search → C++**: единый плагин для app/clipboard поиска
- [ ] **Убрать хардкоженные данные**: VPN name, координаты, путь к аватару, имя ОС
- [ ] **ColorService**: batch update палитры
- [ ] **StatusBar**: предвычислять filtered виджеты
- [ ] **MPRISWidget**: убрать FrameAnimation, использовать Timer MprisController
- [ ] **SystemMonitor.h**: автодетект OS/WM
- [ ] **McuTheme plugin.cpp**: убрать двойную регистрацию

### P3 — Низкий приоритет (polish)

- [ ] Dashboard tabs/sizes из config.json
- [ ] Notification settings из config.json
- [ ] NotificationPopup: visible по count
- [ ] Удалить debug console.log
- [ ] IdleInhibitor: PanelWindow 1×1
- [ ] qreal epsilon comparison
- [ ] Notification hash collision resistance
- [ ] Dashboard.qml: опечатка `sidebarHight`
- [ ] NetworkService/VPNService: nmcli monitor вместо polling

---

## 10. Сводная таблица всех проблем

| # | Приоритет | Категория | Проблема | Файл | Статус |
|---|---|---|---|---|---|
| 1 | P0 | Memory | Use-after-free в McuTheme async | McuTheme.cpp | DONE |
| 2 | P0 | Crash | qDebug из thread pool → SIGSEGV | McuTheme.cpp | DONE |
| 3 | P0 | Stability | Worker thread timeout | SystemMonitor.cpp | DONE |
| 4 | P0 | Thread Safety | Race в инициализации Calculator | QalculateWrapper.cpp | DONE |
| 5 | P0 | Memory | Destroy обёртки в использовании | LauncherService.qml | TODO |
| 6 | P1 | Architecture | Config.qml god object (469 строк) | Config.qml | TODO |
| 7 | P1 | Config | config.json не подключён к коду | Config.qml + многие | TODO |
| 8 | P1 | Performance | LazyLoader loading: true | shell.qml | TODO |
| 9 | P1 | Performance | StackLayout все вкладки активны | DashboardContent.qml | TODO |
| 10 | P1 | Visual | pointSize вместо pixelSize | MaterialText.qml | TODO |
| 11 | P1 | Visual | Двойное alpha | MaterialCard.qml | TODO |
| 12 | P1 | Dead Code | Config.bar.entries + дубликаты | Config.qml, components/ | TODO |
| 13 | P2 | Performance | WallpaperAnalyzer Canvas main thread | WallpaperAnalyzer.qml | TODO |
| 14 | P2 | Performance | JS fuzzy search per-keystroke | ApplicationProvider.qml | TODO |
| 15 | P2 | Hardcode | VPN names, coordinates, paths | VPN/Weather/UserInfo | TODO |
| 16 | P2 | Performance | ColorService cascade recalc | ColorService.qml | TODO |
| 17 | P2 | Performance | Shape + MSAA × 4 | SystemMonitoringElement | TODO |
| 18 | P2 | Performance | FrameAnimation 60fps MPRIS | MPRISWidget.qml | TODO |
| 19 | P2 | Performance | 3× JS filter в StatusBar | StatusBar.qml | TODO |
| 20 | P2 | Correctness | Theme source alpha=0 | Config.qml:25 | TODO |
| 21 | P2 | Build | Двойная регистрация QML типа | plugin.cpp | TODO |
| 22 | P2 | Portability | Hardcoded OS/WM | SystemMonitor.h | TODO |
| 23 | P3 | Resources | NotificationPopup visible: true | NotificationPopup.qml | TODO |
| 24 | P3 | Debug | console.log в production | MaterialSlider, Popouts | TODO |
| 25 | P3 | Performance | nmcli polling (5s, 10s) | VPN/NetworkService | TODO |
| 26 | P3 | Performance | BT polling 2s | BluetoothService.qml | TODO |
| 27 | P3 | Performance | Notification timer 250ms | NotificationService.qml | TODO |
| 28 | P3 | Correctness | 32-bit hash коллизии | NotificationService.qml | TODO |
| 29 | P3 | Compatibility | PanelWindow 0×0 | IdleInhibitorService.qml | TODO |
| 30 | P3 | Precision | qreal без epsilon | SystemMonitor.cpp | TODO |
| 31 | P3 | Portability | sscanf %lu для uint64_t | SystemMonitor.cpp | TODO |
| 32 | P3 | Performance | eval() блокирует GUI 100ms | QalculateWrapper.cpp | TODO |
| 33 | P3 | Code Quality | Опечатка sidebarHight | Dashboard.qml | TODO |
| 34 | P3 | Performance | AppFrequencyService sync SQLite | AppFrequencyService.qml | TODO |
| 35 | P3 | Performance | preparedEntries map on each change | ClipboardService.qml | TODO |
