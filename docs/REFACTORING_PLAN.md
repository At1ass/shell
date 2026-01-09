# Dashboard Refactoring Plan

**Ветка:** `dashboard-refactor`
**Дата начала:** 2026-01-10
**Дата завершения:** 2026-01-10
**Статус:** ✅ Завершен

## Цели рефакторинга

1. **Упрощение Dashboard** - убрать перегруженность Main tab
2. **Конфигурация > GUI** - все настройки через JSON
3. **Разделение ответственности** - Notifications отдельно от Dashboard
4. **Tiling WM философия** - минимализм и эффективность

## Задачи

### ✅ 1. Создать структуру конфигурации
- [x] Создать `config/default.json` с полной схемой
- [x] Определить структуру для bar, dashboard, notifications
- [x] Добавить конфигурацию виджетов

**Файлы:**
- `config/default.json` - дефолтная конфигурация

### ✅ 2. Создать систему загрузки конфига
- [x] Обновить `Config.qml` для загрузки JSON
- [x] Добавить FileView для hot reload
- [x] Fallback на default.json

**Файлы:**
- `src/core/config/Config.qml` - обновлен

### ✅ 3. Реорганизовать Dashboard на вкладки

**План:**
```
Dashboard:
├── Quick (Super+D)
│   ├── Volume slider
│   ├── Brightness slider
│   ├── WiFi toggle
│   ├── Bluetooth toggle
│   ├── Night Light toggle
│   └── Upcoming events (2)
├── Media
│   ├── Player controls
│   └── Output device selector
├── Calendar
│   ├── Month view
│   └── Event list
└── System
    ├── Weather (detailed)
    ├── System Monitor
    └── Audio Advanced
```

**Созданные файлы:**
- ✅ `src/features/dashboard/tabs/QuickTab.qml` - упрощенная вкладка с volume, brightness, quick toggles, 2 события
- ✅ `src/features/dashboard/tabs/MediaTab.qml` - медиаплеер
- ✅ `src/features/dashboard/tabs/CalendarTab.qml` - календарь и события
- ✅ `src/features/dashboard/tabs/SystemTab.qml` - погода, system monitor, audio advanced
- ✅ `src/features/dashboard/tabs/qmldir` - регистрация модулей

**Обновленные файлы:**
- ✅ `src/features/dashboard/DashboardContent.qml` - использует новые вкладки

**Удалено из Quick tab:**
- ✅ Трей (был в MainTab, больше не нужен)
- ✅ Погода (→ System tab)
- ✅ System Monitor (→ System tab)
- ✅ CavaElement (аудио визуализатор)
- ✅ ClockElement (дублирует бар)
- ✅ UserInfoElement (избыточно)

### ✅ 4. Вынести Notification Center в отдельную панель

**План:**
```
NotificationCenter (отдельная панель справа):
├── Header (title + count + clear all)
├── Notifications list (grouped by app)
└── Footer (settings + DND toggle)
```

**Статус:**
- ✅ NotificationCenter уже был реализован как отдельная панель
- ✅ Добавлен правый клик для DND toggle
- ✅ Визуальный индикатор DND (иконка notifications_off, tertiary color)
- ✅ Левый клик → Toggle Notification Center
- ✅ Правый клик → Toggle DND
- ✅ Может быть открыт одновременно с Dashboard

**Обновленные файлы:**
- ✅ `src/features/statusbar/NotificationWidget.qml` - добавлен DND toggle

### ✅ 5. Реорганизовать Bar widgets

**Реализовано:**
- ✅ Добавлена функция `openDashboardTab(tabIndex)` в GlobalStates
- ✅ ClockWidget: правый клик → Quick tab (index 0)
- ✅ VolumeWidget:
  - Левый клик → mute/unmute
  - Правый клик → Quick tab (index 0)
  - Скролл → изменение громкости
- ✅ MPRISWidget: правый клик → Media tab (index 1)
- ✅ NotificationWidget:
  - Левый клик → Toggle NotificationCenter
  - Правый клик → Toggle DND

**Обновленные файлы:**
- ✅ `src/core/services/GlobalStates.qml` - добавлена функция openDashboardTab
- ✅ `src/features/statusbar/ClockWidget.qml`
- ✅ `src/features/statusbar/VolumeWidget.qml`
- ✅ `src/features/statusbar/MPRISWidget.qml`

### ✅ 6. Упростить Dashboard

**Что убрали из MainTab → QuickTab:**
- ✅ Трей из Main tab (дублирует бар)
- ✅ Погоду из Main tab (→ System tab)
- ✅ System Monitor из Main tab (→ System tab)
- ✅ CavaElement (аудио визуализатор)
- ✅ ClockElement (дублирует бар)
- ✅ UserInfoElement (избыточно)
- ✅ MediaPlayerElement (→ Media tab)

**Что оставили в Quick:**
- ✅ Volume slider (вертикальный)
- ✅ Brightness slider (вертикальный)
- ✅ QuickActionsElement (WiFi, Bluetooth, Night Light toggles)
- ✅ SheduleElement - 2 upcoming events (не 3!)

### ✅ 7. Интегрировать клики на Bar widgets

**Реализовано:**
- ✅ Функция `GlobalStates.openDashboardTab(tabIndex)` вместо отдельного сервиса
- ✅ Все виджеты поддерживают right-click для открытия Dashboard
- ✅ VolumeWidget: scroll для громкости, left-click для mute
- ✅ NotificationWidget: left-click для center, right-click для DND

### ✅ 8. Обновить документацию

- [x] README.md - основная документация
- [x] REFACTORING_PLAN.md - обновлен со всеми выполненными задачами

## Принципы рефакторинга

### 1. Backwards Compatibility
- Сохранить существующие сервисы
- Не ломать API
- Graceful fallback при ошибках конфига

### 2. Progressive Enhancement
- Базовая функциональность работает всегда
- Расширенные фичи через конфиг
- Валидация с defaults

### 3. Separation of Concerns
```
Config (JSON) → Config.qml → Services → UI Components
```

### 4. Testing Strategy
- Тестировать каждую вкладку отдельно
- Проверять hot reload конфига
- Тестировать с отсутствующим конфигом

## Структура после рефакторинга

```
shell/
├── config/
│   └── default.json                    # ✅ Создан
├── src/
│   ├── core/
│   │   ├── config/
│   │   │   └── Config.qml             # ✅ Обновлен
│   │   └── services/
│   │       ├── DashboardService.qml   # ⏳ Создать
│   │       └── ...
│   ├── features/
│   │   ├── dashboard/
│   │   │   ├── Dashboard.qml          # ⏳ Обновить
│   │   │   ├── DashboardTabs.qml      # ⏳ Создать
│   │   │   └── tabs/                  # ⏳ Создать
│   │   │       ├── QuickTab.qml
│   │   │       ├── MediaTab.qml
│   │   │       ├── CalendarTab.qml
│   │   │       └── SystemTab.qml
│   │   ├── notifications/
│   │   │   ├── NotificationCenter.qml # ⏳ Создать
│   │   │   ├── NotificationItem.qml   # ⏳ Создать
│   │   │   └── NotificationPopup.qml  # ✅ Существует
│   │   └── statusbar/
│   │       └── *Widget.qml            # ⏳ Обновить (clickAction)
│   └── ui/
│       └── ...
└── README.md                           # ✅ Создан
```

## Миграция для пользователей

### Шаг 1: Создать конфиг
```bash
mkdir -p ~/.config/shell
cp ~/.config/quickshell/shell/config/default.json ~/.config/shell/config.json
```

### Шаг 2: Настроить под себя
Редактировать `~/.config/shell/config.json`:
- Изменить позицию бара
- Включить/отключить виджеты
- Настроить вкладки Dashboard

### Шаг 3: Запустить
```bash
quickshell -c shell --replace
```

Конфиг автоматически перезагрузится при изменениях!

## Breaking Changes

### Нет! 🎉

Все изменения обратно совместимы:
- Если нет config.json → используется default.json
- Старые компоненты продолжают работать
- Новая функциональность опциональна

## Timeline

- **День 1** (сегодня): Config system + README ✅
- **День 2**: Dashboard tabs + вкладки
- **День 3**: Notification Center отдельно
- **День 4**: Bar widgets интеграция
- **День 5**: Упрощение Dashboard
- **День 6**: Тестирование + документация
- **День 7**: Merge в main

## Notes

- Использовать TodoWrite для отслеживания прогресса
- Коммитить после каждой завершенной задачи
- Тестировать на реальном Hyprland
- Обновлять этот документ по мере продвижения

## Questions & Decisions

### Q: Где хранить config.json?
**A:** `~/.config/shell/config.json` (отдельно от shell code)

### Q: Notification Center - отдельная панель или вкладка?
**A:** Отдельная панель (более логично для тайлингового WM)

### Q: Сколько upcoming events показывать?
**A:** 2 (не 3) - меньше clutter

### Q: Удалить трей из Dashboard?
**A:** Да, он уже в баре (дублирование)

### Q: Hot reload конфига?
**A:** Да, через FileView.watchChanges

## Success Criteria

- ✅ Config.json работает (default.json с полной схемой)
- ✅ Hot reload работает (FileView.watchChanges)
- ✅ Dashboard с 4 вкладками (Quick, Media, Calendar, System)
- ✅ Notification Center отдельно (отдельная панель справа)
- ✅ Bar widgets с clickAction (правый клик открывает Dashboard tabs)
- ✅ Quick tab не перегружен (только volume, brightness, toggles, 2 события)
- ✅ Документация полная (README.md, REFACTORING_PLAN.md)
- ✅ Backwards compatible (старые компоненты работают, graceful fallback)

## References

- Caelestia shell: https://github.com/caelestia-dots/shell
- Noctalia shell: https://github.com/noctalia-dev/noctalia-shell
- Material Design 3: https://m3.material.io/
- Quickshell docs: https://quickshell.outfoxxed.me/
