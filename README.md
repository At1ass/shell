# Quickshell Configuration

Минималистичная конфигурация Quickshell для Hyprland.

## Философия

- **Config over GUI** - все настройки через JSON
- **Keyboard-first** - быстрый доступ через keybinds
- **Minimal but powerful** - только необходимое
- **Material Design 3** - современный дизайн

## Установка

```bash
# Скопировать конфигурацию
cp -r shell ~/.config/quickshell/

# Создать пользовательский конфиг
mkdir -p ~/.config/shell
cp ~/.config/quickshell/shell/config/default.json ~/.config/shell/config.json

# Запустить
quickshell -c shell
```

## Конфигурация

Все настройки находятся в `~/.config/shell/config.json`.

### Основные разделы:

- `appearance` - тема, spacing, анимации
- `bar` - настройки панели и виджетов
- `dashboard` - вкладки и содержимое
- `notifications` - панель уведомлений
- `launcher` - поиск приложений
- `services` - погода, календарь, VPN

### Пример конфигурации:

```json
{
  "bar": {
    "position": "top",
    "height": 48,
    "widgets": [
      {"type": "workspaces", "enabled": true},
      {"type": "clock", "enabled": true}
    ]
  },
  "dashboard": {
    "defaultTab": "quick",
    "tabs": [
      {
        "id": "quick",
        "widgets": ["volume-slider", "brightness-slider"]
      }
    ]
  }
}
```

### Hot Reload

Конфиг автоматически перезагружается при изменении файла.

## Горячие клавиши

- `Super+D` - Dashboard (Quick tab)
- `Super+Space` - Launcher
- `Super+N` - Notifications (опционально)

## Структура

```
shell/
├── config/
│   └── default.json          # Дефолтная конфигурация
├── src/
│   ├── core/
│   │   ├── config/          # Config singleton
│   │   └── services/        # Сервисы
│   ├── features/
│   │   ├── bar/            # Панель
│   │   ├── dashboard/      # Dashboard с вкладками
│   │   ├── notifications/  # Уведомления
│   │   └── launcher/       # Лаунчер
│   └── ui/                 # UI компоненты
└── plugins/                # C++ плагины
```

## Dashboard

### Вкладки:

1. **Quick** - Быстрые настройки (volume, brightness, wifi, bluetooth)
2. **Media** - Медиаплеер и устройства вывода
3. **Calendar** - Календарь и события
4. **System** - Погода, мониторинг, расширенные настройки

### Доступ:

- `Super+D` - Открыть Dashboard
- Клик на виджет в баре - Открыть соответствующую вкладку
- `ESC` - Закрыть

## Notification Center

Отдельная панель для уведомлений (справа).

- Клик на 🔔 в баре - Открыть/закрыть
- Группировка по приложениям
- Do Not Disturb режим (правый клик на 🔔)

## Bar Widgets

Конфигурируемые виджеты в баре:

- `workspaces` - Рабочие столы Hyprland
- `media` - Текущий трек (клик → Media tab)
- `notifications` - Уведомления (клик → Notification Center)
- `volume` - Громкость (скролл для изменения)
- `network` - Сеть
- `battery` - Батарея
- `clock` - Время (клик → Quick tab)

## Разработка

```bash
# Создать ветку для изменений
git checkout -b feature-name

# Тестировать изменения
quickshell -c shell --replace

# Создать коммит
git add .
git commit -m "feat: ..."
```

## Material Design 3

Используется C++ плагин Mcu для Material Design 3:

- Динамические цвета из обоев
- Material motion
- Material typography
- Material shapes и spacing

## Зависимости

- `quickshell-git` - Shell framework
- `hyprland` - Window manager
- Qt6 (declarative, multimedia)

### Опциональные:

- `cava` - Audio visualizer (будущее)
- `cliphist` - Clipboard history
