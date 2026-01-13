# 🎨 Workspace Icons - Caelestia Подход

## 📋 Обзор

Реализована система отображения иконок на воркспейсах по подходу **Caelestia** с Material Design Icons.

### Ключевые особенности

- ✅ **Material Icons** - символы вместо системных иконок
- ✅ **Категории приложений** - автоматическое определение по .desktop файлам
- ✅ **Горизонтальное расположение** - все иконки в ряд
- ✅ **Простота** - без hover, без сложной логики
- ✅ **Производительность** - нативное API Quickshell

---

## 🏗️ Архитектура

### Компоненты системы

```
src/core/services/
├── HyprlandWindowService.qml     # Работа с окнами
├── IconCategoryResolver.qml      # Категории → Material Icons
└── ...

src/features/statusbar/
└── WorkspaceWidget.qml            # Виджет с иконками
```

---

## 🎯 IconCategoryResolver

**Расположение**: `src/core/services/IconCategoryResolver.qml`

### Маппинг категорий

Словарь из Caelestia `utils/Icons.qml`:

```qml
readonly property var categoryIcons: ({
    WebBrowser: "web",           // 🌐
    Development: "code",          // 💻
    IDE: "code",
    TerminalEmulator: "terminal", // ▶️
    Game: "sports_esports",      // 🎮
    FileManager: "folder",       // 📁
    Audio: "music_note",         // 🎵
    Video: "videocam",           // 📹
    Graphics: "photo_library",   // 🖼️
    Email: "mail",               // ✉️
    // ... 30+ категорий
})
```

### API

#### `getAppCategoryIcon(windowClass, fallback)`

Получить Material Icon по категории приложения:

```qml
const icon = IconCategoryResolver.getAppCategoryIcon("Firefox", "terminal")
// Результат: "web"

const icon2 = IconCategoryResolver.getAppCategoryIcon("code", "terminal")
// Результат: "code"
```

**Алгоритм**:
1. Ищет класс окна через `DesktopEntries.heuristicLookup()`
2. Получает массив категорий из .desktop файла
3. Находит первую совпадающую категорию в словаре
4. Возвращает Material Icon или fallback

---

## 💡 WorkspaceWidget - Структура

### Визуализация

```
┌────────────────────────────┐
│  [○] [🌐▶️💻] [○] [○]     │  ← Workspace индикаторы
│   1      2      3    4      │     + Material Icons под ними
└────────────────────────────┘
```

### Детали

**Workspace без окон**:
```
[○]  ← Просто точка (индикатор)
 1
```

**Workspace с окнами**:
```
[○]  ← Индикатор
🌐▶️  ← Material Icons (Firefox + Terminal)
 2
```

### Код структуры

```qml
Column {
    id: wsItem
    spacing: 2

    // Индикатор воркспейса (точка)
    Rectangle {
        id: wsIndicator
        // ... цвет, анимации
    }

    // Ряд Material Icons
    Row {
        id: windowIconsRow
        spacing: 1

        Repeater {
            model: allWindows  // Все окна на воркспейсе

            MaterialIcon {
                iconName: IconCategoryResolver.getAppCategoryIcon(
                    modelData.lastIpcObject?.class,
                    "terminal"
                )
                fontSize: 14
                iconColor: active ? onPrimary : onSurfaceVariant

                MouseArea {
                    onClicked: {
                        // Фокус на конкретное окно
                        Hyprland.dispatch("focuswindow address:" + modelData.address)
                    }
                }
            }
        }
    }
}
```

---

## 🔧 HyprlandWindowService

Без изменений, используется для получения списка окон:

```qml
// Все окна на воркспейсе
allWindows: HyprlandWindowService.getWindowsForWorkspace(wsIndex)

// Обновление при изменениях
Connections {
    target: Hyprland.toplevels
    function onValuesChanged() {
        wsItem.updateWindowData()
    }
}
```

---

## 📊 Сравнение подходов

| Аспект | **Caelestia (текущий)** | **Гибридный (старый)** | **ii** |
|--------|-------------------------|------------------------|--------|
| Тип иконок | Material Icons (символы) | Системные иконки | Системные иконки |
| Количество | Все окна | 1 (+ все при hover) | 1 (самое большое) |
| Hover эффект | Нет | Да | Нет |
| Сложность | Низкая | Средняя | Высокая |
| Зависимости | Нет | Нет | Fuzzy search |
| Визуальная согласованность | Высокая (M3) | Средняя | Средняя |
| Определение иконки | Категория .desktop | Desktop entry + эвристики | Multi-step + fuzzy |

---

## ⚙️ Настройка

### Добавление новых категорий

Редактируйте `IconCategoryResolver.qml`:

```qml
readonly property var categoryIcons: ({
    // ... существующие
    MyCategory: "my_material_icon",
    AnotherCategory: "another_icon"
})
```

**Доступные Material Icons**: https://fonts.google.com/icons

### Изменение размера иконок

В `WorkspaceWidget.qml`:

```qml
MaterialIcon {
    fontSize: 14  // Измените размер (8-24)
    // ...
}
```

### Изменение цвета

```qml
MaterialIcon {
    iconColor: active
        ? Config.colors.onPrimary        // Цвет на активном воркспейсе
        : Config.colors.onSurfaceVariant // Цвет на неактивном
}
```

---

## 🎨 Примеры категорий

### Браузеры
- Firefox, Chrome, Chromium → `web` 🌐
- Tor Browser → `security` 🔒

### Разработка
- VSCode, IntelliJ → `code` 💻
- Terminal, Alacritty → `terminal` ▶️

### Медиа
- Spotify, VLC → `music_note` 🎵
- OBS, Kdenlive → `videocam` 📹

### Коммуникации
- Telegram, Discord → `chat` 💬
- Thunderbird → `mail` ✉️

### Игры
- Steam games → `sports_esports` 🎮

### Файлы
- Nautilus, Dolphin → `folder` 📁

---

## 🐛 Отладка

### Иконка не та, которую ожидаете?

1. **Проверьте категории приложения**:
   ```bash
   grep Categories /usr/share/applications/firefox.desktop
   # Результат: Categories=Network;WebBrowser;
   ```

2. **Добавьте категорию в словарь** если нужно:
   ```qml
   readonly property var categoryIcons: ({
       // ...
       YourCategory: "your_icon"
   })
   ```

### Fallback иконка

Если категория не найдена, используется fallback:
```qml
IconCategoryResolver.getAppCategoryIcon("Unknown", "terminal")
// → "terminal"
```

### Консоль отладки

Добавьте в `WorkspaceWidget.qml`:

```qml
Component.onCompleted: {
    console.log("Workspace", wsIndex, "windows:", allWindows.length)
    allWindows.forEach(w => {
        console.log("  Class:", w.lastIpcObject.class)
        console.log("  Icon:", IconCategoryResolver.getAppCategoryIcon(w.lastIpcObject.class))
    })
}
```

---

## ✅ Преимущества подхода Caelestia

1. **Простота**: Минимальный код, легко поддерживать
2. **Согласованность**: Все иконки в едином стиле Material Design
3. **Производительность**: Нет загрузки изображений, только символы
4. **Универсальность**: Работает с любыми приложениями
5. **Расширяемость**: Легко добавлять новые категории
6. **UX**: Сразу видно все окна, без hover

---

## 📝 Миграция с гибридного подхода

### Удалённые файлы:
- ❌ `IconResolver.qml` (системные иконки)

### Новые файлы:
- ✅ `IconCategoryResolver.qml` (Material Icons)

### Изменённые файлы:
- 🔄 `WorkspaceWidget.qml` - переход с Image на MaterialIcon

### Изменения в коде:
```qml
// Было (гибридный):
Image {
    source: IconResolver.getIconPath(windowClass, "image-missing")
}

// Стало (Caelestia):
MaterialIcon {
    iconName: IconCategoryResolver.getAppCategoryIcon(windowClass, "terminal")
}
```

---

## 🚀 Быстрый старт

1. **Перезапустите Quickshell**:
   ```bash
   pkill quickshell && quickshell
   ```

2. **Откройте несколько приложений** на одном воркспейсе

3. **Проверьте**:
   - ✅ Индикатор воркспейса
   - ✅ Ряд Material Icons под индикатором
   - ✅ Клик на иконку → фокус окна

---

## 📚 Связанные файлы

- `src/core/services/HyprlandWindowService.qml`
- `src/core/services/IconCategoryResolver.qml`
- `src/features/statusbar/WorkspaceWidget.qml`
- Вдохновлено: `../caelestia/utils/Icons.qml`

**Приятного использования! 🎉**
