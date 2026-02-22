# Система отображения иконок на воркспейсах

## 📋 Обзор

Реализована гибридная система отображения иконок приложений на воркспейсах, вдохновлённая конфигурациями **ii** и **caelestia**.

### Основные возможности

- ✅ **Нативное API** - использует встроенный `Hyprland.toplevels` вместо subprocess
- ✅ **Умное определение иконок** - многоступенчатая эвристика без fuzzy search
- ✅ **Hover для деталей** - при наведении показывает все окна
- ✅ **Интерактивность** - клик по иконке фокусирует конкретное окно
- ✅ **Плавные анимации** - анимация появления/исчезновения и размера

---

## 🏗️ Архитектура

### Компоненты системы

```
src/core/services/
├── HyprlandWindowService.qml    # Работа с окнами Hyprland
├── IconResolver.qml              # Определение иконок приложений
└── ...

src/features/statusbar/
└── WorkspaceWidget.qml           # Виджет с иконками
```

---

## 🔧 HyprlandWindowService

**Расположение**: `src/core/services/HyprlandWindowService.qml`

### API

#### `getBiggestWindowForWorkspace(workspaceId)`
Возвращает самое большое окно на воркспейсе (по площади)

```qml
const biggestWindow = HyprlandWindowService.getBiggestWindowForWorkspace(1)
console.log(biggestWindow.lastIpcObject.class) // "Firefox"
```

#### `getWindowsForWorkspace(workspaceId)`
Возвращает все окна на воркспейсе

```qml
const windows = HyprlandWindowService.getWindowsForWorkspace(1)
console.log(windows.length) // 3
```

#### `getWindowCountForWorkspace(workspaceId)`
Количество окон на воркспейсе

```qml
const count = HyprlandWindowService.getWindowCountForWorkspace(1)
```

#### `isWorkspaceOccupied(workspaceId)`
Проверка занятости воркспейса

```qml
const occupied = HyprlandWindowService.isWorkspaceOccupied(1) // true/false
```

### Как работает

Использует **гибридный подход** из ii:
1. Получает окна через `Hyprland.toplevels.values` (нативное API)
2. Фильтрует по `workspace?.id`
3. Находит максимум через `reduce()` по площади окна

```javascript
function getBiggestWindowForWorkspace(workspaceId) {
    const windows = getWindowsForWorkspace(workspaceId)

    return windows.reduce((maxWin, win) => {
        const maxArea = maxWin?.size?.[0] * maxWin?.size?.[1] || 0
        const winArea = win?.size?.[0] * win?.size?.[1] || 0
        return winArea > maxArea ? win : maxWin
    }, windows[0])
}
```

---

## 🎨 IconResolver

**Расположение**: `src/core/services/IconResolver.qml`

### API

#### `resolveIcon(windowClass)`
Основная функция определения иконки

```qml
const icon = IconResolver.resolveIcon("Firefox") // "firefox"
const icon2 = IconResolver.resolveIcon("code") // "visual-studio-code"
```

#### `getIconPath(windowClass, fallback)`
Получить полный путь к иконке

```qml
const path = IconResolver.getIconPath("Firefox", "image-missing")
// "/usr/share/icons/hicolor/scalable/apps/firefox.svg"
```

### Алгоритм определения

Многоступенчатая эвристика (упрощённая версия ii без fuzzy search):

1. **Desktop Entry lookup** - `DesktopEntries.heuristicLookup()` (самый надёжный)
2. **Прямые подстановки** - словарь известных приложений
3. **Regex подстановки** - для динамических случаев (Steam, Minecraft)
4. **Существование иконки** - проверка через `Quickshell.iconPath()`
5. **Lowercase** - `Firefox` → `firefox`
6. **Reverse domain** - `org.gnome.Nautilus` → `Nautilus`
7. **Kebab-case** - `Visual Studio` → `visual-studio`
8. **Fallback** - возврат класса окна as-is

### Словарь подстановок

Расширяемый словарь в `IconResolver.qml`:

```qml
readonly property var substitutions: ({
    "code-url-handler": "visual-studio-code",
    "Code": "visual-studio-code",
    "Firefox": "firefox",
    "Google-chrome": "google-chrome",
    "discord": "discord",
    "Spotify": "spotify",
    // ... добавляйте свои
})
```

### Regex подстановки

Для динамических случаев:

```qml
{
    regex: /^steam_app_(\d+)$/,
    replace: "steam_icon_$1"
},
{
    regex: /Minecraft.*/,
    replace: "minecraft"
}
```

---

## 💡 WorkspaceWidget - Использование

### Поведение по умолчанию

**Без окон**:
- Показывается только индикатор (точка)

**С одним окном**:
- Индикатор + маленькая иконка приложения (16x16)

**С несколькими окнами**:
- Индикатор + иконка самого большого окна

### Hover эффект

При наведении на воркспейс с несколькими окнами:
1. Воркспейс расширяется (24px → 80px ширина)
2. Показывается вертикальный список всех иконок
3. Каждая иконка кликабельна - фокусирует окно
4. Tooltip показывает название окна

### Интерактивность

```qml
// Клик на воркспейс - переключение
onClicked: Hyprland.dispatch("workspace " + wsIndex)

// Клик на иконку в hover режиме - фокус окна
onClicked: Hyprland.dispatch("focuswindow address:" + modelData.address)
```

---

## ⚙️ Настройка

### Включение/отключение иконок

В `config.json` или через `widgetSettings`:

```json
{
  "widgets": {
    "workspaces": {
      "showWindows": true  // false - только точки, без иконок
    }
  }
}
```

### Кастомизация размеров

В `WorkspaceWidget.qml`:

```qml
// Размер основной иконки
width: 16
height: 16

// Размер при hover
width: isHovered ? 80 : 24
height: isHovered ? Math.min(allWindows.length * 20 + 12, 100) : 24
```

---

## 🎯 Сравнение с другими системами

| Аспект | **Ваша система (гибрид)** | **ii** | **caelestia** |
|--------|---------------------------|--------|---------------|
| Тип иконок | Системные иконки | Системные иконки | Material Icons |
| Количество по умолчанию | 1 (главное окно) | 1 (главное окно) | Все окна |
| При hover | Все окна | - | - |
| API | Нативное Quickshell | hyprctl subprocess | Нативное |
| Сложность | Средняя | Высокая | Низкая |
| Fallback | Multi-step | Fuzzy search | Категории |

---

## 🚀 Расширение функционала

### Добавление новых подстановок

Редактируйте `IconResolver.qml`:

```qml
readonly property var substitutions: ({
    // ... существующие
    "MyApp": "my-custom-icon",
    "Another": "another-icon"
})
```

### Добавление regex правил

```qml
readonly property var regexSubstitutions: [
    // ... существующие
    {
        regex: /^custom_app_.*/,
        replace: "custom-icon"
    }
]
```

### Изменение анимаций

В `WorkspaceWidget.qml`:

```qml
Behavior on width {
    NumberAnimation {
        duration: Config.animations.durationMedium  // измените на durationFast
        easing.type: Easing.OutCubic               // или другой easing
    }
}
```

---

## 🐛 Отладка

### Проверка определения иконок

```qml
// В консоли QML
console.log("Icon for Firefox:", IconResolver.resolveIcon("Firefox"))
console.log("Path:", IconResolver.getIconPath("Firefox", "image-missing"))
```

### Проверка окон на воркспейсе

```qml
const windows = HyprlandWindowService.getWindowsForWorkspace(1)
windows.forEach(w => {
    console.log("Class:", w.lastIpcObject.class)
    console.log("Size:", w.lastIpcObject.size)
})
```

### Fallback иконка

Если иконка не найдена, показывается `image-missing`. Добавьте подстановку в `IconResolver.substitutions`.

---

## 📝 Примеры использования

### Пример 1: Показать количество окон

```qml
Text {
    text: HyprlandWindowService.getWindowCountForWorkspace(wsIndex)
    visible: hasWindows
}
```

### Пример 2: Список классов окон

```qml
Column {
    Repeater {
        model: HyprlandWindowService.getWindowsForWorkspace(1)

        Text {
            required property var modelData
            text: modelData.lastIpcObject.class
        }
    }
}
```

### Пример 3: Кастомная логика выбора окна

```qml
// Вместо самого большого - показать последнее активное
property var selectedWindow: HyprlandWindowService.getWindowsForWorkspace(wsIndex)
    .sort((a, b) => b.lastIpcObject.focusHistoryID - a.lastIpcObject.focusHistoryID)[0]
```

---

## ✅ Преимущества реализации

1. **Производительность**: Нативное API без spawn процессов
2. **Простота**: Без зависимостей (fuzzy search, levenshtein)
3. **Расширяемость**: Легко добавлять новые подстановки
4. **UX**: Hover показывает детали без перегрузки интерфейса
5. **Универсальность**: Работает с 90% приложений из коробки

---

## 📚 Связанные файлы

- `src/core/services/HyprlandWindowService.qml` - Сервис работы с окнами
- `src/core/services/IconResolver.qml` - Определение иконок
- `src/features/statusbar/WorkspaceWidget.qml` - Виджет с визуализацией
- Вдохновлено: `../ii/services/HyprlandData.qml`, `../caelestia/utils/Icons.qml`
