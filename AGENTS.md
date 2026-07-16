# AGENTS.md — shell (Quickshell / Hyprland)

> **Единый источник правды по конвенциям проекта.** Любой агент или контрибьютор
> читает этот файл ПЕРЕД изменением кода. `CLAUDE.md` — краткая выжимка для Claude
> Code и ссылается сюда.

**Проект:** `shell` — desktop shell для Hyprland на Quickshell
**Фреймворк:** Quickshell (QML/Qt 6) + 5 собственных C++ плагинов
**Языки:** QML, C++17, немного shell-скриптов
**Композитор:** Hyprland (жёстко; используется `Quickshell.Hyprland`, `hyprctl`, ext-global-shortcuts)

---

## 0. НЕПРЕЛОЖНЫЕ ВЕКТОРЫ (приоритеты при любом решении)

Любое изменение оценивается в этом порядке. Если они конфликтуют — приоритет выше у того, кто выше в списке.

1. **Корректность (Correctness).** Никаких утечек, гонок, use-after-free, зомби-процессов, нереактивных биндингов. UI не должен падать.
2. **Производительность (Performance).** UI-поток обязан оставаться неблокирующим (цель — 100% non-blocking UI). Тяжёлое/синхронное/парсинг — в C++. Никакого лишнего спавна процессов и таймеров.
3. **Безопасность (Safety).** Никакой конкатенации в shell-команды, проверка ввода, аккуратный жизненный цикл процессов и файлов, корректный focus-grab для модальностей.
4. **Следование Material Design 3 (MD3).** Цвет, типографика, форма, motion, state layers, elevation — только через `Theme` и `Tokens`. Никакого ad-hoc стиля.

Эти четыре пункта — критерий приёмки. Изменение, которое улучшает фичу, но нарушает любой из них, не принимается.

**Сквозной принцип: config-first, без GUI.** Проект настраивается ТОЛЬКО через `config.json`
(+ `config.schema.json` для автодополнения/валидации в редакторе) и действия через IPC
(`qs ipc call …`). GUI-настроек в проекте **не будет** — это осознанный дизайн-выбор
(tiling-WM минимализм). Schema + полные дефолты + миграции конфига — это и есть «интерфейс
настроек». Чем меньше GUI-конфигурирования, тем лучше.

---

## 1. Обзор проекта

`shell` — конфигурация Quickshell, реализующая бар, док, дашборд, лаунчер, уведомления,
OSD, скриншоты, локскрин, powermenu, cheatsheet и динамическую тему из обоев. Управляется
JSON-конфигом с hot-reload и JSON Schema. Тяжёлая логика вынесена в 5 C++ плагинов.

Проект вдохновлён Caelestia, но реализован самостоятельно (своя слоёная архитектура и своя
MD3-библиотека компонентов). Это **не форк** — заимствования точечные и атрибутированы в коде.

---

## 2. Технологический стек и зависимости

| Слой | Технология |
|---|---|
| UI | Qt 6 (QtQuick, Controls, Layouts, Effects) + Quickshell |
| Нативные сервисы | `Quickshell.Services.Pipewire`, `.Mpris`, `Quickshell.Networking`, `Quickshell.Bluetooth`, `Quickshell.Services.Notifications` |
| Композитор | `Quickshell.Hyprland`, `hyprctl`, ext-global-shortcuts |
| Конфиг | `Quickshell.Io.FileView` (JSON) + `config/config.schema.json` |
| Нативная логика | 5 C++ плагинов (Qt 6.5+, C++17, CMake + Ninja) |
| Цвет | C++ плагин `Mcu` (Material Color Utilities, сабмодуль) |

**Внешние CLI** (только там, где нет нативного API): `ddcutil`, `grim`, `wl-copy`, `swappy`,
`cliphist`, `nmcli` (eth/vpn), `hyprsunset`, `hyprctl`, `gdbus`, `systemctl`.

---

## 3. Архитектура и слои

```
shell.qml                     # ShellRoot: Variants per-screen + глобальные оверлеи (LazyLoader)
src/
├── core/
│   ├── config/               # AppConfig, Theme, Tokens  (НЕ зависит от features/ui)
│   └── services/             # 33 singleton-сервиса + GlobalStates  (зависит только от config)
├── features/                 # бар, док, дашборд, лаунчер, ... — оркестрирует config+services+ui
├── ui/                       # MD3-библиотека: base/ containers/ feedback/ inputs/  (зависит ТОЛЬКО от config)
└── plugins/                  # C++ плагины (требуют сборки) + external/material-color-utilities (сабмодуль)
```

### Импорты (точные namespace)
- `import qs.src.core.config` — `Theme`, `Tokens`, `AppConfig`
- `import qs.src.core.services` — все сервисы и `GlobalStates`
- `import qs.src.ui.base` / `.containers` / `.feedback` / `.inputs`
- `import qs.src.features.<feature>`

### Направление зависимостей — однонаправленное, без обратных рёбер
```
plugins (C++)  ←  config  ←  services  ←  features
                    ↑___________ui_____________↑
```
**Правила (нарушать нельзя):**
- `ui/*` зависит **только** от `config` (Theme/Tokens). **`ui` НИКОГДА не импортирует `services`** — UI-компоненты чистые, без бизнес-логики.
- `services/*` зависит от `config`, но **не от `ui`**.
- `features/*` — единственный слой, который импортирует всё (оркестрация).
- Новые сервисы — `pragma Singleton`, регистрируются в init-последовательности; новые UI-компоненты — в `src/ui/*` с записью в соответствующий `qmldir`.

---

## 4. Сборка, запуск, проверка

```bash
# Сборка C++ плагинов (обязательна — без них import Mcu/Calendar/... падает)
cd src/plugins
cmake -B build -S . -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/
cmake --build build
sudo cmake --install build          # ставит в /usr/lib/qt6/qml/

# Запуск
quickshell -p ~/.config/quickshell/shell        # (сокращённо: qs -p ...)
QT_QPA_PLATFORMTHEME=gtk3 qs -p ~/.config/quickshell/shell   # фактический паттерн запуска

# Внешнее управление
qs ipc call <handler> <function> [arg]

# Линт (требование: qmllint clean на всех изменённых QML)
tools/lint.sh <files...>      # обёртка qmllint с import-путями qs.* (.qmllint-imports/)

# Инварианты запретов §10 + ratchet-базлайн (tools/check-baseline.txt)
tools/check.sh                # exit 1 = регресс; после снижения долга: --update-baseline
```

Автотестов на QML нет; для C++ плагинов пишутся unit-тесты. Перед коммитом изменённый QML
обязан проходить `qmllint` без предупреждений.

---

## 5. Тема и MD3 — цвет, токены

### Цвет — `src/core/config/Theme.qml` (singleton)
- Палитра генерируется C++ плагином: `import Mcu 1.0` → `McuTheme { source: <обои>; darkMode; variant; contrast: 0.5 }`.
- Цвета экспонируются как **плоские `property color`** прямо на `Theme`.
- **Единственно верный способ обратиться к цвету:**
  ```qml
  color: Theme.primary                         // статически
  color: Theme[colorRole] || Theme.onSurface   // динамически по имени роли
  color: Qt.alpha(Theme.surfaceContainer, 0.90) // полупрозрачность — ТОЛЬКО так
  ```
- Доступны все M3 color-roles: `primary/onPrimary/primaryContainer/...`, `surface`,
  `surfaceContainer{Lowest,Low,High,Highest}`, `surfaceVariant`, `outline`, `outlineVariant`,
  `error*`, `inverse*`, `*Fixed*`, `shadow`, `scrim`, `surfaceTint`, плюс `scrimForeground`.

> ⚠️ `ColorService`, `ColorService.layer()`, `palette`/`tPalette` **в коде НЕ существуют**
> (незавершённый, не реализованный план миграции). Не используй их. Реальность — `Theme.<role>` + `Qt.alpha(...)`.

### Токены — `src/core/config/Tokens.qml` (singleton, зависит НИ ОТ ЧЕГО)
Все размеры/формы/типографика/motion/elevation берутся отсюда. Точные группы:
- `Tokens.spacing` — 8px-сетка (`none/extraSmall(4)/small(8)/medium(16)/large(24)/extraLarge(32)/huge/extraHuge`).
- `Tokens.shape` — радиусы (`extraSmall(4)…extraLarge(28)/full(999)/button(999)`).
- `Tokens.typography.<style>` — `displayLarge…/headline…/title…/label…/body…`, поля `{size,lineHeight,weight,letterSpacing}`; размеры масштабируются `fontScale`.
- `Tokens.motion.duration.*` (`short1..4/medium1..4/long1..4/extraLong1..4`, масштаб `durationScale`) и `Tokens.motion.easing.*` (`standard/emphasized/emphasizedDecelerate/emphasizedAccelerate` + `*Points`).
- `Tokens.stateLayer` (`hover 0.08 / pressed 0.12 / focus 0.12 / dragged 0.16`), `Tokens.state` (disabled 0.12/0.38).
- `Tokens.elevation.level(n)` (0–5) → `{surfaceRole, shadowRadius, shadowVerticalOffset, shadowOpacity}`. **Elevation выражается тоном поверхности + тенью, НЕ прозрачностью.**
- `Tokens.iconSize`, `Tokens.touchTarget.minimum(48)`, `Tokens.focusRing`.

### Правила MD3
- Текст — `MaterialText { textStyle: "bodyMedium"; colorRole: "onSurface" }`; `font.pixelSize` (НЕ `pointSize`), `Text.NativeRendering`.
- Анимации — `easing.type: Tokens.motion.easing.emphasized; easing.bezierCurve: Tokens.motion.easing.emphasizedPoints`. Длительности — из `Tokens.motion.duration`.
- Поверхности с тенью/«высотой» — `Surface { elevation: n }` / `MaterialCard`. Меню MD3 = elevation level 2.
- State layers (hover/pressed/focus) — `StateLayer` с `Tokens.stateLayer.*`.
- Вложенные поверхности → выше surfaceContainer-тон (больше emphasis).

---

## 6. UI-компоненты — `src/ui/`

Готовые MD3-примитивы. В `features/` собирай UI **только из них**, а не из сырых `Rectangle`/`Text`.

- **base/** — `MaterialText`, `MaterialIcon`, `MaterialButton`, `IconButton`, `FAB`, `MaterialIndicator`, `SectionHeader`, `CircleAvatar`, `Sparkline`, `MaterialMarqueeText`.
- **containers/** — `Surface`, `MaterialCard`, `BarElement`, `ListItem`, `Divider`, `ScrollableList`, `CollapsibleSection`.
- **feedback/** — `StateLayer`, `Dialog`, `Snackbar`, `Badge`, `ProgressIndicator`, `MaterialMenu`, `TooltipManager`/`TooltipItem`, `EmptyState`.
- **inputs/** — `MaterialSlider`, `MaterialSwitch`, `MaterialCheckbox`, `MaterialRadioButton`, `MaterialComboBox`, `MaterialTextField`, `SegmentedButton`, `Chip`.

Сырые `Rectangle`/`Text` допустимы **только внутри `src/ui/*`** (это их реализация). В `src/features/*` — нет.

---

## 7. Слой сервисов — `src/core/services/`

Паттерн «Reactive Singleton»: `pragma Singleton` (+ часто `pragma ComponentBehavior: Bound`),
внутреннее состояние из асинхронных системных вызовов, наружу — реактивные `property`.

### Источник данных: нативное > подпроцесс
- **Нативный Quickshell API — всегда, когда он есть:** аудио → `Pipewire`; медиа → `Mpris`; Wi-Fi → `Networking`; Bluetooth → `Bluetooth`; уведомления → `Services.Notifications`.
- **`Process` + CLI — только когда нативного API нет:** яркость (`ddcutil`), скриншоты (`grim`/`wl-copy`/`swappy`), буфер (`cliphist`), night light (`hyprsunset`), Ethernet/VPN (`nmcli`), питание/лок (`systemctl`/`hyprctl`/`gdbus`).
- Цель (ROADMAP): мигрировать подпроцессы на нативный D-Bus (`Quickshell.Io.DBus`), эталон — `MprisController`.

### Конвенции
- Свойства lowerCamelCase, реактивные (`masterVolume`, `isCharging`, `available`); методы-команды `setX/toggleX/increase/decrease`; сигналы — действие/прошедшее время (`volumeChanged`, `brightnessAdjusted`); приватное — префикс `_`.
- Системный stdout — `Process` + `SplitParser`/`StdioCollector`, обработка построчно.
- Списки/модели внутри `Process.onStdout` менять только через `Qt.callLater()`.
- Всегда безопасный fallback (`available: device !== null`).

---

## 8. Состояние, конфиг, IPC

> **Config-first (см. раздел 0).** Единственный интерфейс настройки — `config.json` + `config.schema.json`;
> действия — через IPC. GUI-настройки запрещены. Новую конфигурируемость добавляй как: поле в
> `config.json` → запись в `config.schema.json` (с `description`) → дефолт в `default.json` →
> типизированный геттер в `AppConfig.qml`. «Пресеты»/«схемы» — это JSON-данные + применение по IPC,
> а не GUI-пикер. Schema, полные дефолты и миграции — приоритет инвестиций (это заменяет GUI).

### Два файла, строго разделённых
- **`config.json`** (`$XDG_CONFIG_HOME/quickshell/config.json`, fallback `config/default.json`) — **пользователь редактирует, код только читает.** `FileView { watchChanges: true }` → hot-reload. Есть `config/config.schema.json` (draft-07) — авторитетная справка по конфигу; обновляй её при добавлении ключей.
- **`state.json`** — **runtime-состояние, пишет только код** (gaming mode, текущие обои, порядок пинов дока). `updateState(section, data)`.
- **Шелл НИКОГДА не пишет в `config.json`** (кроме явных GUI-действий через `updateConfig`, заменяющих секцию целиком). Конфликт — «config edit wins».
- Запись дебаунсится (`Timer interval: 500`); самозапись защищена флагом `_suppressConfigReload` от reload-цикла.
- Доступ — типизированные `readonly property` с `?.`/`??`: `data.appearance?.theme?.darkMode ?? true`. `default.json` должен содержать ВСЕ возможные ключи.

### UI-состояние — `GlobalStates` (в `src/core/services/GlobalStates.qml`)
Канонический рантайм-стейт открытости панелей (`dashboardOpen`, `launcherOpen`, `lockscreenActive`, …)
со взаимоисключением (открытие одной гасит остальные через `on<Panel>OpenChanged`), `closeAllPanels()`, power/lock-утилиты.

> `src/features/GlobalState.qml` (одно поле `showDateSelector`) — **легаси-дубль, использовать НЕ нужно**, подлежит удалению/слиянию в `GlobalStates`.

### IPC и хоткеи
- 5 `IpcHandler`: `globalstates`, `audio`, `mpris`, `wallpaper`, `wallpaper-cache`. Вызов: `qs ipc call <handler> <fn> [arg]`.
- `GlobalShortcut` (ext-global-shortcuts) объявлены в `GlobalStates`/`AudioService`; биндятся `bind = …, global, quickshell:<name>` в hyprland.conf.

---

## 9. C++ плагины — `src/plugins/`

Тяжёлое/быстрое/системное живёт здесь, не в QML. Qt 6.5+, C++17, `qt_add_qml_module(URI <Name> VERSION 1.0)`.

| URI | Назначение |
|---|---|
| `Mcu 1.0` | Material Color Utilities: палитра M3 из обоев (`McuTheme`). База — сабмодуль `external/material-color-utilities`. |
| `Calendar 1.0` | iCalendar/RRULE через libical (`CalendarBackend`, singleton). |
| `Qalculate 1.0` | калькулятор лаунчера (`QalculateWrapper.eval`). |
| `SystemMonitor 1.0` | CPU/RAM/swap/GPU/disk/net из `/proc` (`SystemMonitor`, singleton). |
| `FuzzySearch 1.0` | нечёткий поиск (`score/match/matchWeighted`). |

**Что обязано быть в C++, а не в QML:** парсинг строк/`.ics`, сканирование/чтение ФС, анализ
изображений, O(n)-поиски, LRU-кэши, любая синхронная тяжёлая работа в UI-потоке.
**Конвенции C++:** `Q_OBJECT`+`QML_ELEMENT`(+`QML_SINGLETON`); worker-thread через `moveToThread`
с `quit()/wait(3000)` в деструкторе; `QMutexLocker`, **сигналы эмитить вне лока**; запись файлов
атомарно (`.tmp` + rename); единый сигнал `errorOccurred(QString)` + graceful degradation.
**НИКАКИХ `qDebug`/`qWarning` в коде thread-pool** (вызывает SIGSEGV); raw `this` в лямбдах
`QtConcurrent::run` оборачивать в `QPointer`.

---

## 10. ⛔ ЖЁСТКИЕ ЗАПРЕТЫ (NEVER)

Перечисленное в проекте использоваться **не должно**. PR с любым из этого не принимается.

**Стиль / MD3**
1. ❌ **Хардкод цвета** (`"#RRGGBB"`, `"white"`, `Qt.rgba(...)`) в UI. Только `Theme.<role>` / `Qt.alpha(Theme.x, a)`.
2. ❌ **Хардкод размеров/радиусов/длительностей/шрифтов/easing-кривых.** Только `Tokens.*`.
3. ❌ **Сырой `Rectangle`/`Text` в `src/features/*`.** Только компоненты из `src/ui/*` (`Surface`, `MaterialText`, …).
4. ❌ **Elevation через `opacity`.** Высота = surfaceContainer-тон + тень (`Surface { elevation }`).
5. ❌ **`font.pointSize`.** Только `font.pixelSize` (через `MaterialText`/`Tokens.typography`).
6. ❌ **`QtQuick.Controls` Tooltip / стоковые контролы для оформленного UI.** Только MD3-аналоги из `src/ui`.
7. ❌ Ссылки на несуществующие `ColorService`/`palette`/`tPalette`/`.layer()` (мёртвый план миграции, не реализован).

**Архитектура**
8. ❌ **Импорт `services` из `ui`** или любые обратные рёбра зависимостей (см. §3).
9. ❌ **Свойства состояния на `ShellRoot`/в `shell.qml`.** Общий рантайм-стейт — в `GlobalStates`.
10. ❌ **Запись runtime-данных в `config.json`.** Только в `state.json`.
11. ❌ **`property var` там, где возможен типизированный тип** (особенно цвета — `property color`).
12. ❌ Использование легаси `src/features/GlobalState.qml`, `WallpaperServiceLegacy`, `wallpaper.json`, пути `~/.config/shell/`, имени `DesignTokens.qml`.

**Производительность**
13. ❌ **Синхронная/блокирующая работа в UI-потоке** (чтение/сканирование ФС, парсинг, тяжёлые вычисления) — выноси в C++ плагин.
14. ❌ **`StackLayout` для вкладок** (инстанцирует все сразу) — используй `Loader` с ленивой загрузкой.
15. ❌ **`LazyLoader { loading: true }`** без привязки к видимости (сводит на нет ленивость).
16. ❌ **Спавн процесса в цикле/на каждый кадр/без нужды**; периодика — только через `Timer` с разумным интервалом и без накопления `Process`-объектов.
17. ❌ **`console.log`/`qDebug` в продакшен-коде.**

**Корректность**
18. ❌ **`process.running = true` без проверки `!process.running`** (зомби/краш).
19. ❌ **`createObject()` без парного `destroy()`**; неограниченные кэши/очереди без лимита и eviction.
20. ❌ **`destroy()` объекта, который ещё используется** (в модели/ListView) — use-after-free.
21. ❌ **Orphan-таймеры:** при удалении сущности её `Timer` остановить, `destroy()`, обнулить; cleanup в `Component.onDestruction`.
22. ❌ **Нереактивный доступ к модели** (`model[i]`, разовый `.filter()`); используй реактивные биндинги / `ScriptModel`.
23. ❌ **JS `Set`/`Map` в `property`** — используй массив с `includes/indexOf/splice`.
24. ❌ Сравнение объектов (плееров, мониторов) **по ссылке** — сравнивай по стабильному ключу (`identity`/имя).

**Безопасность**
25. ❌ **`sh -c` с конкатенацией/template-literal из переменных.** Только argv-массив в `Process`; внешний ввод — через regex-guard (напр. `^[a-zA-Z0-9_-]+$`).
26. ❌ Хардкод абсолютных путей пользователя (`/home/<user>/...`); используй XDG/`StandardPaths`.
27. ❌ `MouseArea`-костыли для модальности — для попаутов/меню используй `HyprlandFocusGrab` (одно окно/один grab на все экраны, Timer-задержка для right-click).

**Гигиена репозитория**
28. ❌ **Коммит артефактов сборки и мусора:** `src/plugins/build/`, `shell.zip`, `test.diff`, `*.qsb`-кэши. (В проекте НЕТ `.gitignore` — заведи его и держи актуальным.)
29. ❌ **Плодить отдельные аналитические/отчётные `.md`** (audit/plan/migration-заметки). Конвенции и решения — в `AGENTS.md`, открытую работу — в `ROADMAP.md`. Не воссоздавать архив `docs/`.
30. ❌ **Смешение языков в комментариях.** Код-комментарии — на английском; без emoji в коде.

**Config-first**
31. ❌ **GUI-настройки в любом виде:** приложение/окно настроек, declarative settings-панели (`ConfigSwitch`/`ConfigSpinBox` и пр.), drag-and-drop переразметка бара/панелей, GUI-пикеры пресетов/тем. Настройка — только `config.json` + IPC.
32. ❌ **Конфигурируемость в обход схемы:** новый ключ без записи в `config.schema.json` и без дефолта в `default.json`.
33. ❌ **«Пресеты»/«схемы» как UI.** Реализовывать как JSON-данные (`assets/presets/`, `assets/colors/`) + применение через IPC/поле конфига, не через интерфейс выбора.

---

## 11. Векторы детально

### Производительность
- Цель — **100% non-blocking UI**. Тяжёлое → C++ (см. §9).
- Дебаунс/троттлинг ввода: калькулятор лаунчера троттлится ~150мс + кэш результата (включая ошибки).
- SystemMonitor: интервал 2000мс, **ноль спавна процессов** для CPU/RAM/Disk (только `/proc`+`statvfs`), FD держатся открытыми, сигналы — только при значимом изменении.
- Обои: кэш отсортированных списков per-monitor, очередь сканирования с лимитом, пост-скрипты — следить за блокировкой последовательным запуском.
- Лениво: `LazyLoader` с `active: AppConfig.moduleEnabled(...) && GlobalStates.<panel>Open`; вкладки — `Loader`, не `StackLayout`.

### Корректность
- Жизненный цикл QML: **create → use → destroy**, сбалансированно. Каждому `createObject` — `destroy`.
- Процессы: guard `!running`; диагностика `ps aux | grep defunct`.
- Таймеры/Connections — чистить при разрушении владельца; не плодить (история: «21 таймер → гонки → SEGFAULT»).
- Реактивность — биндинги, а не разовые присваивания; модели Quickshell — через реактивный доступ.

### Безопасность
- Shell-команды — argv-массивы, guard на ввод (см. запрет 25).
- Процессы — без зомби; файлы — атомарная запись; пути — XDG.
- Модальность — `HyprlandFocusGrab`, тройное условие активации (`loader.active && grabReady && GlobalStates.<panel>Open`), Timer-задержка под right-click.
- Лок/PAM/greeter — отдельный конфиг (`src/features/greeter/`), не трогать без явной задачи.

### MD3
- См. §5. Динамический цвет из обоев (variant по умолчанию `tonalspot`, contrast 0.5 ≈ WCAG ≥4.5), state layers, elevation-тоном, emphasized motion. MCU даёт seed — глубину/прозрачность добавляет QML-слой через `Theme` + `Qt.alpha`.

---

## 12. Где что искать

| Задача | Файл |
|---|---|
| Добавить настройку | `config/config.schema.json` + `config/default.json` + типизированный геттер в `AppConfig.qml` |
| Цветовые роли | `src/core/config/Theme.qml` |
| Размеры/типографика/motion | `src/core/config/Tokens.qml` |
| Состояние панелей / хоткеи / IPC | `src/core/services/GlobalStates.qml` |
| Виджеты бара (data-driven) | `src/features/statusbar/` (`StatusBar.qml`, `BarWidgetLoader.qml`) |
| Новый сервис | `src/core/services/` (singleton, регистрация в init) |
| Новый UI-компонент | `src/ui/<base|containers|feedback|inputs>/` + `qmldir` |
| Нативная/тяжёлая логика | `src/plugins/src/<plugin>` |

---

## 13. Заметки для агентов

- **Источники правды:** этот `AGENTS.md` + `CLAUDE.md` (конвенции), `README.md` (фичи/установка/IPC), `ROADMAP.md` (открытая работа), `config/config.schema.json` (конфиг). Других «документов-планов» в репо нет — архив `docs/` удалён, не воссоздавай.
- **Устарело / не существует — не использовать** (следы старых планов могут встретиться в комментариях или git-истории): `ColorService.layer()` (нет в коде → `Theme.<role>`), `DesignTokens.qml` (→ `Tokens.qml`), путь `~/.config/shell/` (→ `~/.config/quickshell/config.json`). Верь коду.
- C++ плагины должны быть **собраны и установлены**, иначе `import Mcu 1.0` падает и копит ошибки → segfault.
- Технический долг (не плодить дальше): дубль сети (Wi-Fi нативно, eth/vpn через `nmcli`), дубль `GlobalState`/`GlobalStates`, отсутствие `.gitignore`, qmldir-асимметрия (`config`/`services` без qmldir).
- Изменил поведение или фичу — обнови `README.md`/`ROADMAP.md`, а конвенцию — здесь. Не создавай новый отчётный `.md`.
