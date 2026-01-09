# Dashboard Refactoring Plan

**Ветка:** `dashboard-refactor`
**Дата:** 2026-01-10
**Статус:** В процессе

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

### 🔄 2. Создать систему загрузки конфига
- [x] Обновить `Config.qml` для загрузки JSON
- [x] Добавить FileView для hot reload
- [x] Fallback на default.json
- [ ] Валидация конфига

**Файлы:**
- `src/core/config/Config.qml` - обновлен

### ⏳ 3. Реорганизовать Dashboard на вкладки

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

**Файлы для создания:**
- `src/features/dashboard/DashboardTabs.qml`
- `src/features/dashboard/tabs/QuickTab.qml`
- `src/features/dashboard/tabs/MediaTab.qml`
- `src/features/dashboard/tabs/CalendarTab.qml`
- `src/features/dashboard/tabs/SystemTab.qml`

**Удалить из Dashboard:**
- ❌ Трей (дублирует бар)
- ❌ Погоду из Quick (→ System tab)
- ❌ System Monitor из Quick (→ System tab)

### ⏳ 4. Вынести Notification Center в отдельную панель

**План:**
```
NotificationCenter (отдельная панель справа):
├── Header (title + count + clear all)
├── Notifications list (grouped by app)
└── Footer (settings + DND toggle)
```

**Файлы для создания:**
- `src/features/notifications/NotificationCenter.qml`
- `src/features/notifications/NotificationItem.qml`
- `src/features/notifications/NotificationGroup.qml`

**Интеграция:**
- Клик на 🔔 в баре → Toggle Notification Center
- Правый клик на 🔔 → Toggle DND
- Может быть открыт одновременно с Dashboard

### ⏳ 5. Реорганизовать Bar widgets

**Новая структура:**
```json
{
  "bar": {
    "widgets": [
      {"type": "workspaces", "clickAction": "none"},
      {"type": "media", "clickAction": "dashboard-media"},
      {"type": "notifications", "clickAction": "notification-center"},
      {"type": "volume", "clickAction": "dashboard-quick", "scrollable": true},
      {"type": "clock", "clickAction": "dashboard-quick"}
    ]
  }
}
```

**Поведение:**
- `clickAction: "dashboard-quick"` → Открыть Dashboard на Quick tab
- `clickAction: "dashboard-media"` → Открыть Dashboard на Media tab
- `clickAction: "notification-center"` → Toggle Notification Center
- `scrollable: true` → Скролл для изменения значения

**Файлы для обновления:**
- `src/features/statusbar/StatusBar.qml`
- `src/features/statusbar/*Widget.qml` - добавить clickAction

### ⏳ 6. Упростить Dashboard

**Что убрать:**
- 🔧 Трей из Main tab (уже в баре)
- ☀️ Погоду из Main tab (→ System tab)
- 📊 System Monitor из Main tab (→ System tab)

**Что оставить в Quick:**
- 🔊 Volume slider
- ☀️ Brightness slider
- 📶 WiFi toggle
- 🔵 Bluetooth toggle
- 🌙 Night Light toggle
- 📅 2 upcoming events (не 3!)

**Файлы для обновления:**
- `src/features/dashboard/components/MainTab.qml` → `QuickTab.qml`
- Удалить ненужные элементы

### ⏳ 7. Интегрировать клики на Bar widgets

**Создать:**
- `src/core/services/DashboardService.qml` - управление Dashboard
- Метод `openTab(tabId)` для открытия конкретной вкладки

**Обновить:**
- Bar widgets для вызова `DashboardService.openTab()`
- `NotificationWidget` для toggle `NotificationCenter`

**Файлы:**
- `src/core/services/DashboardService.qml` - новый
- `src/features/statusbar/*Widget.qml` - обновить

### ⏳ 8. Обновить документацию

- [x] README.md - основная документация
- [ ] CONFIG.md - детальное описание конфига
- [ ] KEYBINDS.md - список горячих клавиш
- [ ] CHANGELOG.md - список изменений

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

- ✅ Config.json работает
- ✅ Hot reload работает
- ⏳ Dashboard с 4 вкладками
- ⏳ Notification Center отдельно
- ⏳ Bar widgets с clickAction
- ⏳ Quick tab не перегружен
- ⏳ Документация полная
- ⏳ Backwards compatible

## References

- Caelestia shell: https://github.com/caelestia-dots/shell
- Noctalia shell: https://github.com/noctalia-dev/noctalia-shell
- Material Design 3: https://m3.material.io/
- Quickshell docs: https://quickshell.outfoxxed.me/
