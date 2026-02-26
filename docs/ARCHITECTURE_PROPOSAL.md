# Предложение по архитектуре QuickShell

> Дата: 2026-02-22
> Основано на: полный аудит проекта (FULL_PROJECT_AUDIT.md)
> Цель: упрощение поддержки, масштабируемость, конфигурируемость

---

## Содержание

1. [Текущее состояние](#1-текущее-состояние)
2. [Целевая архитектура](#2-целевая-архитектура)
3. [Фаза 1: Разделение Config.qml](#3-фаза-1-разделение-configqml)
4. [Фаза 2: Система конфигурации](#4-фаза-2-система-конфигурации)
5. [Фаза 3: Оптимизация загрузки](#5-фаза-3-оптимизация-загрузки)
6. [Фаза 4: C++ плагины](#6-фаза-4-c-плагины)
7. [Фаза 5: Очистка и polish](#7-фаза-5-очистка-и-polish)
8. [Карта зависимостей](#8-карта-зависимостей)
9. [Порядок рефакторинга](#9-порядок-рефакторинга)

---

## 1. Текущее состояние

### Граф зависимостей (упрощённый)

```
                        Config.qml (80 файлов зависят)
                       /     |      \
                  colors   tokens   config.json → data
                     |
                 McuTheme ← WallpaperService ← WallpaperAnalyzer

            GlobalStates.qml (18 файлов зависят)
                /    |     \      \
         Dashboard Launcher StatusBar NotificationCenter
```

### Ключевые метрики

| Метрика | Значение | Оценка |
|---|---|---|
| Config.qml зависимостей | 80 файлов | Критично высокое |
| GlobalStates зависимостей | 18 файлов | Высокое, но оправдано |
| Межсервисных зависимостей | 4 | Хорошо (плоский граф) |
| Сервисов-синглтонов | 22 | Много, но большинство изолированы |
| Используемых параметров config.json | 5 из 30+ | Критично низкое |

### Что работает хорошо

1. **Фичи изолированы друг от друга** — Dashboard, Launcher, Notifications, StatusBar не зависят друг от друга
2. **Сервисы в основном single-responsibility** — WallpaperService управляет обоями, NotificationService — уведомлениями
3. **Плоский граф сервисов** — минимум inter-service зависимостей
4. **UI-компоненты переиспользуются** — MaterialCard, MaterialIcon, MaterialText и т.д.
5. **StatusBar уже config-driven** — BarWidgetLoader читает из config.json

### Главные проблемы

1. **Config.qml = 3 сущности в одном файле** (469 строк, 80 зависимостей)
2. **config.json декоративный** — 85% настроек не читаются
3. **Нет ленивой загрузки** — всё грузится при старте
4. **Тяжёлые операции на main thread** — Canvas luminance, JS fuzzy search

---

## 2. Целевая архитектура

### Принципы

1. **Единый источник правды** — config.json определяет поведение, код только устанавливает defaults
2. **Разделение ответственности** — каждый модуль делает одну вещь
3. **Ленивая загрузка** — компоненты создаются только когда нужны
4. **Тяжёлое в C++** — вычисления не блокируют GUI
5. **Минимальная связанность** — зависимости явные и однонаправленные

### Целевая структура

```
~/.config/quickshell/
├── shell/
│   ├── config.json              # Пользовательский конфиг (read-only из кода)
│   ├── config/
│   │   └── default.json         # Defaults (fallback + документация)
│   └── src/
│       ├── core/
│       │   ├── config/
│       │   │   ├── AppConfig.qml      # НОВЫЙ: config.json + state.json, typed access
│       │   │   ├── DesignTokens.qml   # НОВЫЙ: MD3 константы (standalone)
│       │   │   └── Theme.qml          # НОВЫЙ: McuTheme + colors
│       │   └── services/              # Без изменений в структуре
│       │       └── ...
│       ├── features/                  # Без изменений в структуре
│       │   └── ...
│       ├── plugins/
│       │   └── src/
│       │       ├── mcu-qml/           # Существующий + luminance()
│       │       ├── qalculate-qml/     # Без изменений
│       │       ├── system-monitor-qml/# Автодетект OS/WM
│       │       └── fuzzy-search-qml/  # НОВЫЙ: C++ fuzzy search
│       └── ui/                        # Без изменений
│           └── ...
│
└── state.json                   # Runtime-состояние (read/write из кода)
```

**Ключевое разделение:**
- `config.json` — **пользователь** редактирует, код только **читает**
- `state.json` — **код** пишет автоматически (текущие обои, индексы, кэши)
- `default.json` — полный набор defaults, fallback при отсутствии config.json

### Граф зависимостей (целевой)

```
                    config.json ──→ AppConfig.qml ←── state.json
                   (read-only)    (typed access)     (read/write)
                                       ↑
                                       │ reads config
                                       │
DesignTokens.qml                 Theme.qml ──→ McuTheme (C++)
(standalone,                          ↑              ↓
 нет зависимостей)                    │        WallpaperService
     ↑                                │              ↓
     │ uses                           │ uses    AppConfig.updateState()
     │                                │              ↓
Все UI компоненты ────────────────────┘         state.json
(зависят от DesignTokens + Theme,
 НЕ от Config.qml — god object удалён)
```

---

## 3. Фаза 1: Разделение Config.qml

> Приоритет: P1 | Сложность: средняя | Влияние: высокое

Это **ключевой рефакторинг** — он уменьшает связанность с 80 файлов до 3 отдельных, более фокусированных модулей.

### 3.1 DesignTokens.qml — MD3 константы

```qml
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: tokens

    // Material Design 3 spacing (8px grid)
    readonly property QtObject spacing: QtObject {
        readonly property int none: 0
        readonly property int extraSmall: 4
        readonly property int small: 8
        readonly property int medium: 16
        readonly property int large: 24
        readonly property int extraLarge: 32
        readonly property int huge: 40
        readonly property int extraHuge: 48
    }

    // MD3 shape/radius
    readonly property QtObject shape: QtObject {
        readonly property int none: 0
        readonly property int extraSmall: 4
        readonly property int small: 8
        readonly property int medium: 12
        readonly property int large: 16
        readonly property int extraLarge: 28
        readonly property int full: 999
    }

    // MD3 elevation opacity
    readonly property QtObject elevation: QtObject { ... }

    // MD3 state layer
    readonly property QtObject stateLayer: QtObject { ... }

    // MD3 icon sizes
    readonly property QtObject iconSize: QtObject { ... }

    // MD3 touch targets
    readonly property QtObject touchTarget: QtObject { ... }

    // MD3 typography (15 стилей)
    readonly property QtObject typography: QtObject { ... }

    // MD3 motion (duration + easing)
    readonly property QtObject motion: QtObject { ... }
}
```

**Характеристики:**
- ~250 строк (вырезано из Config.qml)
- Все свойства `readonly` — гарантия иммутабельности
- Нет зависимостей — полностью standalone
- Потенциально можно перенести в C++ для снижения memory overhead

### 3.2 Theme.qml — цвета и тема

```qml
pragma Singleton
import QtQuick
import Quickshell
import Mcu 1.0
import qs.src.core.services
import qs.src.core.config

Singleton {
    id: theme

    // Состояние
    readonly property bool valid: mcuTheme.valid
    readonly property bool loading: mcuTheme.loading

    // McuTheme (C++ плагин)
    McuTheme {
        id: mcuTheme
        source: {
            if (AppConfig.themeSource === "wallpaper") {
                return WallpaperService.currentWallpaper !== ""
                    ? WallpaperService.currentWallpaper
                    : "#6750A4"  // MD3 default purple
            }
            return AppConfig.themeColor
        }
        darkMode: AppConfig.darkMode
        variant: AppConfig.themeVariant
        contrast: AppConfig.themeContrast
    }

    // Типизированные цвета (полная MD3 палитра)
    readonly property color primary: _colors.primary ?? "#6750A4"
    readonly property color onPrimary: _colors.onPrimary ?? "#FFFFFF"
    readonly property color primaryContainer: _colors.primaryContainer ?? "#EADDFF"
    // ... все 50+ цветовых ролей ...

    // Приватные данные
    property var _colors: ({})

    Connections {
        target: mcuTheme
        function onColorsChanged() {
            theme._colors = mcuTheme.colors
        }
    }

    Component.onCompleted: {
        if (mcuTheme.valid) _colors = mcuTheme.colors
    }
}
```

**Характеристики:**
- ~120 строк
- Зависит от: AppConfig (настройки темы), WallpaperService, McuTheme
- Предоставляет: типизированные `color` свойства (не `var`)
- Заменяет: `Config.colors.*`

### 3.3 AppConfig.qml — конфигурация

```qml
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: config

    // Пути и загрузка — см. полную реализацию в Фазе 2 (раздел 4.5)
    // Typed readonly properties для всех секций config.json
    // saveState() / updateState() для записи в state.json

    // === Appearance ===
    readonly property string themeSource: _data.appearance?.theme?.source ?? "wallpaper"
    readonly property bool darkMode: _data.appearance?.theme?.darkMode ?? true
    readonly property string themeVariant: _data.appearance?.theme?.variant ?? "tonalSpot"
    // ...

    // === Bar ===
    readonly property var barWidgets: _data.bar?.widgets ?? []
    readonly property int barHeight: _data.bar?.height ?? 48
    // ...

    // === Dashboard, Notifications, Launcher, OSD, Services ===
    // ... (typed readonly properties с defaults)

    // === Wallpaper config (из config.json) ===
    readonly property var wallpaperMonitors: _data.wallpaper?.monitors ?? ({})
    readonly property bool wallpaperAutoChange: _data.wallpaper?.global?.autoChange?.enabled ?? false
    // ...

    // === Wallpaper state (из state.json, read/write) ===
    readonly property var wallpaperState: _state.wallpaper ?? ({})
    function updateState(section, data) { /* ... пишет в state.json */ }
}
```

**Характеристики:**
- ~150 строк
- **Два FileView**: config.json (watchChanges) + state.json
- Типизированный доступ: readonly properties с defaults для config.json
- `saveState()` / `updateState()` для записи в state.json
- Нет design tokens, нет цветов — только конфигурация и состояние
- Полная реализация описана в Фазе 2 (раздел 4.5)

### 3.4 План миграции

Config.qml удаляется сразу — без proxy и обратной совместимости.

**Шаг 1**: Создать 3 новых файла (DesignTokens, Theme, AppConfig).

**Шаг 2**: Обновить все 80 файлов, заменив импорты:
```
// Было:
Config.spacing.medium       →  DesignTokens.spacing.medium
Config.shape.large          →  DesignTokens.shape.large
Config.typography.bodyLarge →  DesignTokens.typography.bodyLarge
Config.motion.duration.medium2 → DesignTokens.motion.duration.medium2
Config.colors.primary       →  Theme.primary
Config.colors.onSurface     →  Theme.onSurface
Config.data.bar?.widgets    →  AppConfig.barWidgets
Config.bar.height           →  AppConfig.barHeight
Config.weather.location     →  AppConfig.weatherLocation
Config.ready                →  AppConfig.ready
```

Порядок миграции:
1. `src/ui/` (28 файлов) — зависят только от DesignTokens + Theme
2. `src/core/services/` (5 файлов с Config) — зависят от AppConfig
3. `src/features/` (47+ файлов) — зависят от всех трёх

**Шаг 3**: Удалить Config.qml.

---

## 4. Фаза 2: Система конфигурации (config.json + state.json)

> Приоритет: P1 | Сложность: средняя | Влияние: высокое

### 4.1 Разделение: конфигурация vs состояние

**Принцип**: пользователь редактирует `config.json`, код пишет только в `state.json`.

```
~/.config/quickshell/
├── shell/
│   ├── config.json          # Пользовательский конфиг (read-only из кода)
│   └── config/
│       └── default.json     # Defaults (fallback при отсутствии config.json)
│
└── state.json               # Runtime-состояние (read/write из кода)
```

#### config.json — что редактирует пользователь

Всё, что пользователь настраивает осознанно:
- Appearance (тема, анимации, прозрачность)
- Bar (виджеты, позиция, высота)
- Dashboard (вкладки, размеры)
- Notifications (timeout, позиция, maxVisible)
- Launcher (провайдеры, maxResults, fuzzy)
- OSD (timeout, позиция)
- Wallpaper (**настройки**: директории per-monitor, fillMode, autoChange, postSetScript)
- Services (weather location, VPN name, calendar)
- Hyprland (workspaceCount)

#### state.json — что меняет код автоматически

Runtime-состояние, которое не имеет смысла редактировать вручную:
- Текущие обои per-monitor (пути к файлам)
- Индексы сканирования директорий
- Кэш списка файлов обоев
- Последнее используемое значение (для восстановления после рестарта)

### 4.2 Целевая структура config.json

```json
{
  "version": 1,

  "appearance": {
    "theme": {
      "source": "wallpaper",
      "color": "#6750A4",
      "variant": "vibrant",
      "darkMode": true,
      "contrast": 0.0
    },
    "animations": {
      "enabled": true,
      "durationScale": 1.0
    },
    "transparency": {
      "enabled": true,
      "default": 0.85,
      "cards": 0.80,
      "dialogs": 0.90
    }
  },

  "bar": {
    "enabled": true,
    "position": "top",
    "height": 48,
    "margin": 16,
    "widgets": [ ... ]
  },

  "dashboard": { ... },
  "notifications": { ... },
  "launcher": { ... },
  "osd": { ... },

  "wallpaper": {
    "primaryMonitor": "DP-2",
    "defaultWallpaper": "/path/to/default.jpg",
    "postSetScript": "",
    "global": {
      "directory": "",
      "randomOrder": true,
      "autoChange": {
        "enabled": true,
        "intervalMs": 900000
      }
    },
    "monitors": {
      "DP-2": {
        "directory": "/home/user/wallpapers/3440x1440",
        "fillMode": 2
      },
      "DP-1": {
        "directory": "/home/user/wallpapers/1080x1920",
        "fillMode": 2
      }
    }
  },

  "services": {
    "weather": {
      "enabled": true,
      "location": "Penza",
      "units": "metric",
      "refreshMinutes": 15
    },
    "vpn": {
      "enabled": false,
      "name": ""
    },
    "calendar": {
      "enabled": true,
      "upcomingEventsCount": 2
    }
  },

  "hyprland": {
    "workspaceCount": 10,
    "perMonitor": true
  }
}
```

### 4.3 Целевая структура state.json

```json
{
  "version": 1,

  "wallpaper": {
    "monitors": {
      "DP-2": {
        "current": "/home/user/wallpapers/3440x1440/image.jpg",
        "index": 5
      },
      "DP-1": {
        "current": "/home/user/wallpapers/1080x1920/photo.jpg",
        "index": 3
      }
    },
    "fileCache": {
      "/home/user/wallpapers/3440x1440": ["img1.jpg", "img2.jpg", "..."],
      "/home/user/wallpapers/1080x1920": ["photo1.jpg", "photo2.jpg", "..."]
    }
  }
}
```

### 4.4 default.json — полный набор defaults

`config/default.json` должен содержать **все** возможные настройки с разумными значениями по умолчанию. Это:
- Документация в виде кода — пользователь видит все доступные опции
- Fallback при отсутствии config.json
- Эталон для валидации (в будущем)

### 4.5 AppConfig.qml — загрузка обоих файлов

```qml
pragma Singleton
import Quickshell
import Quickshell.Io

Singleton {
    id: config

    // Пути
    readonly property string configDir: Quickshell.env("XDG_CONFIG_HOME")
        || (Quickshell.env("HOME") + "/.config")
    readonly property string shellDir: configDir + "/quickshell/shell"
    readonly property string configPath: shellDir + "/config.json"
    readonly property string statePath: configDir + "/quickshell/state.json"
    readonly property string defaultConfigPath:
        Qt.resolvedUrl("../../../config/default.json").toString().replace("file://", "")

    // Готовность
    property bool ready: false
    property var _data: ({})
    property var _state: ({})

    // === Typed config properties (readonly) ===
    // ... (appearance, bar, dashboard, etc. — как в Фазе 1)

    // === Wallpaper config (readonly — пользовательские настройки) ===
    readonly property string wallpaperPrimaryMonitor:
        _data.wallpaper?.primaryMonitor ?? ""
    readonly property string wallpaperDefaultPath:
        _data.wallpaper?.defaultWallpaper ?? ""
    readonly property string wallpaperPostScript:
        _data.wallpaper?.postSetScript ?? ""
    readonly property bool wallpaperAutoChange:
        _data.wallpaper?.global?.autoChange?.enabled ?? false
    readonly property int wallpaperAutoChangeInterval:
        _data.wallpaper?.global?.autoChange?.intervalMs ?? 300000
    readonly property bool wallpaperRandomOrder:
        _data.wallpaper?.global?.randomOrder ?? true
    readonly property var wallpaperMonitors:
        _data.wallpaper?.monitors ?? ({})

    // === State (read/write — runtime) ===
    readonly property var wallpaperState: _state.wallpaper ?? ({})

    // --- FileView для config.json ---
    FileView {
        id: configFile
        path: config.configPath
        watchChanges: true
        onLoaded: { config._data = config._parse(text()); config._checkReady() }
        onLoadFailed: { config._loadDefault() }
        onFileChanged: reload()
    }

    // --- FileView для state.json ---
    FileView {
        id: stateFile
        path: config.statePath
        watchChanges: false
        onLoaded: { config._state = config._parse(text()); config._checkReady() }
        onLoadFailed: { config._state = {}; config._checkReady() }
    }

    // --- FileView для default.json ---
    FileView {
        id: defaultFile
        onLoaded: { config._data = config._parse(text()); config._checkReady() }
        onLoadFailed: { config._data = {}; config._checkReady() }
    }

    function _parse(text) {
        try { return JSON.parse(text) || {} }
        catch (e) { console.warn("AppConfig: parse error:", e); return {} }
    }

    function _loadDefault() {
        defaultFile.path = config.defaultConfigPath
    }

    function _checkReady() {
        if (!config.ready) {
            config.ready = true
        }
    }

    // === Запись state.json ===
    function saveState(newState) {
        config._state = newState
        stateFile.setText(JSON.stringify(newState, null, 2))
    }

    // Обновить конкретную секцию state
    function updateState(section, data) {
        let s = JSON.parse(JSON.stringify(config._state))
        s[section] = data
        saveState(s)
    }
}
```

### 4.6 WallpaperService — миграция на AppConfig

Текущий WallpaperService читает/пишет `wallpaper.json` напрямую. После миграции:

```
Чтение настроек:  WallpaperService → AppConfig.wallpaperMonitors (из config.json)
Чтение состояния: WallpaperService → AppConfig.wallpaperState (из state.json)
Запись состояния: WallpaperService → AppConfig.updateState("wallpaper", {...})
```

Это позволит:
1. Убрать дублирование (одна секция wallpaper в config.json вместо двух файлов)
2. WallpaperService не управляет своим конфигом — читает из AppConfig
3. Runtime-состояние (текущий wallpaper, индексы) пишется в state.json
4. Пользователь редактирует wallpaper-настройки в config.json (директории, autoChange, fillMode)

### 4.7 Подключение config.json к поведению

После создания AppConfig.qml, заменить хардкоженные значения в фичах:

| Файл | Было | Стало |
|---|---|---|
| `Dashboard.qml:14-15` | `sidebarWidth: 900` | `sidebarWidth: AppConfig.dashboardWidth` |
| `DashboardContent.qml:40-57` | Хардкоженный массив вкладок | `Repeater { model: AppConfig.dashboardTabs }` |
| `DashboardContent.qml:88-96` | `requestHeightChange(640)` | Динамическая высота от контента |
| `NotificationPopup.qml` | `maxVisible: 5` | `maxVisible: AppConfig.notificationPopupMaxVisible` |
| `VPNService.qml:15` | `"diasoft_VPN"` | `AppConfig.vpnName` |
| `Weather.qml:12-13` | `53.2, 45.0` | Геокодинг или конфиг |
| `WallpaperService` | Свой `wallpaper.json` | `AppConfig.wallpaperMonitors` + `AppConfig.updateState()` |

### 4.8 Dashboard tabs из config.json

Текущий хардкод в DashboardContent.qml:
```qml
Repeater {
    model: [
        { icon: "dashboard", label: "Quick" },
        { icon: "partly_cloudy_day", label: "Weather" },
        ...
    ]
}
```

Целевой вариант:
```qml
Repeater {
    model: AppConfig.dashboardTabs
    delegate: TabButton {
        nameIcon: modelData.icon
        label: modelData.name
        onClicked: tabView.currentIndex = index
    }
}

// Tab content через Loader
StackLayout {
    Repeater {
        model: AppConfig.dashboardTabs
        delegate: Loader {
            active: tabView.currentIndex === index
            sourceComponent: _tabComponent(modelData.id)
        }
    }
}

function _tabComponent(id) {
    switch (id) {
        case "quick": return quickTabComponent
        case "weather": return weatherTabComponent
        case "calendar": return calendarTabComponent
        case "system": return systemTabComponent
        default: return null
    }
}
```

---

## 5. Фаза 3: Оптимизация загрузки

> Приоритет: P1 | Сложность: низкая | Влияние: среднее

### 5.1 LazyLoader — привязка к видимости

```qml
// shell.qml — было:
LazyLoader { loading: true; Dashboard {} }

// Стало:
LazyLoader { loading: GlobalStates.dashboardOpen; Dashboard {} }
LazyLoader { loading: GlobalStates.osdVolumeOpen; VolumeOSD {} }
LazyLoader { loading: GlobalStates.launcherOpen; Launcher {} }
LazyLoader { loading: NotificationService.activeList.count > 0; NotificationPopup {} }
LazyLoader { loading: GlobalStates.notificationCenterOpen; NotificationCenter {} }
```

### 5.2 StackLayout → Loader для вкладок

```qml
// DashboardContent.qml — было:
StackLayout {
    QuickTab {}     // Всегда создан
    WeatherTab {}   // Всегда создан
    CalendarTab {}  // Всегда создан
    SystemTab {}    // Всегда создан
}

// Стало:
StackLayout {
    id: tabView
    Loader { active: tabView.currentIndex === 0; sourceComponent: QuickTab {} }
    Loader { active: tabView.currentIndex === 1; sourceComponent: WeatherTab {} }
    Loader { active: tabView.currentIndex === 2; sourceComponent: CalendarTab {} }
    Loader { active: tabView.currentIndex === 3; sourceComponent: SystemTab {} }
}
```

### 5.3 NotificationPopup — visible по count

```qml
// Было:
PanelWindow { visible: true; implicitHeight: count > 0 ? h : 0 }

// Стало:
PanelWindow { visible: NotificationService.activeList.count > 0 }
```

---

## 6. Фаза 4: C++ плагины

> Приоритет: P2 | Сложность: средняя | Влияние: среднее

### 6.1 Расширение McuTheme — luminance

Добавить к McuTheme метод вычисления luminance из изображения, заменив WallpaperAnalyzer.qml:

```cpp
// McuTheme.h — добавить:
Q_PROPERTY(qreal luminance READ luminance NOTIFY luminanceChanged)

Q_INVOKABLE void computeLuminance(const QUrl& imageUrl);

// McuTheme.cpp — реализация в thread pool:
void McuTheme::computeLuminance(const QUrl& url) {
    QtConcurrent::run([guard = QPointer<McuTheme>(this), url]() {
        QImage img = readDownscaled(url.toLocalFile(), 32);
        if (img.isNull()) return;

        double sum = 0;
        int count = 0;
        for (int y = 0; y < img.height(); ++y) {
            const QRgb* row = reinterpret_cast<const QRgb*>(img.constScanLine(y));
            for (int x = 0; x < img.width(); ++x) {
                double r = qRed(row[x]) / 255.0;
                double g = qGreen(row[x]) / 255.0;
                double b = qBlue(row[x]) / 255.0;
                sum += 0.2126 * r + 0.7152 * g + 0.0722 * b;
                ++count;
            }
        }

        double lum = count > 0 ? sum / count : 0.5;

        auto* app = QCoreApplication::instance();
        if (!app) return;
        QMetaObject::invokeMethod(app, [guard, lum]() {
            if (!guard) return;
            guard->m_luminance = lum;
            emit guard->luminanceChanged();
        }, Qt::QueuedConnection);
    });
}
```

После этого WallpaperAnalyzer.qml можно удалить.

### 6.2 C++ fuzzy search плагин

```cpp
// FuzzySearch.h
class FuzzySearch : public QObject {
    Q_OBJECT
    QML_ELEMENT

public:
    // Возвращает отсортированный список индексов с оценками
    Q_INVOKABLE QVariantList search(
        const QString& query,
        const QStringList& candidates,
        int maxResults = 10
    ) const;
};
```

Алгоритм: Smith-Waterman или fzf-like scoring. Один плагин для лаунчера и буфера обмена.

### 6.3 SystemMonitor — автодетект OS/WM

```cpp
// SystemMonitor.h — вместо hardcoded:
QString osName() const {
    // Читать /etc/os-release один раз при старте
    return m_osName;
}

QString wmName() const {
    // Читать $XDG_CURRENT_DESKTOP или $DESKTOP_SESSION
    return m_wmName;
}

// В конструкторе:
void SystemMonitor::detectSystem() {
    // OS
    QFile f("/etc/os-release");
    if (f.open(QIODevice::ReadOnly)) {
        // parse PRETTY_NAME=...
    }
    // WM
    m_wmName = qEnvironmentVariable("XDG_CURRENT_DESKTOP", "Unknown");
}
```

---

## 7. Фаза 5: Очистка и polish

> Приоритет: P3 | Сложность: низкая | Влияние: низкое

### 7.1 Удалить мёртвый код

- [ ] `components/CalendarTab.qml` (дубликат `tabs/CalendarTab.qml`)
- [ ] `components/MediaTab.qml` (если дубликат)
- [ ] `Config.bar.entries` (мёртвый код, StatusBar читает из config.json)
- [ ] `Config.radius` (alias на shape)
- [ ] `Config.animations` (alias на motion)
- [ ] `Config.vpnName` (переместить в AppConfig)
- [ ] Пустые директории: system/, display/, layout/, navigation/

### 7.2 Удалить debug logging

- [ ] `MaterialSlider.qml:99-103` — console.log при движении
- [ ] `Popouts.qml:43,57,78,155` — console.log при открытии/закрытии
- [ ] `Dashboard.qml:46` — console.log при потере фокуса

### 7.3 Исправить визуальные баги

- [ ] `MaterialText.qml` — `font.pixelSize` вместо `font.pointSize`
- [ ] `MaterialCard.qml` — убрать внутреннее `Qt.alpha(color, 0.85)`, оставить контроль прозрачности на вызывающей стороне
- [ ] `Config.qml:25` — fallback `"#6750A4"` вместо `Qt.alpha("#6200EE", 0)`
- [ ] `Dashboard.qml:15` — опечатка `sidebarHight` → `sidebarHeight`

### 7.4 Прочие улучшения

- [ ] `MPRISWidget.qml` — удалить FrameAnimation, использовать Timer из MprisController
- [ ] `NotificationPopup.qml` — `visible: count > 0`
- [ ] `IdleInhibitorService.qml` — PanelWindow 1×1
- [ ] `StatusBar.qml` — предвычислять left/center/right массивы

---

## 8. Карта зависимостей

### Текущая (упрощённая)

```
Config.qml (god object, 469 строк)
├── Импортируется 80 файлами
├── Содержит: tokens + config + theme + colors + bar + vpnName
├── Зависит от: McuTheme, WallpaperService, GlobalStates
└── Проблема: любое изменение = потенциальный риск для 80 файлов

GlobalStates.qml
├── Импортируется 18 файлами
├── Содержит: UI state + shortcuts + IPC + auto-close logic
└── Оценка: приемлемо, единая роль (UI state management)
```

### Целевая

```
DesignTokens.qml (~250 строк, readonly)
├── Импортируется: ~40 файлами (UI компоненты + features)
├── Содержит: ТОЛЬКО MD3 константы
├── Зависит от: НИЧЕГО
└── Риск изменений: нулевой (константы не меняются)

Theme.qml (~120 строк)
├── Импортируется: ~40 файлами (те же + services)
├── Содержит: McuTheme + типизированные цвета
├── Зависит от: AppConfig, McuTheme (C++), WallpaperService
└── Риск изменений: низкий (стабильный API)

AppConfig.qml (~120 строк)
├── Импортируется: ~20 файлами (services + features, НЕ UI)
├── Содержит: загрузка JSON + typed properties + defaults
├── Зависит от: НИЧЕГО (только FileView)
└── Риск изменений: средний (при добавлении настроек)

GlobalStates.qml (без изменений)
├── Импортируется: 18 файлами
└── Оценка: оставить как есть
```

### Зависимости сервисов (актуальная карта)

```
Tier 1 — используются 10+ файлами:
  DesignTokens ← 40 файлов (UI + features)
  Theme ← 40 файлов (UI + features)
  AppConfig ← 20 файлов (services + features)
  GlobalStates ← 18 файлов (features)

Tier 2 — используются 3-9 файлами:
  NotificationService ← 5 файлов (notifications + statusbar)
  AudioService ← 5 файлов (dashboard + statusbar)
  MprisController ← 4 файла (statusbar + dashboard)
  Weather ← 3 файла (dashboard + statusbar)
  WallpaperService ← 3 файла (background + analyzer + theme)

Tier 3 — используются 1-2 файлами:
  SystemMonitorService ← 2 (dashboard)
  NetworkService ← 2 (statusbar + dashboard)
  PopoutsState ← 2 (popouts)
  CalendarService ← 1 (dashboard calendar tab)
  ClipboardService ← 1 (launcher clipboard provider)
  LauncherService ← 1 (launcher)
  BluetoothService ← 1 (dashboard quick actions)
  VPNService ← 1 (dashboard quick actions)
  IdleInhibitorService ← 1 (dashboard quick actions)
  DateTime ← 1 (dashboard user info)
  AppFrequencyService ← 1 (launcher app provider)
  WeatherIcons ← 1 (Weather service)
  IconCategoryResolver ← 1 (notifications)

Standalone (не импортируются напрямую):
  ColorService — indirect через Config/Theme
  WallpaperAnalyzer — indirect через ColorService
  HyprlandWindowService — implicit через shell.qml
```

---

## 9. Порядок рефакторинга

### Этап 1: Разделение Config.qml и миграция импортов

1. **Создать DesignTokens.qml** — вырезать MD3 токены из Config.qml
2. **Создать Theme.qml** — вырезать цвета/McuTheme из Config.qml
3. **Создать AppConfig.qml** — config.json + state.json, typed properties
4. **Обновить default.json** — полный набор всех настроек с defaults
5. **Мигрировать src/ui/** (28 файлов) — `Config.spacing` → `DesignTokens.spacing`, `Config.colors.*` → `Theme.*`
6. **Мигрировать src/core/services/** (5 файлов) — `Config.data.*` → `AppConfig.*`
7. **Мигрировать src/features/** (47+ файлов) — оба типа замен
8. **Удалить Config.qml** — без proxy, сразу

### Этап 2: Подключение config.json + state.json

9. **Dashboard**: размеры, вкладки из AppConfig
10. **Notifications**: timeout, maxVisible из AppConfig
11. **Launcher**: maxResults, providers из AppConfig
12. **VPN**: name из AppConfig
13. **WallpaperService**: настройки из `AppConfig.wallpaperMonitors`, состояние через `AppConfig.updateState("wallpaper", {...})`
14. **Перенести wallpaper настройки** из wallpaper.json в config.json
15. **Удалить wallpaper.json** — заменён на config.json + state.json
16. Удалить все хардкоженные значения (VPN name, координаты, пути, размеры)

### Этап 3: Ленивая загрузка

17. **LazyLoader**: loading привязать к видимости
18. **StackLayout → Loader**: ленивые вкладки dashboard
19. **NotificationPopup**: visible по count

### Этап 4: Очистка

20. Удалить мёртвый код (дубликаты CalendarTab/MediaTab, Config.bar.entries, legacy aliases)
21. Удалить пустые директории (system/, display/, layout/, navigation/)
22. Удалить debug console.log (MaterialSlider, Popouts, Dashboard)
23. Исправить MaterialText (pixelSize), MaterialCard (двойное alpha), theme fallback
24. Опечатка `sidebarHight` → `sidebarHeight`

### Этап 5: C++ плагины (по необходимости)

25. McuTheme.luminance() — заменить WallpaperAnalyzer.qml
26. FuzzySearch плагин — заменить JS search в лаунчере/буфере обмена
27. SystemMonitor — автодетект OS/WM из /etc/os-release и $XDG_CURRENT_DESKTOP

---

## Приложение: Оценка рисков

| Изменение | Риск регрессии | Способ снижения |
|---|---|---|
| Разделение Config + миграция 80 файлов | Средний | Простой find-replace: Config.X → Module.X |
| config.json + state.json | Средний | Миграция wallpaper.json данных при первом запуске |
| Подключение config.json к фичам | Низкий | Defaults совпадают с текущим хардкодом |
| WallpaperService → AppConfig | Средний | Единственный сервис с записью состояния |
| LazyLoader | Низкий | Не меняет логику, только время создания |
| StackLayout → Loader | Низкий | Tab state сохраняется через GlobalStates |
| Удаление мёртвого кода | Нулевой | Код не используется |
| C++ плагины | Средний | Параллельная реализация, постепенная замена |
