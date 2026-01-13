# Анализ: Почему Dashboard работает с HyprlandFocusGrab, а TrayMenu нет

## Результаты анализа

### ✅ Dashboard - работает корректно

**Файл:** `src/features/dashboard/Dashboard.qml`

#### Механизм открытия:
```qml
// Dashboard открывается через LEFT CLICK на виджете
// Например: ClockWidget.qml:69
clickHandler: function(mouse) {
    GlobalStates.handleClickAction(widgetConfig.clickAction)
    // action = "dashboard-quick" -> openDashboardTab(0)
}
```

**Последовательность событий:**
1. LEFT CLICK на виджете (например, часы)
2. `onClicked` срабатывает
3. Mouse release завершается
4. `GlobalStates.dashboardOpen = true`
5. Dashboard window становится `visible: true`
6. `HyprlandFocusGrab` активируется
7. **Mouse event уже завершён** - grab не перехватывает его

#### HyprlandFocusGrab конфигурация:
```qml
HyprlandFocusGrab {
    id: focusGrab
    active: dashboardLoader.active && GlobalStates.dashboardOpen
    windows: [dashboardWindow]
    onCleared: () => {
        console.log("Dashboard: focus lost, closing dashboard")
        GlobalStates.dashboardOpen = false;  // ← Только через grab
    }
}
```

#### MouseArea для click-outside:
```qml
// НЕТ MouseArea вообще! Только HyprlandFocusGrab.onCleared
```

**Почему работает:**
- ✅ Открытие через LEFT CLICK (не Right)
- ✅ Нет MouseArea для ручного закрытия
- ✅ Закрытие только через HyprlandFocusGrab.onCleared
- ✅ Event полностью обработан до активации grab

---

### ❌ TrayMenu - моментально закрывается

**Файл:** `src/features/statusbar/TrayMenuOverlay.qml`

#### Механизм открытия:
```qml
// TrayMenu открывается через RIGHT CLICK на иконке трея
// TrayWidget.qml:99
onClicked: event => {
    if (event.button === Qt.RightButton && trayItem.modelData.hasMenu) {
        root.trayMenu.showMenu(trayItem.modelData.menu, trayItem)
    }
}
```

**Последовательность событий:**
1. RIGHT CLICK на иконке трея
2. `onClicked` срабатывает
3. `showMenu()` → `GlobalStates.trayMenuOpen = true`
4. TrayMenuOverlay становится `visible: true`
5. `HyprlandFocusGrab` **активируется СРАЗУ**
6. ❌ **Mouse release event еще не завершён**
7. ❌ Grab перехватывает tail of mouse event
8. ❌ `onCleared` срабатывает → `hideMenu()`
9. ❌ Меню моментально закрывается

#### HyprlandFocusGrab конфигурация:
```qml
HyprlandFocusGrab {
    id: focusGrab
    active: GlobalStates.trayMenuOpen  // ← активен сразу!
    windows: [root]
    onCleared: () => {
        console.log("TrayMenuOverlay: Focus lost, hiding menu");
        hideMenu();  // ← закрывает меню
    }
}
```

#### MouseArea для click-outside:
```qml
// ЗАКОММЕНТИРОВАНА! (строки 88-93)
MouseArea {
    anchors.fill: parent
    enabled: root.visible
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    onClicked: root.hideMenu()  // ← не используется
}
```

**Почему НЕ работает:**
- ❌ Открытие через RIGHT CLICK
- ❌ Grab активируется моментально (`active: GlobalStates.trayMenuOpen`)
- ❌ Mouse release event перехватывается grab
- ❌ `onCleared` триггерится от того же клика
- ❌ Race condition: открытие и закрытие в одном event loop

---

## Ключевые различия

| Аспект | Dashboard | TrayMenu |
|--------|-----------|----------|
| **Тип клика** | LEFT CLICK | RIGHT CLICK |
| **Timing** | Event завершён до grab | Event перехватывается grab |
| **MouseArea** | Отсутствует | Закомментирована |
| **Grab активация** | `dashboardLoader.active && dashboardOpen` | `trayMenuOpen` (сразу) |
| **Закрытие** | Только через onCleared | onCleared (+ закомм. MouseArea) |

---

## Почему RIGHT CLICK проблематичнее LEFT CLICK

### LEFT CLICK (Dashboard):
```
User clicks → MousePress → MouseRelease → onClicked →
→ dashboardOpen=true → visible=true → grab activates →
→ ✅ event chain завершён
```

### RIGHT CLICK (TrayMenu):
```
User right-clicks → MousePress → MouseRelease (начинается) → onClicked →
→ trayMenuOpen=true → visible=true → grab activates →
→ ❌ MouseRelease еще обрабатывается → grab перехватывает →
→ ❌ onCleared → menu closes
```

**Суть проблемы:** Right click event processing может быть длиннее, и grab активируется ДО полного завершения события.

---

## Решения для TrayMenu

### ✅ Решение 1: Задержка активации grab (РЕКОМЕНДУЕТСЯ)

```qml
HyprlandFocusGrab {
    id: focusGrab
    active: root.grabActive  // ← не напрямую от trayMenuOpen
    windows: [root]
    onCleared: () => {
        hideMenu();
    }
}

property bool grabActive: false

function showMenu(menuHandle, source) {
    // ... существующий код ...
    GlobalStates.openTrayMenu(root.screenKey);

    // Активировать grab с задержкой
    grabActivationTimer.restart();
}

Timer {
    id: grabActivationTimer
    interval: 100  // 100ms достаточно
    repeat: false
    onTriggered: root.grabActive = true
}

function hideMenu() {
    root.grabActive = false;  // сбросить
    grabActivationTimer.stop();
    // ... остальной код ...
}
```

**Преимущества:**
- ✅ Простое и чистое решение
- ✅ 100ms незаметно для пользователя
- ✅ Гарантирует завершение mouse event
- ✅ Не требует сложной логики

---

### ✅ Решение 2: Использовать onPressed вместо onClicked

```qml
// В TrayWidget.qml изменить:
onPressed: event => {  // ← вместо onClicked
    if (event.button === Qt.RightButton && trayItem.modelData.hasMenu) {
        root.trayMenu.showMenu(trayItem.modelData.menu, trayItem)
        event.accepted = true
    }
}
```

**Преимущества:**
- ✅ onPressed срабатывает раньше (на MousePress, не на Release)
- ✅ К моменту MouseRelease grab уже активен и игнорируется корректно
- ✅ Не нужна задержка

**Недостатки:**
- ⚠️ Меню откроется ДО отпускания кнопки (может быть непривычно)
- ⚠️ Нестандартное поведение для контекстных меню

---

### ✅ Решение 3: Grace period (как в noctalia DockMenu)

```qml
property bool canAcceptGrabClear: false

HyprlandFocusGrab {
    id: focusGrab
    active: GlobalStates.trayMenuOpen
    windows: [root]
    onCleared: () => {
        if (root.canAcceptGrabClear) {  // ← проверка
            hideMenu();
        }
    }
}

function showMenu(menuHandle, source) {
    root.canAcceptGrabClear = false;
    // ... существующий код ...
    GlobalStates.openTrayMenu(root.screenKey);
    gracePeriodTimer.restart();
}

Timer {
    id: gracePeriodTimer
    interval: 150  // 150ms grace period
    repeat: false
    onTriggered: root.canAcceptGrabClear = true
}
```

**Преимущества:**
- ✅ Защита от spurious events
- ✅ Grab активен сразу, но игнорируется кратковременно

**Недостатки:**
- ⚠️ Более сложная логика
- ⚠️ Небольшое окно, когда grab не работает (150ms)

---

## Рекомендация

**Использовать Решение 1 (задержка активации grab)**

Почему:
1. Самое простое и понятное
2. Не меняет UX (100ms незаметно)
3. Аналогично тому, как Dashboard работает "by accident" (event завершается до grab)
4. Чистая реализация без флагов и проверок

**Альтернатива:** Решение 2 (onPressed), если хотите более responsive UX.

**Не рекомендуется:** Решение 3 (grace period) - избыточно для данной задачи.

---

## Дополнительные находки

### 1. MouseArea в TrayMenuOverlay закомментирована

Строки 88-93:
```qml
// MouseArea {
//     anchors.fill: parent
//     enabled: root.visible
//     acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
//     onClicked: root.hideMenu()
// }
```

**Почему закомментирована:**
- Вероятно, вы пытались использовать HyprlandFocusGrab как единственный механизм закрытия
- Столкнулись с проблемой race condition
- Закомментировали MouseArea, думая что проблема в ней
- **На самом деле:** MouseArea не нужна, если HyprlandFocusGrab работает корректно

### 2. Dashboard не имеет MouseArea вообще

В Dashboard.qml нет никакого MouseArea для click-outside-to-close.
Только `HyprlandFocusGrab.onCleared` делает всю работу.

**Вывод:** После фикса TrayMenu тоже не нужна MouseArea.

---

## Выводы

1. **Dashboard работает** потому что открывается через LEFT CLICK, и event полностью завершается до активации grab
2. **TrayMenu ломается** потому что RIGHT CLICK event chain перехватывается grab до завершения
3. **Решение:** Задержать активацию grab на 100ms через Timer
4. **MouseArea не нужна** - HyprlandFocusGrab достаточно для click-outside-to-close
5. **Комментарий в коде** был неправильным пониманием проблемы

---

## Итоговый код (рекомендация)

```qml
// TrayMenuOverlay.qml
PanelWindow {
    id: root

    property bool grabActive: false  // ← добавить

    HyprlandFocusGrab {
        id: focusGrab
        active: root.grabActive  // ← изменить
        windows: [root]
        onCleared: () => {
            console.log("TrayMenuOverlay: Focus lost, hiding menu");
            hideMenu();
        }
    }

    function showMenu(menuHandle, source) {
        if (!menuHandle)
            return;

        if (root.isOwner && root.visible && root.sourceItem === source) {
            hideMenu();
            return;
        }

        root.currentHandle = menuHandle;
        root.sourceItem = source;
        menuLoader.active = false;
        menuLoader.active = true;

        GlobalStates.openTrayMenu(root.screenKey);

        // Активировать grab с задержкой
        grabActivationTimer.restart();  // ← добавить
    }

    function hideMenu() {
        root.grabActive = false;  // ← добавить
        grabActivationTimer.stop();  // ← добавить
        GlobalStates.closeTrayMenu();
        clearLocal();
        root.menuClosed();
    }

    // Таймер для задержки активации grab
    Timer {  // ← добавить
        id: grabActivationTimer
        interval: 100
        repeat: false
        onTriggered: root.grabActive = true
    }

    // MouseArea НЕ НУЖНА - удалить или оставить закомментированной
}
```

**Изменения:**
1. ➕ `property bool grabActive: false`
2. ➕ `Timer { id: grabActivationTimer }`
3. ✏️ `active: root.grabActive` (вместо `GlobalStates.trayMenuOpen`)
4. ✏️ В `showMenu()`: `grabActivationTimer.restart()`
5. ✏️ В `hideMenu()`: `grabActive = false` + `grabActivationTimer.stop()`

**Результат:** TrayMenu будет работать так же стабильно, как Dashboard.
