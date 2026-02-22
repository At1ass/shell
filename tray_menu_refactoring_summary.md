# Рефакторинг TrayMenuOverlay - Итоговая сводка

## Проблемы до рефакторинга:

1. **Множественные окна** - по одному TrayMenuOverlay на каждый экран
2. **Конфликт grab'ов** - несколько HyprlandFocusGrab активировались одновременно
3. **Multi-monitor баг** - клик на втором мониторе не закрывал меню с первого
4. **Race condition** - grab перехватывал mouse release event, открывающий меню
5. **Сложная синхронизация** - нужно было синхронизировать состояние между экранами

## Решение:

### 1. Единое глобальное окно
**Файл:** `shell.qml`
```qml
ShellRoot {
    // ОДНО окно для всех экранов (раньше: по одному на экран)
    Bar.TrayMenuOverlay {
        id: globalTrayMenu
    }

    Variants {
        model: Quickshell.screens
        Bar.StatusBar {
            trayMenu: globalTrayMenu  // все бары используют одно меню
        }
    }
}
```

**Было:**
- `Variants { TrayMenuOverlay { screen: modelData } }` - создание per-screen
- Множественные окна с отдельными grab'ами

**Стало:**
- Одно глобальное окно вне Variants
- Spanning через все экраны (anchors: left/right/top/bottom: true)

### 2. Конфигурация окна
**Файл:** `TrayMenuOverlay.qml`
```qml
PanelWindow {
    // Убрано: required property ShellScreen screen
    // Убрано: readonly property string screenKey
    // Убрано: readonly property bool isOwner

    // Spanning через все экраны
    anchors {
        left: true
        top: true
        right: true
        bottom: true
    }

    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.namespace: "shell:traymenu:global"  // было: per-screen
}
```

### 3. HyprlandFocusGrab с тройной защитой
```qml
property bool grabReady: false

HyprlandFocusGrab {
    // Тройное условие для предотвращения race condition:
    active: trayMenuLoader.active &&  // 1. Loader активен (асинхронная загрузка)
            root.grabReady &&          // 2. Timer сработал (50ms задержка)
            GlobalStates.trayMenuOpen  // 3. Меню открыто
    windows: [root]
    onCleared: hideMenu()
}

Timer {
    id: grabReadyTimer
    interval: 50  // RIGHT CLICK требует больше времени чем LEFT
    onTriggered: root.grabReady = true
}
```

**Почему тройная защита:**
- `trayMenuLoader.active` - микрозадержка от асинхронной загрузки (как в Dashboard)
- `grabReady` - явная задержка 50ms (RIGHT CLICK обрабатывается дольше LEFT)
- `trayMenuOpen` - общее состояние меню

### 4. Позиционирование в глобальных координатах

**Было (per-screen):**
```qml
function sourceScreenPos() {
    const screenX = root.screen.x
    const screenY = root.screen.y
    return { x: globalX - screenX, y: globalY - screenY }
}
```

**Стало (глобальное):**
```qml
// Получить экран где находится sourceItem
function getSourceScreen() {
    const globalPos = sourceGlobalPos();
    for (let i = 0; i < Quickshell.screens.length; i++) {
        const screen = Quickshell.screens[i];
        if (globalPos.x >= screen.x && globalPos.x < screen.x + screen.width &&
            globalPos.y >= screen.y && globalPos.y < screen.y + screen.height) {
            return screen;
        }
    }
    return Quickshell.screens[0];  // fallback
}

// Вычислить позицию меню в глобальных координатах
function computeX(cardWidth, margin) {
    const screen = getSourceScreen();
    const globalPos = sourceGlobalPos();

    // Центрируем меню относительно sourceItem
    let menuX = globalPos.x + sourceItem.width / 2 - cardWidth / 2;

    // Ограничиваем границами экрана
    if (menuX < screen.x + margin)
        menuX = screen.x + margin;
    if (menuX + cardWidth > screen.x + screen.width - margin)
        menuX = screen.x + screen.width - cardWidth - margin;

    return menuX;  // Глобальная X координата
}
```

### 5. Упрощение управления состоянием

**Убрано из GlobalStates.qml:**
```qml
// property bool trayMenuGrabActive: false  // больше не нужно!
```

**Функции:**
```qml
function openTrayMenu(ownerKey) {
    trayMenuOpen = true
    trayMenuOwner = ownerKey || ""  // теперь всегда "global"
    trayMenuEpoch++
}

function closeTrayMenu() {
    trayMenuOpen = false
    trayMenuOwner = ""
    // trayMenuGrabActive = false  // убрано
    trayMenuEpoch++
}
```

## Преимущества новой архитектуры:

### ✅ Решённые проблемы:
1. **Один HyprlandFocusGrab** - нет конфликтов между экранами
2. **Клик на любом мониторе закрывает меню** - grab spanning через все экраны
3. **Нет race condition** - тройная защита (loader + timer + state)
4. **Упрощённое состояние** - не нужно синхронизировать между экранами
5. **Корректное позиционирование** - меню позиционируется на правильном экране

### ✅ Архитектурные улучшения:
1. **Один источник истины** - одно окно, одно состояние
2. **Меньше кода** - убрана логика per-screen
3. **Аналог noctalia-shell** - подготовка к универсальной системе меню
4. **Простота отладки** - один grab, одно окно

## Тестирование:

### Сценарии для проверки:
- [x] Открытие меню RIGHT CLICK на экране A
- [x] Клик вне меню на экране A - должно закрыться
- [x] Открытие меню на экране A, клик на экране B - должно закрыться
- [x] Escape закрывает меню
- [x] Toggle (повторный клик на тот же элемент) закрывает меню
- [x] Меню позиционируется корректно на обоих мониторах
- [x] Меню не перекрывается границами экрана

### Ожидаемые логи:
```
TrayWidget: clicked on tray item chrome_status_icon_1 button: 2
Showing tray menu via TrayMenuOverlay
TrayMenuOverlay: Menu opened, starting grab timer
(50ms пауза)
TrayMenuOverlay: Grab ready
(клик вне меню)
TrayMenuOverlay: Focus lost, hiding menu
TrayMenuOverlay: Hiding menu
```

## Следующие шаги (опционально):

### 1. Универсальная система меню (как в noctalia-shell)
Текущий TrayMenuOverlay можно расширить до PopupMenuWindow:
- `showContextMenu(model, x, y, callback)` - для других виджетов
- `showDynamicMenu(menuComponent)` - для custom контента
- Регистрация через сервис

### 2. Добавление контекстных меню в другие виджеты
Все виджеты бара смогут использовать `globalTrayMenu` для показа своих меню:
- MPRISWidget - управление плеером
- VolumeWidget - выбор устройств
- NetworkWidget - список сетей

### 3. Интеграция с Dashboard
Если SystemTrayElement в Dashboard будет активирован:
- Передать `globalTrayMenu` через props
- Использовать то же единое окно

## Сравнение с noctalia-shell:

| Аспект | noctalia-shell | Наша реализация |
|--------|----------------|-----------------|
| Количество окон | Одно PopupMenuWindow | Одно TrayMenuOverlay |
| Spanning | Да (Top layer) | Да (Overlay layer) |
| HyprlandFocusGrab | Да | Да |
| Multi-monitor | ❌ Баг (несколько grab) | ✅ Исправлено |
| Универсальность | Для всех типов меню | Пока только трей |
| Регистрация | PanelService | GlobalStates |

**Наше преимущество:** Исправили баг multi-monitor который есть в noctalia-shell!

## Файлы изменены:

1. `shell.qml` - создание единого globalTrayMenu
2. `src/features/statusbar/TrayMenuOverlay.qml` - рефакторинг в единое окно
3. `src/core/services/GlobalStates.qml` - упрощение состояния
4. `src/features/dashboard/Dashboard.qml` - откат ненужных изменений
5. `src/features/dashboard/DashboardContent.qml` - откат ненужных изменений

## Итог:

Рефакторинг завершён. TrayMenuOverlay теперь:
- ✅ Единое глобальное окно
- ✅ Работает на multi-monitor setup
- ✅ Нет race condition
- ✅ Готово к расширению в универсальную систему меню
