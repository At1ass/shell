# Quickshell Shell

Современная конфигурация Hyprland shell на базе [Quickshell](https://quickshell.outfoxxed.me/) с дизайном Material Design 3.

## Возможности

| Компонент | Описание |
|-----------|----------|
| **Status Bar** | Настраиваемые виджеты: воркспейсы, активное окно, часы, погода, медиа, уведомления, громкость, сеть, батарея, раскладка, трей |
| **Dashboard** | 4-вкладочный центр управления: Quick, Weather, Calendar, System |
| **Launcher** | Поиск приложений с fuzzy matching + калькулятор + история буфера обмена |
| **Notification Center** | Панель уведомлений с историей, группировкой по приложениям, DND |
| **OSD** | Оверлеи громкости и яркости |
| **Toast** | Всплывающие уведомления уровней info / success / warning / error |
| **Screenshot** | Выбор области мышью или клавиатурой (hjkl), аннотации через swappy |
| **Gaming Mode** | Авто-отключение анимаций/blur/shadows в Hyprland, восстановление при выключении |
| **Wallpaper** | Мультимониторное управление обоями с автосменой |
| **Power Menu** | Lock / Suspend / Reboot / Shutdown / Logout |
| **Lockscreen** | Интеграция с WlSessionLock |
| **Cheatsheet** | Интерактивный справочник keybindings (Hyprland + Shell) и IPC-команд |

---

## Зависимости

### Обязательные

| Пакет | Назначение |
|-------|------------|
| `quickshell-git` | Shell framework (Wayland, QML) |
| `hyprland` | Compositor (используются ext-global-shortcuts, WlrLayershell, HyprlandFocusGrab) |
| `qt6-base`, `qt6-declarative` | Qt6 runtime |
| `pipewire` + `wireplumber` | Аудио — для виджета громкости и OSD |

### Опциональные

| Пакет | Назначение |
|-------|------------|
| `grim` | Скриншоты (нужен для Screenshot overlay) |
| `wl-clipboard` | Копирование скриншота в буфер (`wl-copy`) |
| `swappy` | Аннотации скриншотов |
| `ddcutil` | Яркость внешних мониторов через DDC/CI |
| `cliphist` | История буфера обмена в launcher |
| `qalculate-glib` | Калькулятор в launcher (нужен при сборке плагина) |
| `libnotify` | Напоминания о событиях календаря (`notify-send`) |
| `networkmanager` | Виджет сети и статус VPN |
| `bluez` | Статус Bluetooth в Dashboard |

### Зависимости сборки (C++ плагины)

| Пакет | Назначение |
|-------|------------|
| `cmake` + `ninja` | Система сборки |
| `qt6-tools` | `moc`, `rcc` |
| `qalculate-glib` | Заголовки для плагина калькулятора |

---

## Установка

### 1. Клонировать / скопировать

```bash
git clone <repo> ~/.config/quickshell/shell
# или просто скопировать директорию shell в ~/.config/quickshell/
```

### 2. Собрать C++ плагины

```bash
cd ~/.config/quickshell/shell/src/plugins
cmake -B build -S . -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
```

Плагины: Material Color Utilities (динамические цвета), FuzzySearch (поиск), Qalculate (калькулятор), SystemMonitor (мониторинг системы).

### 3. Создать конфиг пользователя

```bash
cp ~/.config/quickshell/shell/config/default.json \
   ~/.config/quickshell/shell/config.json
```

Конфиг также читается из `~/.config/quickshell/shell/config.json`. При отсутствии используется `config/default.json` как fallback.

### 4. Настроить конфиг

Минимальные изменения — установить координаты и название города для погоды:

```json
"services": {
  "weather": {
    "location": "Москва",
    "latitude": 55.75,
    "longitude": 37.62
  }
}
```

### 5. Добавить keybinds в `hyprland.conf`

Горячие клавиши регистрируются через `GlobalShortcut` — привязываются в Hyprland:

```conf
# Панели
bind = SUPER, D,      global, quickshell:controlPanelToggle
bind = SUPER, SPACE,  global, quickshell:launcherToggle
bind = SUPER, Escape, global, quickshell:powerMenuToggle
bind = SUPER, F1,     global, quickshell:cheatsheetToggle

# Скриншоты
bind = SUPER,       Print, global, quickshell:screenshot
bind = SUPER SHIFT, Print, global, quickshell:screenshotSwappy

# Аудио
bind = , XF86AudioRaiseVolume, global, quickshell:audioVolumeUp
bind = , XF86AudioLowerVolume, global, quickshell:audioVolumeDown
bind = , XF86AudioMute,        global, quickshell:audioToggleMute

# Яркость (DDC/CI мониторы)
bind = , XF86MonBrightnessUp,   global, quickshell:brightnessUp
bind = , XF86MonBrightnessDown, global, quickshell:brightnessDown

# Gaming mode
bind = SUPER ALT, G, global, quickshell:gamingModeToggle
```

### 6. Запустить

```bash
quickshell -c shell
```

Или добавить в автозапуск Hyprland:

```conf
exec-once = quickshell -c shell
```

---

## Конфигурация

Файл: `~/.config/quickshell/shell/config.json`

**Hot-reload**: конфиг отслеживается — изменения применяются без перезапуска.

Полная документация всех полей: [`config/config.schema.json`](config/config.schema.json)

Референсный конфиг со значениями по умолчанию: [`config/default.json`](config/default.json)

### Структура конфига

```
appearance.theme         — тема (source, variant, darkMode)
appearance.fontScale     — масштаб шрифтов (0.5–2.0)
bar                      — панель и виджеты
bar.transparent          — прозрачный фон бара
dashboard                — размеры центра управления
notifications            — попапы и центр уведомлений
launcher                 — поиск и провайдеры
osd                      — оверлеи громкости/яркости
lockscreen               — экран блокировки
powerMenu                — меню питания
gamingMode               — игровой режим
wallpaper                — управление обоями
services.weather         — погода (Open-Meteo, без API ключа)
services.calendar        — напоминания о событиях
services.vpn             — статус VPN (NetworkManager)
hyprland.workspaceCount  — количество воркспейсов
```

### Виджеты бара

Каждый виджет в массиве `bar.widgets` имеет общие поля:

| Поле | Описание |
|------|----------|
| `type` | Тип виджета (см. таблицу ниже) |
| `enabled` | Включён или нет |
| `section` | `"left"` / `"center"` / `"right"` |
| `monitors` | `"all"` или имя монитора (`"DP-2"`) или массив |
| `clickAction` | Действие при клике (см. список ниже) |
| `settings` | Параметры конкретного виджета |

Доступные типы виджетов:

| Тип | Описание |
|-----|----------|
| `workspaces` | Воркспейсы Hyprland с индикаторами окон |
| `activewindow` | Заголовок и иконка активного окна |
| `weather` | Текущая погода |
| `clock` | Дата / время (настраиваемый формат) |
| `media` | Текущий трек (MPRIS) |
| `notifications` | Колокольчик с бейджем |
| `volume` | Громкость (скролл для изменения) |
| `network` | WiFi / Ethernet статус |
| `battery` | Заряд батареи |
| `layout` | Текущая раскладка клавиатуры |
| `tray` | Системный трей |

Доступные `clickAction`:

| Значение | Действие |
|----------|----------|
| `dashboard-quick` | Открыть Dashboard на вкладке Quick |
| `dashboard-weather` | Открыть Dashboard на вкладке Weather |
| `dashboard-calendar` | Открыть Dashboard на вкладке Calendar |
| `dashboard-system` | Открыть Dashboard на вкладке System |
| `notification-center` | Открыть/закрыть центр уведомлений |
| `launcher` | Открыть launcher |
| `control-panel` | Открыть правую панель управления |

---

## IPC команды

Управление шеллом извне:

```bash
qs ipc call <handler> <function> [аргумент]
```

### `globalstates`

```bash
# Dashboard
qs ipc call globalstates toggleDashboard
qs ipc call globalstates openDashboardTab 0   # 0=Quick 1=Weather 2=Calendar 3=System

# Control Panel (правая панель)
qs ipc call globalstates toggleControlPanel
qs ipc call globalstates openControlPanel
qs ipc call globalstates closeControlPanel
qs ipc call globalstates openControlPanelLeft
qs ipc call globalstates closeControlPanelLeft

# Launcher
qs ipc call globalstates toggleLauncher
qs ipc call globalstates openLauncher
qs ipc call globalstates closeLauncher

# Notification Center
qs ipc call globalstates toggleNotificationCenter
qs ipc call globalstates openNotificationCenter
qs ipc call globalstates closeNotificationCenter

# Скриншоты
qs ipc call globalstates screenshot          # область → буфер обмена
qs ipc call globalstates screenshotSwappy    # область → swappy

# Power
qs ipc call globalstates togglePowerMenu
qs ipc call globalstates openPowerMenu
qs ipc call globalstates closePowerMenu
qs ipc call globalstates lockScreen

# Gaming Mode
qs ipc call globalstates toggleGamingMode
qs ipc call globalstates enableGamingMode
qs ipc call globalstates disableGamingMode

# Cheatsheet
qs ipc call globalstates toggleCheatsheet
qs ipc call globalstates openCheatsheet
qs ipc call globalstates closeCheatsheet

# Прочее
qs ipc call globalstates closeAll
```

### `audio`

```bash
qs ipc call audio volumeUp
qs ipc call audio volumeDown
qs ipc call audio setVolume 0.5       # 0.0 – 1.0
qs ipc call audio toggleMute
qs ipc call audio getMasterVolume     # возвращает текущую громкость
qs ipc call audio isMuted
```

### `mpris`

```bash
# Воспроизведение
qs ipc call mpris play
qs ipc call mpris pause
qs ipc call mpris stop
qs ipc call mpris togglePlaying
qs ipc call mpris next
qs ipc call mpris previous
qs ipc call mpris seek 10             # перемотка на 10 секунд
qs ipc call mpris setPosition 30      # перейти к позиции (секунды)

# Громкость плеера
qs ipc call mpris setVolume 0.8
qs ipc call mpris volumeUp
qs ipc call mpris volumeDown
qs ipc call mpris getVolume

# Режимы
qs ipc call mpris toggleShuffle
qs ipc call mpris toggleLoop

# Информация
qs ipc call mpris getCurrentTrack
qs ipc call mpris isPlaying
qs ipc call mpris getPosition         # текущая позиция (секунды)
qs ipc call mpris getLength           # длительность трека (секунды)

# Управление плеером
qs ipc call mpris raise               # показать окно плеера
qs ipc call mpris quit                # закрыть плеер
```

### `wallpaper`

```bash
# Установка обоев
qs ipc call wallpaper set DP-1 /path/to/image.jpg
qs ipc call wallpaper setAll /path/to/image.jpg

# Навигация
qs ipc call wallpaper next            # следующие обои на всех мониторах
qs ipc call wallpaper next DP-1       # следующие обои на конкретном мониторе
qs ipc call wallpaper previous

# Настройки
qs ipc call wallpaper setDirectory /path/to/wallpapers
qs ipc call wallpaper setAutoChange true 300000
qs ipc call wallpaper setRandom true
qs ipc call wallpaper setFillMode DP-1 2      # Qt Image.FillMode (2=PreserveAspectCrop)
qs ipc call wallpaper setFillModeAll 2

# Информация
qs ipc call wallpaper status          # текущее состояние всех мониторов (JSON)
```

---

## Управление скриншотами с клавиатуры

При открытом оверлее выделения:

| Клавиша | Действие |
|---------|----------|
| `h` / `←` | Курсор влево |
| `j` / `↓` | Курсор вниз |
| `k` / `↑` | Курсор вверх |
| `l` / `→` | Курсор вправо |
| `Shift` + движение | Большой шаг (40px) |
| Удержание клавиши | Ускоренное движение (16px/шаг) |
| `Space` | Поставить якорь (первый раз) / Сделать скриншот (второй раз) |
| `Enter` | Сделать скриншот выделенной области |
| `ПКМ` / `Esc` | Отмена |

Навигация работает в любой раскладке клавиатуры.

---

## Структура проекта

```
shell/
├── shell.qml                    # Точка входа
├── config.json                  # Пользовательский конфиг (создаётся вручную)
├── config/
│   ├── default.json             # Референсный конфиг / fallback
│   └── config.schema.json       # JSON Schema с описанием всех полей
├── src/
│   ├── core/
│   │   ├── config/
│   │   │   └── AppConfig.qml    # Центральный синглтон конфига
│   │   └── services/            # Все сервисы (аудио, сеть, погода, …)
│   ├── features/
│   │   ├── statusbar/           # Панель и виджеты
│   │   ├── dashboard/           # 4-вкладочный центр управления
│   │   ├── launcher/            # Поиск приложений
│   │   ├── notifications/       # Центр уведомлений и попапы
│   │   ├── osd/                 # VolumeOSD, BrightnessOSD, ToastOverlay
│   │   ├── screenshot/          # Оверлей выбора области
│   │   ├── cheatsheet/          # Справочник горячих клавиш
│   │   ├── lockscreen/          # Экран блокировки
│   │   ├── powermenu/           # Меню питания
│   │   ├── popouts/            # Popouts (трей-меню, контекстные панели)
│   │   └── background/          # Обои
│   ├── plugins/
│   │   └── src/                 # C++ плагины (требуют сборки)
│   │       ├── mcu-qml/         # Material Color Utilities
│   │       ├── fuzzy-search-qml/# Fuzzy matching
│   │       ├── qalculate-qml/   # Калькулятор
│   │       └── system-monitor-qml/ # Мониторинг CPU/RAM/…
│   └── ui/                      # Переиспользуемые MD3 компоненты
└── docs/                        # Дополнительная документация
```

---

## Устойчивое состояние

Состояние, сохраняемое между перезапусками (`~/.config/quickshell/state.json`):

- **Gaming Mode** — активен или нет, сохранённые настройки Hyprland для восстановления
- **Wallpaper** — текущие обои для каждого монитора

---

## Горячие клавиши шелла

Полный список шорткатов для `hyprland.conf` (`bind = ..., global, quickshell:<name>`):

| Имя шортката | Действие |
|-------------|----------|
| `controlPanelToggle` | Открыть/закрыть правую панель управления |
| `launcherToggle` | Открыть/закрыть launcher |
| `closeAllPanels` | Закрыть все открытые панели |
| `screenshot` | Выделить область → скриншот в буфер |
| `screenshotSwappy` | Выделить область → открыть в swappy |
| `powerMenuToggle` | Открыть/закрыть меню питания |
| `cheatsheetToggle` | Открыть/закрыть справочник |
| `gamingModeToggle` | Включить/выключить gaming mode |
| `audioVolumeUp` | Громкость +5% |
| `audioVolumeDown` | Громкость −5% |
| `audioToggleMute` | Заглушить/включить звук |
| `brightnessUp` | Яркость +5% (DDC/CI) |
| `brightnessDown` | Яркость −5% (DDC/CI) |
