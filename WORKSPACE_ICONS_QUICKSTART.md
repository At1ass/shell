# 🚀 Workspace Icons - Quick Start

## Что было сделано

Реализована система отображения иконок приложений на воркспейсах с **гибридным подходом**:
- ✅ Иконка самого большого окна по умолчанию
- ✅ При наведении - показ всех окон
- ✅ Клик по иконке - фокус на конкретное окно
- ✅ Нативное API без subprocess
- ✅ Умное определение иконок

---

## 📦 Созданные файлы

```
src/core/services/
├── HyprlandWindowService.qml    ← Работа с окнами Hyprland
└── IconResolver.qml              ← Определение иконок приложений

src/features/statusbar/
└── WorkspaceWidget.qml           ← Обновлён с поддержкой иконок

docs/
└── WORKSPACE_ICONS_GUIDE.md      ← Полная документация
```

---

## ⚡ Быстрый тест

### 1. Перезапустите Quickshell

```bash
# Через Hyprland
hyprctl dispatch exec "pkill quickshell && quickshell"

# Или просто
pkill quickshell
quickshell
```

### 2. Проверьте работу

- Откройте несколько окон на одном воркспейсе (например, Firefox + Terminal)
- Посмотрите на индикатор воркспейса - должна появиться иконка
- Наведите мышь на воркспейс - должны показаться все иконки
- Кликните на любую иконку - должно переключиться на это окно

---

## 🎨 Как это выглядит

### Без окон
```
┌─┐
│○│  ← Просто точка
└─┘
```

### С одним окном
```
┌─┐
│🦊│  ← Иконка Firefox
└─┘
```

### При hover (несколько окон)
```
┌────┐
│ 🦊 │  ← Firefox (кликабельно)
│ ▶️ │  ← Terminal (кликабельно)
│ 💻 │  ← VSCode (кликабельно)
└────┘
```

---

## ⚙️ Настройка

### Отключить иконки (если нужно)

В `config.json`:

```json
{
  "widgets": {
    "workspaces": {
      "showWindows": false  // Только точки, без иконок
    }
  }
}
```

### Добавить подстановку для приложения

Если иконка не распознаётся, добавьте в `src/core/services/IconResolver.qml`:

```qml
readonly property var substitutions: ({
    // ... существующие
    "МоёПриложение": "my-app-icon",
})
```

**Как узнать класс окна?**
```bash
hyprctl clients | grep class
```

---

## 🔍 Отладка

### Иконка не показывается?

1. **Проверьте класс окна**:
   ```bash
   hyprctl clients -j | jq '.[] | {class, workspace}'
   ```

2. **Проверьте наличие иконки в системе**:
   ```bash
   # Найти иконку firefox
   find /usr/share/icons -name "*firefox*"
   ```

3. **Добавьте в консоль QML** (в `WorkspaceWidget.qml`):
   ```qml
   Component.onCompleted: {
       console.log("Window class:", biggestWindow?.lastIpcObject?.class)
       console.log("Icon path:", mainIconPath)
   }
   ```

### Hover не работает?

Проверьте, что `hoverEnabled: true` в MouseArea (уже должно быть).

### Ошибки при запуске?

Проверьте лог Quickshell:
```bash
journalctl --user -u quickshell -f
```

---

## 🎯 Следующие шаги

### Улучшения которые можно добавить:

1. **Индикатор количества окон**
   ```qml
   Text {
       text: allWindows.length
       visible: hasMultipleWindows && !isHovered
   }
   ```

2. **Разные стили для разных мониторов**
   ```qml
   property bool isVerticalBar: screen.name === "DP-1"
   // Изменить layout с Row на Column
   ```

3. **Группировка по классу**
   ```qml
   // Показывать иконку один раз, даже если несколько окон
   property var uniqueClasses: [...new Set(allWindows.map(w => w.class))]
   ```

4. **Анимация при открытии/закрытии окон**
   ```qml
   add: Transition { ... }
   remove: Transition { ... }
   ```

---

## 📚 Документация

Полная документация в `docs/WORKSPACE_ICONS_GUIDE.md`:
- Детальное описание API
- Алгоритм определения иконок
- Примеры расширения
- Сравнение с ii и caelestia

---

## 🙏 Источники вдохновения

- **ii** (`../ii/`) - алгоритм поиска самого большого окна, система подстановок
- **caelestia** (`../caelestia/`) - нативное API, категории Material Icons

---

## ❓ Вопросы?

1. Проверьте `docs/WORKSPACE_ICONS_GUIDE.md`
2. Посмотрите код в `src/core/services/`
3. Экспериментируйте с настройками!

**Приятного использования! 🎉**
