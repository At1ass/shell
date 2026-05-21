# ROADMAP

Открытые задачи по следам недавних рефакторов и систематического аудита подсистем. Сгруппированы по area + tier (severity × frequency × ROI).

История недавних рефакторов в ветке `dashboard-refactor`:
- `feat(calendar): replace khal CLI with libical C++ plugin` — calendar полностью на нативный плагин
- 6 коммитов notifications subsystem — declarative lifecycle, decomposition god-object'а на 4 фокусных singleton'а
- 5 коммитов wallpaper subsystem — pluggable provider model + Wallhaven с полным API v1 search

---

## Tier 1 — Security / hygiene quick fixes (~30 мин суммарно)

Точечные правки, низкий риск, локализованы в одном файле каждая.

### `ScreenshotService.qml` — template injection
Строки `19, 28`:
```qml
command: ["sh", "-c", `sleep 0.2 && grim -g "${root._grimGeometry}" - | wl-copy`]
```
`_grimGeometry` приходит из ScreenshotOverlay (внутренний источник, эксплуатация маловероятна), но `bash -c` с template literal — плохая форма. Заменить на argv chain через два Process'а (grim + pipe → wl-copy/swappy).

### `ClipboardService.qml:208` — shell concat
```qml
thumbDecodeProc.command = ["sh", "-c", "mkdir -p '" + root._thumbnailDir + "' && " + root.cliphistBinary + " decode > '" + thumbDecodeProc._outPath + "'"]
```
`item.id` от cliphist числовой, эксплуатация маловероятна, но паттерн зеркалит calendar `deleteEvent` баг (уже починен). Заменить на `QDir().mkpath(...)` для каталога + `Process` с argv для cliphist + redirect через stdin/stdout.

### `EthernetService.qml:77` — defense-in-depth
```qml
speedProc.command = ["cat", "/sys/class/net/" + root.interfaceName + "/speed"]
```
`interfaceName` от nmcli, реально безопасен. Добавить regex-валидацию `^[a-zA-Z0-9_-]+$` для гигиены.

### `GlobalStates.qml:140` — DBus parse precision
```qml
data.includes("Lock")
```
Матчит и "UnLock". Заменить на `data.includes(".Lock ")` или regex-anchor.

---

## Tier 2 — Subprocess → DBus (3-4 часа)

### `BluetoothService.qml:20` — bluetoothctl infinite loop
```qml
command: ["sh", "-c", "{ echo 'agent KeyboardDisplay'; ... while true; do sleep 0.5; echo 'yes'; done; } | bluetoothctl"]
```
- Infinite loop без exit handler
- Если bluetoothctl падает, процесс висит ждать I/O
- Поллинг каждые 2с для device list

**Правильный путь**: native D-Bus через `Quickshell.Io.DBus` к `org.bluez`. Pattern уже использован в `MprisController.qml`. Готовый шаблон для будущих subprocess→DBus миграций. Подсистема — чистый кейс отказа от subprocess в пользу нативного API.

---

## Wallpaper — отложенные расширения

### Stage E — Wallpaper Picker UI (~3-5 часов)
Нижняя панель браузера source items с thumbnails. Архитектурно прозрачно — `WallpaperSourceRegistry.getSource(id).items` уже всё даёт. UI:
- Bottom panel (как cheatsheet, layer)
- Tabs по source ids
- Grid из thumbnail Image с lazy loading
- Click on thumbnail → `WallpaperManager.setMonitorSource + setItem`
- Per-source actions: refresh, loadMore, для wallhaven — search bar с onAccepted → query

### Wallhaven — endpoints помимо /search
- **`/w/{id}`** — single wallpaper details (used когда пользователь добавил конкретный wallpaper-ID)
- **`/tag/{id}`** — tag info
- **`/collections/{username}/{id}`** — содержимое коллекции (важно: «использовать мою Wallhaven-коллекцию как источник»)
- Настройка: либо новый source type `wallhaven-collection`, либо опц. `collectionId + username` в существующем

### Другие remote sources
По паттерну Wallhaven (~250 LOC каждый):
- **Unsplash** — `/photos/random` или `/search/photos`, нужен Access Key (env var)
- **Reddit** — `/r/wallpapers/.json`, без auth, проще всего
- **Bing wallpaper** — `/HPImageArchive.aspx` без auth

### Wallpaper migration helper
Программный конвертер старого config (`wallpaper.global.directory + monitors[].directory`) в новый (`sources[] + monitors[].sourceId`). Решение Stage B — пользователь правит руками. Может пригодиться для других пользователей если когда-нибудь станет публичным проектом.

### Per-monitor query overrides для Wallhaven
В Stage D у source один `query`, все monitors разделяют. Чтобы каждый monitor имел свой query/categories — нужно либо несколько Wallhaven sources, либо `monitors[].sourceQueryOverride`. Пока решается через несколько sources.

---

## Notifications — отложенные

### Tests (Qt Test framework)
По паттерну calendar (`src/plugins/src/calendar-qml/test/`). Можно тестировать logic-only singletons:
- `NotificationRateLimiter` — token bucket math, queue behavior
- `NotificationHistory` — TTL pruning, grouping, persistence roundtrip

UI popup тесты сложны (требуют сцену) — out of scope.

### `services.notifications.dnd.suppressOnFullscreen` config
Сейчас hardcoded `true` в `NotificationDND.qml`. Если нужно отключаемо — добавить:
- AppConfig reader
- schema entry
- Чтение в NotificationDND через `?? true`

15 строк работы.

### Inline reply support
Quickshell поддерживает `notification.sendInlineReply(text)`. Требует UI text input в popup. Для notifications которые declare `inlineReplyPlaceholder` (Slack, Discord, Telegram, etc).

### Action icons
`actionIconsSupported` capability — currently не объявлено и UI не показывает иконки на actions. Если объявить — clients начнут слать `iconName` в action и ожидать рендер иконки рядом с текстом.

### Persistent notifications через `keepOnReload: true`
Сейчас `keepOnReload: false` + JSON file для history. Альтернатива — Quickshell-managed retention. Не очевидно что лучше; текущее работает.

---

## Calendar — отложенные

### Stage E полировка UI (низкий приоритет)
Из аудита были предложения, но в рефактор не вошли:
- Локализация дней недели (`Qt.locale().dayName(i, Locale.ShortFormat)`)
- "Today" button в шапке
- Multi-day events в timeline-view (сейчас фильтрует по `!ev.allDay && ev.start === selectedDate.date`)
- Drag-to-reschedule в day timeline
- Confirm-on-close в EventDialog при unsaved changes (есть, но можно расширить)
- Search по событиям

Все QML-only, ничего не блокирует.

---

## Out of scope

- **Полная замена subprocess-based services на DBus/native** — большой проект; делается по одному за раз (BluetoothService первый)
- **Cross-shell pattern share** — наработки из этих рефакторов (BaseProvider, NotifData wrapper, source registry) можно вынести в reusable patterns если когда-нибудь делать форк/share
- **CI / unit tests для всего** — selectively по mission-critical компонентам, не везде
