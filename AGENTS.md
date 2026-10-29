# AGENTS.md — shell (Quickshell / Hyprland)

> **Единый источник правды по конвенциям проекта.** Любой агент или контрибьютор
> читает этот файл ПЕРЕД изменением кода. `CLAUDE.md` — краткая выжимка для Claude
> Code и ссылается сюда.

**Проект:** `shell` — desktop shell для Hyprland на Quickshell
**Фреймворк:** Quickshell (QML/Qt 6) + 7 собственных C++ плагинов
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
(`at1ass-shell ipc call …`). GUI-настроек в проекте **не будет** — это осознанный дизайн-выбор
(tiling-WM минимализм). Schema + полные дефолты + миграции конфига — это и есть «интерфейс
настроек». Чем меньше GUI-конфигурирования, тем лучше.

---

## 1. Обзор проекта

`shell` — конфигурация Quickshell, реализующая бар, док, дашборд, лаунчер, уведомления,
OSD, скриншоты, локскрин, powermenu, cheatsheet и динамическую тему из обоев. Управляется
JSON-конфигом с hot-reload и JSON Schema. Тяжёлая логика вынесена в 7 C++ плагинов.

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
| Нативная логика | 7 C++ плагинов (Qt 6.5+, C++17, CMake + Ninja) |
| Цвет | C++ плагин `Mcu` (Material Color Utilities, сабмодуль) |

**Внешние CLI** (только там, где нет нативного API): `ddcutil`, `grim`, `wl-copy`, `swappy`,
`cliphist`, `nmcli` (VPN actions by UUID), `hyprsunset`, `hyprctl`, `gdbus`, `systemctl`.

---

## 3. Архитектура и слои

```
shell.qml                     # ShellRoot: Variants per-screen + глобальные оверлеи (LazyLoader)
src/
├── core/
│   ├── config/               # AppConfig, Theme, Tokens  (НЕ зависит от features/ui)
│   └── services/             # singleton-сервисы + GlobalStates  (зависит только от config)
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
sudo cmake --install build          # ставит в /usr/lib/qt6/qml/ — В ОБХОД pacman
# На этой машине плагины и greeter ставятся пакетом (packaging/arch/PKGBUILD):
#   tools/build-arch.sh /tmp/at1ass-shell-build; затем tools/migrate-installed.py --packages /tmp/at1ass-shell-build --apply
# Пакет собирается из ЗАКОММИЧЕННОГО состояния: сначала коммит, потом сборка.
# Не смешивай: cmake --install поверх пакета перезапишет файлы, которыми владеет pacman.
# ⚠️ Замена .so под работающим шеллом может его уронить, а плагин всё равно
# подхватится только после перезапуска: systemctl --user restart at1ass-shell.service
# (сначала проверь `at1ass-shell ipc call globalstates locked` — см. предупреждение ниже).

# Запуск
quickshell -p ~/.config/quickshell/shell        # (сокращённо: qs -p ...)
QT_QPA_PLATFORMTHEME=gtk3 qs -p ~/.config/quickshell/shell   # фактический паттерн запуска
# В живой сессии шелл — пакетный user-сервис (/usr/lib/systemd/user/at1ass-shell.service):
systemctl --user restart at1ass-shell.service   # полный перезапуск; НЕ pkill + qs из терминала
journalctl --user -u at1ass-shell.service -f    # логи шелла

# Внешнее управление
at1ass-shell ipc call <handler> <function> [arg]

# Линт (требование: qmllint clean на всех изменённых QML)
tools/lint.sh <files...>      # обёртка qmllint с import-путями qs.* (.qmllint-imports/)

# Инварианты запретов §10 + ratchet-базлайн (tools/check-baseline.txt)
tools/check.sh                # exit 1 = регресс; после снижения долга: --update-baseline

# Юнит-тесты календарного плагина (единственные тесты в проекте — ЗАПУСКАЙ их,
# трогая src/plugins/src/calendar-qml: они ловят то, что не видно глазом)
cd src/plugins && cmake -B build-test -S . -G Ninja -DCMAKE_BUILD_TYPE=Debug -DBUILD_TESTING=ON \
  && cmake --build build-test --target calendar_test \
  && QT_QPA_PLATFORM=offscreen ./build-test/src/calendar-qml/test/calendar_test

# Сборка каждого компонента настоящим движком Quickshell (не создаёт окон)
tools/compile-check.sh        # exit 1 = что-то не компилируется
```

Изолированные UI-тесты: `tools/test-ui.py` (Qt Quick Test, реальные key events, mock-сервисы).
Для C++ плагинов пишутся unit-тесты. Перед коммитом изменённый QML
обязан проходить `qmllint` без предупреждений.

Текущая система переведена на AUR: код запускается из `/usr/share/at1ass-shell`,
`at1ass-shell.service` включён, старый `quickshell.service` отключён. Checkout в
`~/.config/quickshell/shell` сохранён для разработки и не подхватывается пакетным
процессом. Изменения QML в checkout требуют сборки/обновления пакета для применения;
не копировать их в `/usr/share` поверх pacman. Для IPC установленного экземпляра
использовать `at1ass-shell` или `/usr/bin/shell-ctl`, а не `qs -c shell`.

### ⚠️ Правка на живом шелле = риск потерять сессию

Шелл перезагружается горячо, а загрузка конфигурации — **всё или ничего**: одна ошибка
в одном файле роняет её целиком. Пока шелл держит `WlSessionLock`, вместе с конфигурацией
умирает и экран блокировки — Hyprland остаётся заблокированным без клиента.

Отсюда два правила:

1. **Если сессия заблокирована — не править файлы.** Ждать разблокировки. `hypridle`
   в этой системе блокирует после 600 с простоя, и IPC-вызовы со скриншотами счётчик
   простоя НЕ сбрасывают: при долгой автоматической работе блокировка приходит сама.

   Спрашивать состояние так:
   ```bash
   at1ass-shell ipc call globalstates locked      # true → НЕ ПРАВИТЬ
   ```
   `loginctl show-session <id> -p LockedHint` для этого НЕ годится: `hypridle`
   зовёт `lockScreen()` прямо по IPC, мимо `loginctl lock-session`, поэтому
   hint остаётся `no` при фактически заблокированной сессии.

   Сюда же: **проверять инварианты, ломая реальные файлы, нельзя** — живой шелл
   перезагрузится на сломанном дереве. Для этого `tools/compile-check.sh` уже
   работает на копии; ломать нужно копию.
2. **Надёжного восстановления НЕ найдено — проверено 2026-08-13 ребутом.**
   Hyprland на своём экране предлагает `hyprctl --instance 0 eval
   'hl.clear_crashed_lockscreen()'` из другого tty. Функция в 0.56.2 существует
   и отвечает, но проблему тогда не решила; помог только перезапуск машины.
   Вероятная причина (НЕ проверена): процесс `qs` переживает провал загрузки —
   в тот раз `pgrep -x qs` показывал живой pid при «Failed to load configuration»
   в логе. Умирает конфигурация, а не процесс. Тогда второй совет с того же экрана —
   «убей процессы блокировки и повтори eval» — означает здесь `pkill -x qs`,
   а не `killall hyprlock`. Проверять это на живой сессии никто не будет,
   поэтому **единственная надёжная защита — пункт 1**.

`qmllint` этот класс ошибок НЕ ловит: файл с двумя `pragma ComponentBehavior` линтуется
чисто (exit 0, без диагностики) и падает только на загрузке. Поэтому есть
`tools/compile-check.sh` и инварианты `duplicate-pragmas` / `qml-compile-failures`.

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
- `Tokens.iconSize`, `Tokens.touchTarget.minimum`, `Tokens.focusRing`.
- `Tokens.size` — семантические размеры контролов: `control`, `buttonMinimumWidth`, `field`,
  `fieldWidth`, `iconButton`, `listItem`, `itemIcon`, `tileMinimumWidth`; значения определяет пакет дизайна.

### Правила MD3
- Текст — `MaterialText { textStyle: "bodyMedium"; colorRole: "onSurface" }`; `font.pixelSize` (НЕ `pointSize`), `Text.NativeRendering`.
- Анимации — `easing.type: Tokens.motion.easing.emphasized; easing.bezierCurve: Tokens.motion.easing.emphasizedPoints`. Длительности — из `Tokens.motion.duration`.
- Поверхности с тенью/«высотой» — `Surface { elevation: n }` / `MaterialCard`. Меню MD3 = elevation level 2.
- State layers (hover/pressed/focus) — `StateLayer` с `Tokens.stateLayer.*`.
- Вложенные поверхности → выше surfaceContainer-тон (больше emphasis).

---

## 6. UI-компоненты — `src/ui/`

Готовые MD3-примитивы. В `features/` собирай UI **только из них**, а не из сырых `Rectangle`/`Text`.

- **base/** — `MaterialShape` (лёгкая плоская геометрия/маски без elevation и неявной анимации), `MaterialText`, `MaterialIcon`, `MaterialButton`, `IconButton`, `FAB`, `MaterialIndicator`, `SectionHeader`, `CircleAvatar`, `Sparkline`, `MaterialMarqueeText`, `ElevationShadow`.
  Тень приподнятой поверхности — только через `ElevationShadow` (`RectangularShadow` + маппинг `Tokens.elevation`).
  `MultiEffect { shadowEnabled: true }` не использовать: он гоняет источник через FBO и блюр на каждое его изменение,
  а у каждой поверхности есть `Behavior on color`. `MultiEffect` остаётся для блюра картинок и масок.
- **containers/** — `Surface`, `MaterialCard`, `BarElement`, `ListItem`, `Divider`, `ScrollableList`, `CollapsibleContent`.
  `ListView.reuseItems` — **только для делегатов фиксированной высоты.** При переменной высоте (перенос текста)
  и/или секциях переиспользованный делегат позиционируется по прошлой высоте раньше, чем содержимое разложилось:
  карточки наезжают друг на друга и на заголовки групп. Проверено на центре уведомлений — откачено; в лаунчере
  (высота строки фиксированная) оставлено.
  Анимация в виджете бара гейтится на `animationsActive` (= `animated && barRevealed`): скрытый авто-хайдом бар
  продолжает отслеживать состояние, но переходы выполняет мгновенно. Qt не пропускает анимации невидимого
  поддерева сам — это 30% стоимости жеста компози́тора.
- Tooltip lifecycle: `TooltipItem` supplies owner/text/show to a per-bar `TooltipManager`;
  `MaterialTooltip` owns appearance and text bounds, `MaterialHint` supplies local popup
  lifecycle. Passive tooltips never take a grab. Animate content opacity only; native
  popup dimensions must remain positive during closing. `Tokens.interaction` deadlines
  do not scale with reduced motion. Tray submenu components are owned by StackView;
  observe opener/child-model updates and guard deferred dismissals by request epoch.
- **feedback/** — `StateLayer`, `Dialog`, `Snackbar`, `Badge`, `ProgressIndicator`, `MaterialMenu`, `TooltipManager`/`TooltipItem`, `EmptyState`.
- **inputs/** — `MaterialTabs` (controlled selection, roving focus), `MaterialSlider`, `MaterialSwitch`, `MaterialCheckbox`, `MaterialRadioButton`, `MaterialComboBox`, `MaterialTextField`, `SegmentedButton`, `Chip`.

Сырые `Rectangle`/`Text` допустимы **только внутри `src/ui/*`** (это их реализация). В `src/features/*` — нет.

### Типы действий

`ToggleTile` — управляемый режим с маркером состояния; `ActionTile` — переход
(стрелка) или однократная команда (`trailingIcon: ""`), без on/off-маркера.
BarElement.accessibleName задаёт подробное состояние; загрузчик задаёт только
defaultAccessibleName как fallback и не перезаписывает биндинг виджета. Разовая
активация кнопок и переключателей игнорирует auto-repeat; навигация может повторяться.
Основной клик статусного виджета открывает `clickAction`; вложенная кнопка владеет
своим действием. Наведение не меняет геометрию бара. IPC-справка обнаруживает
сигнатуры через `at1ass-shell ipc show`; таблица описаний не создаёт команды.

### Обход фокуса

Tab/Shift+Tab обходят контролы; вкладки переключаются Ctrl+Tab либо стрелками внутри
`MaterialTabs`. В Dashboard Ctrl+Tab/Ctrl+Shift+Tab — оконные Shortcut с ограничением
по видимости/открытости и modalOpen: дочерние контролы могут поглотить Tab до
всплытия Keys. Стрелки календаря и vi-навигация принадлежат клетке сетки; полоса
вкладок не передаёт вверх/вниз в календарь. Bare-команды панели не перехватывают
клавиши фокусного контрола. Диалог владеет обходом ближайшей модальности и возвращает прежний фокус
после закрытия. `ScrollableList` раскрывает область с фокусом по событию, без polling.
Он наблюдает каретку только своего TextInput/TextEdit; у редактора выше viewport
показывается cursorRectangle, а не нижняя граница всего текста. MaterialTextArea
включает редактор в Tab-цепочку и передаёт Keys владельцу перед штатной обработкой
TextEdit; форма EventDialog направляет Tab/Shift+Tab в обход ближайшей модальности.
Высота строки с reuseItems должна быть постоянной для выбранных pack/fontScale.
`MaterialComboBox` с внешним источником выбора использует `controlled: true` и
`onActivated`; обработчик пишет в модель владельца, currentIndex остаётся биндингом.
Обычный режим без controlled сохраняет локальный выбор. Пустые/отключённые списки
не открывают popup; подписи всегда PlainText.
`MaterialButton` явно обрабатывает оба Enter через нативный `click()` (Qt 6.8+);
Space остаётся на штатном пути Button. Нельзя полагаться на платформенную
активацию Return или просто эмитить clicked: сохраняются checked/pressed/released.
Обычный `ListItem` измеряет текст/слоты; действие строки обязано иметь `onClicked`,
повтор той же команды в trailing-иконке не добавляет второй Tab-stop. Снимки устройств
согласуются через `ScriptModel` (Bluetooth — `objectProp: "address"`), чтобы обновление
данных сохраняло делегат и фокус. Скролл-контейнер сам не является Tab-stop.

### Клавиатура — привязка к КЛАВИШЕ, а не к символу

`event.key` и `event.text` несут символ, который даёт активная раскладка. На
кириллице физическая J приходит как `Qt.Key_O` с текстом «о», поэтому
`event.key === Qt.Key_J` не срабатывает вообще. Так были мертвы все vi-привязки
шелла. Цифры тоже небезопасны: на AZERTY верхний ряд без Shift даёт `&é"'(`.

Сопоставлять нужно физическую позицию — `event.nativeScanCode` (XKB-код, он же
evdev + 8), она одинакова в любой раскладке. Для этого есть `Keycodes` в
`core/config`:

```qml
Keys.onPressed: (event) => {
    const key = Keycodes.key(event)        // НЕ event.key
    if (key === Qt.Key_J) moveDown()
}
// для сопоставления с буквами из данных:
if (Keycodes.letter(event) === action.key) activate()
```

`Escape`, стрелки, `Return`, `Delete`, `Home/End`, `PageUp/Down`, `F1…` от
раскладки не зависят и проходят через `Keycodes.key()` без изменений — их
можно сравнивать как обычно. Инвариант `layout-dependent-keys` держит ноль.

---

## 7. Слой сервисов — `src/core/services/`

Паттерн «Reactive Singleton»: `pragma Singleton` (+ часто `pragma ComponentBehavior: Bound`),
внутреннее состояние из асинхронных системных вызовов, наружу — реактивные `property`.

### Источник данных: нативное > подпроцесс
- **Нативный Quickshell API — всегда, когда он есть:** аудио → `Pipewire`; медиа → `Mpris`; Wi-Fi → `Networking`; Bluetooth → `Bluetooth`; уведомления → `Services.Notifications`.
- **`Process` + CLI — только когда нативного API нет:** яркость (`ddcutil`), скриншоты (`grim`/`wl-copy`/`swappy`), буфер (`cliphist`), night light (`hyprsunset`), VPN (`nmcli`), питание/лок (`systemctl`/`hyprctl`/`gdbus`).
- Цель (ROADMAP): мигрировать подпроцессы на нативный D-Bus (`Quickshell.Io.DBus`), эталон — `MprisController`.

### Конвенции
- Свойства lowerCamelCase, реактивные (`masterVolume`, `isCharging`, `available`); методы-команды `setX/toggleX/increase/decrease`; сигналы — действие/прошедшее время (`volumeChanged`, `brightnessAdjusted`); приватное — префикс `_`.
- Системный stdout — `Process` + `SplitParser`/`StdioCollector`, обработка построчно.
- Списки/модели внутри `Process.onStdout` менять только через `Qt.callLater()`.
- Всегда безопасный fallback (`available: device !== null`).
- **Запуск приложений — только через `AppLaunchService`** (`launchEntry(entry)` / `launchCommand(argv)` → `app2unit`, отдельный systemd scope на приложение). Прямые `DesktopEntry.execute()` и `Quickshell.execDetached` для приложений запрещены: запущенное попадает в cgroup шелла — общий учёт ресурсов и общая судьба при остановке scope или OOM-kill любого процесса в нём (`OOMPolicy=stop`).

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
  **Тоггл, которым владеет шелл, обязан жить здесь** (caffeine, night light, DND, gaming mode): свойство только
  ВЫВОДИТСЯ из `AppConfig.stateData`, сеттер только ПИШЕТ через `updateState` — образец в `NotificationDND`.
  Read-write свойство с персистером в `onChanged` зацикливается через `stateData` и рвёт собственный биндинг
  на первой императивной записи. Тоггл, состояние которого держит система (WiFi, Bluetooth, VPN), сюда не пишется —
  оно читается обратно из системы. Хранить такой флаг в памяти нельзя: он молча теряется и при рестарте,
  и при hot-reload QML.
- **Конфиг валидируется по схеме ДО публикации при каждой загрузке** (`ConfigValidator`, вызывается из `AppConfig`).
  Неверный файл не заменяет последний рабочий snapshot; синтаксические ошибки и ошибки
  схемы остаются в `configErrors` и IPC `config validate`. На невалидном первом запуске
  используются bundled defaults. `additionalProperties`-схемы проверяются рекурсивно.
  Новый ключ обязан попасть в `config.schema.json` и `default.json`, иначе `tools/check.sh` падает
  (`config-default-drift`): он же сверяет литерал `?? default` в `AppConfig` со значением в `default.json`.
  `AppConfig` только ПУБЛИКУЕТ ошибки в `configErrors` — тост поднимает `shell.qml`, потому что
  слой `config` не имеет права трогать `services`. Снаружи проверяется через `tools/shell-ctl config validate`
  (IPC-хендлер `config`) — тем же валидатором, без перезапуска шелла.
- **`tools/shell-ctl`** — единая точка входа в IPC. Список хендлеров он ОБНАРУЖИВАЕТ через `at1ass-shell ipc show`,
  а не хранит: справка и zsh-автодополнение поэтому не могут разойтись с кодом. Добавил IPC-функцию —
  ничего в CLI править не надо; ярлыки (`launcher`, `caffeine`, …) — только алиасы поверх той же поверхности.
- **Шелл НИКОГДА не пишет в `config.json`**. Конфликт — «config edit wins».
- Запись дебаунсится (`Timer interval: 500`); самозапись защищена флагом `_suppressConfigReload` от reload-цикла.
- Доступ — типизированные `readonly property` с `?.`/`??`: `data.appearance?.theme?.darkMode ?? true`. `default.json` должен содержать ВСЕ возможные ключи.

### UI-состояние — `GlobalStates` (в `src/core/services/GlobalStates.qml`)
Канонический рантайм-стейт открытости панелей (`dashboardOpen`, `launcherOpen`, `lockscreenActive`, …)
со взаимоисключением через единственное поле `activePanel` и производные флаги, `closeAllPanels()`, power/lock-утилиты.

> `src/features/GlobalState.qml` (одно поле `showDateSelector`) — **легаси-дубль, использовать НЕ нужно**, подлежит удалению/слиянию в `GlobalStates`.

### Панель подключений

`features/connections` — единственное место управления Wi-Fi/Bluetooth/VPN/Ethernet;
в Dashboard остаются Quick/Weather/Calendar; Audio вынесено в `features/audio`. `GlobalStates.connectionsOpen`
выводится из `activePanel`; источник открытия и запрошенный раздел хранятся там же.
Старые `dashboard-network` и `openDashboardTab(4)` перенаправляются в Connections.
Поиск ограничен видимостью раздела и таймаутом; подключение живёт в сервисе.
Внешние редакторы профилей разрешены по явному действию; GUI-настроек шелла здесь нет.
BluetoothPairingAgent (`Connectivity 1.0`) регистрируется только для процесса шелла,
не вызывает RequestDefaultAgent и принимает запросы только от текущего владельца
org.bluez для явно выбранного устройства. PIN/подтверждения — модальный Dialog
внутри существующего окна Connections; новый grab не создаётся. Каждый ответ
проверяет request token. Закрытие панели, смена раздела, блокировка, resume,
выключение адаптера и исчезновение устройства отменяют запрос. Нативный мост
вызывает Pair асинхронно: QS 0.3.2 не публикует ошибку и использует короткий
стандартный D-Bus timeout. Остальные операции/модель — Quickshell.Bluetooth.
Новый Pair ждёт завершения отменённого транспорта; таймаут абсолютный, монотонный.
Конфиг: connections.bluetoothAgent и connections.pairingTimeout. Optional Loader
изолирует отсутствие модуля до установки; fallback — внешний default agent.
Проверки: bluetooth_agent_test на приватной D-Bus шине, tools/test-bluetooth.py,
tools/test-ui.py. blueman-applet пока не отключать: нужна оставшаяся аппаратная
приёмка сопряжения. Миграция nm-applet описана ниже.

Wi-Fi Personal (WpaPsk/Wpa2Psk/Sae) передаёт пароль через нативный
WifiNetwork.connectWithPsk(), без nmcli/stdin. Сервис удерживает только типизированный
объект сети, не пароль; busy снимается по состоянию/ошибке/удалению объекта и имеет
ограниченный fallback deadline для немых ошибок записи профиля в QS 0.3.2.
Создание WEP/802.1X/неизвестных профилей — внешний nm-connection-editor.
NetworkAuthService запускается через ServiceBootstrap независимо от панели;
Connectivity.NetworkSecretAgent обрабатывает Get/Cancel/Save/DeleteSecrets.
Доверяет только текущему unique owner NetworkManager, очередь ограничена 8 запросами,
один cancellable worker, deadline включает очередь/ввод/keyring. При disable нужно
дождаться позднего ответа регистрации и снять её; уничтожение фасада не ждёт worker.
QML получает только описание полей и токен, ответы не сохраняет. Locked запрещает
интерактивные запросы; noninteractive lookup не разблокирует keyring. libsecret
работает в worker, схема/атрибуты совместимы с nm-applet; NOT_SAVED и VPN challenge
не сохраняются. OpenVPN helper запускается только в external-ui-mode для описания
полей, без настоящих секретов; другие VPN plugins/WireGuard пока не реализованы.
NetworkAuthenticationDialog делит grab панели; отложенные переходы проверяют токен.
Редактор профилей не заменяется. nm-applet отключать только после установки плагина,
проверки networkauth registered и аппаратной приёмки; blueman этим не затрагивается.
Проверки: network_agent_test на private bus, tools/test-network-auth.py,
tools/test-network-keyring.py с изолированным keyring, tools/test-network.py и test-ui.py.
Поиск — явный lease сервиса: желание искать отделено от scannerEnabled и готовности
адаптера. Unknown -> Disconnected и замена устройства применяют lease заново;
остановка/закрытие/idle deadline освобождают его. Deadline поиска приостановлен на
время подключения. Повторный пароль ждёт терминального состояния сети и устройства;
ошибки доставляются по epoch и стабильному ключу interface/SSID, без удержания
уничтожаемого QObject в Qt.callLater. Индекс команд ограничен живыми delegate-watchers,
удаление проверяет поколение; UI читает реактивную нативную модель. Типизированный
list перед передачей в ScriptModel.values преобразуется через Array.from().
При изменении этого пути запускать tools/test-network.py и tools/test-ui.py.

EthernetService читает connected из Quickshell.Networking, без требования IPv4.
NetworkInfo/Connectivity.NetworkInterfaceInfo читают AddressData и Gateway обеих
семейств через асинхронный D-Bus, без polling/CLI/файлового I/O. Запросы single-flight,
refresh коалесцируется; snapshot публикуется целиком, устаревший epoch отбрасывается.
PropertiesChanged учитывает текущие device/IP-config пути; смена интерфейса/владельца
сбрасывает адреса. Один читатель для Ethernet, отдельный ленивый для Wi-Fi details.
Наличие адреса/link-local/шлюза не является проверкой доступа в интернет. Диалог
держит реактивную привязку к деталям, а не снимок при открытии. Проверки:
network_info_test, tools/test-network-info.py (--native — read-only QS/DBus), test-ui.py.

VPNService использует Connectivity.VpnProfiles: read-only D-Bus snapshot по UUID,
один запрос в полёте, coalescing и общий deadline 5 с, ограничение числа профилей.
GetSettings не запрашивает секреты; GetSecrets не вызывается. New/Updated/Removed,
ActiveConnections и StateChanged обновляют модель; сбой refresh сохраняет последний
рабочий snapshot, смена владельца/disable сбрасывает его, поздние ответы отбрасываются.
ScriptModel согласует строки по uuid. Имя — только отображение; services.vpn.name
игнорируется (схема оставлена для совместимости). Общее действие открывает выбор,
команды up/down идут по UUID через один Process с deadline и защитой от повторов.
Поздние результаты после смены enabled не поднимают тост. NetworkEventMonitor удалён:
нет фонового nmcli monitor и CLI-запросов списка/статуса. Проверки: vpn_profiles_test,
tools/test-vpn.py (--native только чтение), test-ui.py.

### Аудио и трей

Dashboard держит стабильную по высоте Wayland-поверхность; input mask ограничен
Loader карточки. Высота карточки следует текущему layout без второго Behavior:
иначе после уменьшения содержимого остаётся догоняющая пустая подложка. Плеер
публикует высоту из того же morph, что двигает контролы; CollapsibleContent сохраняет
ленивое содержимое до конца закрытия и анимирует высоту вместе с одним отступом
родительского layout (spacing). На смене вкладки размер применяется сразу после
измерения. Не возвращать resize нативного окна: Hyprland накладывает его анимацию
геометрии на QML motion. Начальные/скрытые изменения мгновенны, reduceMotion
соблюдается; край со стороны бара остаётся привязанным.

`features/audio` владеет выбором устройств и ленивым микшером. Состояние аудио
читается из AudioService, команды идут через его сеттеры; UI не хранит копию
mute/volume. `dashboard-audio` и `openDashboardTab(3)` — совместимые переходы.
Окна Audio и Connections используют `features/common/AnchoredPanel` с одним
focus-grab, ограничением размеров и привязкой к источнику открытия.

Трей ограничивается `maxVisible`; `pinnedIds` задаёт порядок по SNI ID. Overflow
не останавливает приложения. При переходе в меню используется живой якорь бара,
а отложенное закрытие проверяет epoch, чтобы не закрыть заменившее его меню.

DockService публикует новый snapshot индекса key → entry при согласовании модели;
`entryForKey` — реактивный O(1)-доступ. Hover и отложенный показ превью передают
ключ приложения через DockIcon/DockBar, не позицию списка. Удаление цели отменяет
таймер показа; старый exit другого ключа не отменяет новый enter. Индексы остаются
только для геометрии разделителя и команды перестановки пинов. Кэш резолвера
DockService ограничен 512 записями, включая отрицательные; обновление каталога
сбрасывает его. Словари по внешним app keys создаются через Object.create(null),
чтобы __proto__/constructor не пересекались со встроенными свойствами. Ограничения меню
берутся из размера экрана, а не из размера зависящей от меню PanelWindow (иначе
получается цикл геометрии). Превью учитывает свободную область со стороны дока;
анимируется центр, координаты ограничиваются после анимации. Размер контейнера
миниатюры не выводится из implicitWidth захвата с зависимым constraintSize.

### Хранилища

`SystemMonitor` собирает локальные тома и физические устройства в worker:
mountinfo фильтруется до stat-вызовов, повторные Btrfs/bind mounts группируются
по каноническому источнику ФС. Ёмкости разных строк не суммируются. I/O считается
по целым leaf-устройствам без разделов/dm/md; счётчики сбрасываются при смене
diskseq, пропадании устройства и больших интервалах. `storage` в конфиге задаёт
пороги, исключённые mount paths, порядок и имена. Предупреждения о свободном месте
не зависят от раскрытия графиков; RO/недоступный том не считается переполненным.
`StorageSection` показывает данные, без GUI-настроек и операций с дисками.
После изменения StorageCollector запускать `storage_test` и native/UI-пробы.

### IPC и хоткеи
- 5 `IpcHandler`: `globalstates`, `audio`, `mpris`, `wallpaper`, `wallpaper-cache`. Вызов: `at1ass-shell ipc call <handler> <fn> [arg]`.
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
| `Connectivity 1.0` | BlueZ Pair/agent и NetworkManager SecretAgent; отмена/deadline, libsecret worker и OpenVPN external UI. |
| `GreeterData 1.0` | Каталоги сессий и локальных пользователей гритера: worker, desktop/Exec parser, готовый argv. |

**Что обязано быть в C++, а не в QML:** парсинг строк/`.ics`, сканирование/чтение ФС, анализ
изображений, O(n)-поиски, LRU-кэши, любая синхронная тяжёлая работа в UI-потоке.
**Конвенции C++:** `Q_OBJECT`+`QML_ELEMENT`(+`QML_SINGLETON`); worker-thread через `moveToThread`
с независимым временем жизни (`WorkerLifetime`): фасад запрашивает interruption + quit,
но не ждёт worker в UI-потоке; `finished` удаляет worker и QThread. `terminate()` запрещён;
QtConcurrent-результаты доставляются через принадлежащий фасаду QFutureWatcher (у worker нет
указателя на фасад или QCoreApplication); `QMutexLocker`, **сигналы эмитить вне лока**; запись файлов
атомарно (`.tmp` + rename); единый сигнал `errorOccurred(QString)` + graceful degradation.
**НИКАКИХ `qDebug`/`qWarning` в коде thread-pool** (вызывает SIGSEGV); `QtConcurrent::run` получает только независимые данные, без `this` и указателя на приложение;
результат доставляет принадлежащий фасаду `QFutureWatcher`.

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
28. ❌ **Коммит артефактов сборки и мусора:** `src/plugins/build/`, `shell.zip`, `test.diff`, `*.qsb`-кэши. Держи `.gitignore` актуальным.
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
- SystemMonitor: сбор и ограниченная история (120 отсчётов) работают независимо от видимости Dashboard; ServiceBootstrap запускает фасад при старте, UI/графики остаются ленивыми. Температуры и GPU читаются существующим slow timer (5 с). Интервал основного сбора 2000мс, **ноль спавна процессов** для CPU/RAM/Disk (только `/proc`+`statvfs`), FD держатся открытыми, сигналы — только при значимом изменении.
- Обои: кэш отсортированных списков per-monitor, очередь сканирования с лимитом, пост-скрипты — следить за блокировкой последовательным запуском.
- Сервисы с сохранёнными системными эффектами запускает `ServiceBootstrap`; транспорт logind — `SessionMonitor`.
- Время жизни retained UI не определяет активность работы: discovery принадлежит раскрытому разделу панели Connections и останавливается при закрытии/скрытии; HTTP-компонент `HttpRequest` владеет таймером и отменой (browser-only `XMLHttpRequest.timeout/onerror` в QML не работают).
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
- Отложена миграция VPN actions по UUID с `nmcli` на D-Bus; модели Wi-Fi/Ethernet/VPN уже нативные. Механические baselines предупреждений qmllint, Rectangle в features и StackLayout равны нулю и не должны расти.
- Изменил поведение или фичу — обнови `README.md`/`ROADMAP.md`, а конвенцию — здесь. Не создавай новый отчётный `.md`.

### Нативные каталоги гритера

GreeterData читает системные каталоги сессий и /etc/passwd в worker, без shell и
без доступа к home. GLib декодирует desktop entry и кавычки; C++ раскрывает field
codes один раз и передаёт argv. GreeterAuth копирует argv при начале входа; QML
не разбивает Exec повторно. Независимые QtConcurrent jobs возвращаются через
принадлежащий фасаду QFutureWatcher, удаление фасада не ждёт worker. Новую версию
гритера устанавливать вместе с пакетом плагинов, содержащим GreeterData. Проверки:
greeter_data_test, tools/test-greeter.py и tools/test-greeter-data.py (read-only).


### Обзор воркспейсов

Overview — отдельная лениво создаваемая модальность activePanel. OverviewService
читает нативные Hyprland.workspaces/toplevels; карточки используют единый windowsByWorkspace по window.workspace.id,
без CLI/polling. Пустые цели берутся из overview в config/schema/defaults. Поиск —
нативный FuzzySearch, адрес окна является стабильным ключом; выбор не хранит QObject
между командами. Перенос фиксирует адрес исходного окна и снимок ID целей до открытия
меню, повторно проверяет их через сервис перед dispatch. Исчезновение исходного окна
закрывает меню. Скрытые карточки не захватываются, живой захват у видимых окон при overview.showPreviews=true; закрытие уничтожает панель. Настоящие focus/move в тестах запрещены —
tools/test-overview.py использует отдельные fake dispatchers даже с нативной моделью.

MaterialShape сохраняет прямое Rectangle-родительство для масок и координат потомков;
панели с elevation используют Surface. Сгенерированный greeter/ui относится к слою UI,
его Rectangle не считаются feature-кодом и защищены проверкой генератора. Базлайн
предупреждений QML, feature Rectangle и StackLayout снижен до нуля. Горячие клавиши
аудио/медиа регистрирует GlobalStates; ServiceBootstrap заранее создаёт AudioService
и MprisController, чтобы получение PipeWire/MPRIS не зависело от виджетов.

Обзор поддерживает физические Alt+H/L (воркспейсы), Alt+J/K (окна), в том числе
из поиска; без Alt эти команды действуют вне редактора. В меню назначения J/K
используют MaterialMenu.focusNext(), сохраняя пропуск отключённых строк. Высота
сетки ограничивается viewport и минимальным читаемым размером; canvas сохраняет
пропорции монитора. Не возвращать расчёт высоты только по ширине ultrawide-экрана.

DragHandler обзора не перемещает исходный Item: ghost/выбор цели живут в
OverviewContent, адрес исходного окна фиксируется при старте. Commit допускается
только при нормальном отпускании exclusive grab, с повторной проверкой окна и
цели. Escape, потеря grab/окна/воркспейса, скрытие и modal отменяют перенос. Потеря
источника обрабатывается отложенно с epoch, чтобы не перезаписать dragAddress внутри
биндинга dragWindow. Кэш GridView удерживает исходную карточку при edge scroll, но
захват скрытой карточки выключается. ScreencopyView получает HyprlandToplevel.wayland
(как DockService), не handle другого протокола. overview.showPreviews=false удаляет
capture Loader; фон выбранной карточки и canvas используют токенизированный tint.

Обзор закрывает окно по физическому Ctrl+W или явной кнопке превью через
OverviewService → HyprlandDispatch.closeWindow. Команда не фокусирует окно, не
закрывает обзор и не удаляет его из модели оптимистично. Drag/modal блокируют
закрытие; autorepeat игнорируется. DragHandler принадлежит body MouseArea, чтобы
не перехватывать жест кнопки закрытия, расположенной рядом в дереве. Тесты закрытия
используют только fake dispatcher; реальные окна пользователя не закрывать.

Перед closeWindow сервис эмитит windowCloseRequested: превью синхронно очищает
captureSource (не только live=false), затем выгружает Loader. Toplevel.closed
делает то же до уничтожения native source. Локальный latch не возобновляет
захват при изменении видимости во время закрытия; новый делегат/источник снимает
его. При отмене диалога сохранения превью вернётся после повторного открытия обзора.
Это защита от overlap close/capture, не доказанное исправление fatal Wayland error.

Меню ⋮ карточки и физическое Ctrl+Shift+M управляют целым воркспейсом. Положительный
существующий source ID фиксируется при открытии; снимок целей хранит только ID/имя.
OverviewService повторно проверяет source/monitor/target. На любой номер идёт
перенос всех окон source, независимо от поиска; на монитор — workspace.move с
явным source. workspace.change_id не использовать: Quickshell 0.3.2 не согласует
старый ID после этого события, refreshWorkspaces() не удаляет старые записи.
Не брать окна карточек из workspace.toplevels: группировать единый глобальный
список по текущему window.workspace.id, чтобы запоздавшая дочерняя модель не
создавала дубликаты. Перенос на другой номер использует обычное tiling-размещение.
Специальные и синтетические воркспейсы исключены. Modal блокирует обычные команды
обзора; исчезновение source закрывает меню. Тестировать только fake dispatchers,
без реального переноса окон/воркспейсов пользователя.

### Переносимая Arch-упаковка

packaging/arch/PKGBUILD — публичный split VCS рецепт: shell/plugins/greeter с
суффиксом -git, GPL-3.0-or-later; MCU Apache-2.0 и RapidFuzz MIT сохраняют notices.
Runtime устанавливается в /usr/share/at1ass-shell, плагины — /usr/lib/qt6/qml.
Пользовательские config/state/history/launcher DB не входят в пакет. Сборка через
tools/build-arch.sh использует только committed source и отдельный temporary
recipe с git+file://#commit, не меняя публичные HTTPS source или MCU worktree.
Новые внешние команды/импорты/ELF зависимости сверять с depends/optdepends и
матрицей README; обязательная linked library не становится optional от выключения
UI-модуля. Никаких install hooks для включения системных служб/гритера.

Миграцию выполняет tools/migrate-installed.py: dry-run по умолчанию, sudo до
остановки, lock-state до и после auth, остановка shell до замены .so, backup и
rollback интеграции. После перехода использовать at1ass-shell IPC (фиксированный
пакетный путь), не qs -c shell, который всё ещё обнаруживает dev checkout. Не
перезапускать greetd и не завершать пользовательскую сессию для проверки пакета.
Публикация исходников/AUR выполняется отдельным явным действием.


### AccountsService avatars and Quick system summary

GreeterData.AccountProfile is the shared read-only AccountsService bridge for
AccountService (dashboard) and LoginForm (selected greeter user). It performs
single-flight asynchronous D-Bus lookups with unique-owner reads, generation
checks and coalesced Changed/PropertiesChanged handling. User/owner/enable changes
clear the old avatar immediately. Filesystem validation runs in a value-only
QtConcurrent job; only shared system icon roots are allowed, including canonical
path checks against escaping symlinks. Never restore direct .face reads or home
ACLs. accountsservice is an optional runtime dependency of shell and greeter.

Dashboard flags: dashboard.showAvatar and dashboard.showSystemSummary. Greeter:
showAvatar. Defaults are true. CircleAvatar keeps its fallback during loading
and failed decoding. DateTime uptime updates only from FileView.onLoaded and
holds a minute timer while a visible summary owns a watcher; retained hidden
panels do not retain that lease. Native tests: account_profile_test under
dbus-run-session; UI: tools/test-ui.py and tools/test-greeter.py. Use the built
GreeterData import path for lint/compile checks before installing new plugins.
