# Анализ систем меню: текущая конфигурация vs noctalia-shell

## 1. Текущая система меню (shell)

### Компоненты:
- **TrayWidget.qml** - виджет трея в статус-баре
- **TrayMenu.qml** - содержимое меню трея (StackView с навигацией по подменю)
- **TrayMenuOverlay.qml** - полноэкранное окно-оверлей для отображения меню

### Архитектура:
```
TrayWidget.qml
    └─> MouseArea (RightClick)
        └─> trayMenu.showMenu(item, source)
            └─> TrayMenuOverlay.qml (PanelWindow, Top layer)
                └─> MaterialCard
                    └─> Loader
                        └─> TrayMenu.qml (StackView)
```

### Характеристики:
1. **Специализированная** - создана только для меню трея
2. **Глобальное состояние** - использует GlobalStates.trayMenuOpen/trayMenuOwner
3. **Одно окно на экран** - создается для каждого ShellScreen
4. **Позиционирование** - вычисляет позицию относительно элемента-источника
5. **Закрытие** - клик вне меню или Escape

---

## 2. Система меню noctalia-shell

### Компоненты:

#### A. Базовые компоненты меню:

**NContextMenu.qml** - Qt Popup меню
- Использование: внутри панелей, диалогов, повторителей
- Базируется на: `Popup` (Qt Quick Controls)
- Родитель: `Overlay.overlay`
- Особенности: простое popup-меню с моделью данных

**NPopupContextMenu.qml** - PopupWindow меню
- Использование: в bar виджетах и контекстах верхнего уровня
- Базируется на: `PopupWindow` (Quickshell)
- Особенности:
  - Автоматическое позиционирование относительно экрана
  - Учет позиции бара (top/bottom/left/right)
  - Динамический расчет ширины по содержимому
  - anchor.item для привязки к элементу

#### B. Универсальное окно меню:

**PopupMenuWindow.qml** - полноэкранное окно для всех меню
- Тип: `PanelWindow` (Top layer)
- Регистрация: `PanelService.registerPopupMenuWindow(screen, root)`
- Содержимое:
  ```
  PopupMenuWindow
  ├─> trayMenuLoader (загружает TrayMenu по умолчанию)
  ├─> dynamicMenu (NPopupContextMenu для виджетов)
  └─> contentItem (текущий активный контент)
  ```

#### C. Специализированные меню:

**TrayMenu.qml** - меню системного трея
- Тип: `PopupWindow`
- Функции: показ меню элемента трея, подменю, pin/unpin
- Позиционирование: относительно элемента трея с учетом позиции бара

**DockMenu.qml** - контекстное меню дока
- Тип: `PopupWindow`
- Функции: Focus, Pin/Unpin, Close, действия из .desktop файлов
- Динамическая ширина: автоматический расчет по содержимому

### Архитектура:
```
Виджет в баре (например, Tray)
    └─> MouseArea (RightClick)
        └─> PopupMenuWindow.showDynamicContextMenu(model, x, y, callback)
            └─> PopupMenuWindow (PanelWindow, Top layer, full screen)
                ├─> MouseArea (click-outside-to-close)
                ├─> TrayMenu (загружен по умолчанию)
                └─> dynamicMenu (NPopupContextMenu)
                    └─> contentItem (текущее активное меню)
```

### Характеристики:
1. **Универсальная** - одно окно для всех типов меню
2. **Сервис-ориентированная** - регистрация через PanelService
3. **Гибкая** - может показывать разный контент (TrayMenu, NPopupContextMenu, custom)
4. **API для виджетов**:
   - `showContextMenu(menu)` - показать существующий PopupWindow меню
   - `showDynamicContextMenu(model, x, y, callback)` - показать меню из модели данных
5. **Переключение контента** - может временно заменить TrayMenu на контекстное меню
6. **dialogParent** - контейнер для диалогов, которым нужен полноэкранный родитель

---

## 3. Ключевые различия

| Аспект | Текущая система | noctalia-shell |
|--------|-----------------|----------------|
| **Назначение** | Только меню трея | Универсальная система для всех меню |
| **Компонентов** | 3 (Widget, Menu, Overlay) | 6 (2 базовых + Window + 3 специализированных) |
| **Регистрация** | GlobalStates | PanelService |
| **Контент** | Фиксированный (только TrayMenu) | Динамический (любой компонент) |
| **API** | showMenu(menuHandle, source) | showContextMenu/showDynamicContextMenu |
| **Использование** | Только трей | Трей, виджеты, дока, desktop items |
| **Позиционирование** | Вычисления в TrayMenuOverlay | Вычисления в каждом компоненте (TrayMenu, NPopupContextMenu) |
| **Закрытие** | Локальная логика | Централизованная логика в PopupMenuWindow |

---

## 4. Преимущества системы noctalia-shell

### 4.1 Масштабируемость
- Одна система для всех типов меню
- Легко добавить новые типы меню без дублирования кода

### 4.2 Переиспользование
- NContextMenu для простых случаев (внутри панелей)
- NPopupContextMenu для виджетов бара
- Специализированные меню (TrayMenu, DockMenu) для сложных случаев

### 4.3 Централизация
- Одно окно PopupMenuWindow на экран
- Одна точка управления всеми меню
- Единая логика click-outside-to-close

### 4.4 Гибкость
- Виджеты могут показывать контекстные меню без создания собственных окон
- Поддержка динамических меню из модели данных
- Возможность показывать диалоги поверх меню

### 4.5 Интеграция с другими компонентами
- Desktop widgets могут использовать меню через PanelService
- Виджеты бара получают доступ через PanelService.getPanel("popupMenuWindow")
- Единый стиль для всех меню

---

## 5. Как это работает в noctalia-shell

### Пример 1: Меню системного трея
```qml
// В виджете трея
MouseArea {
    onClicked: event => {
        if (event.button === Qt.RightButton) {
            // Получить PopupMenuWindow
            const popupWindow = PanelService.getPanel("popupMenuWindow", screen);

            // TrayMenu уже загружен в popupWindow.trayMenuLoader
            popupWindow.trayMenuLoader.item.showAt(trayItem, 0, anchorItem.height);
            popupWindow.open();
        }
    }
}
```

### Пример 2: Контекстное меню виджета
```qml
// В любом виджете бара
MouseArea {
    onClicked: event => {
        if (event.button === Qt.RightButton) {
            const popupWindow = PanelService.getPanel("popupMenuWindow", screen);

            const menuModel = [
                { icon: "settings", label: "Settings", action: "settings" },
                { icon: "refresh", label: "Refresh", action: "refresh" }
            ];

            const globalPos = mapToItem(null, event.x, event.y);

            popupWindow.showDynamicContextMenu(
                menuModel,
                globalPos.x,
                globalPos.y,
                (action) => {
                    if (action === "settings") {
                        // открыть настройки
                    }
                    return false; // вернуть true если откроется диалог
                }
            );
        }
    }
}
```

### Пример 3: Меню дока
```qml
// Док создает собственный DockMenu как PopupWindow
DockMenu {
    id: dockMenu
    anchorItem: null
    toplevel: null

    onRequestClose: {
        // скрыть меню
    }
}

// При правом клике на иконку
MouseArea {
    onClicked: event => {
        if (event.button === Qt.RightButton) {
            dockMenu.show(dockItem, toplevelData);
        }
    }
}
```

---

## 6. План адаптации текущей конфигурации

### Этап 1: Создание базовых компонентов (приоритет: высокий)
1. **NContextMenu.qml** (или ContextMenu.qml)
   - Базовое popup-меню на основе Qt Popup
   - Модель: массив { icon, label, action, enabled, visible }
   - Для использования внутри панелей и диалогов
   - Расположение: `src/ui/containers/`

2. **NPopupContextMenu.qml** (или PopupContextMenu.qml)
   - PopupWindow меню для виджетов бара
   - Автоматическое позиционирование
   - Динамический расчет ширины
   - Расположение: `src/ui/containers/`

### Этап 2: Рефакторинг PopupMenuWindow (приоритет: высокий)
3. **Переименование TrayMenuOverlay.qml → PopupMenuWindow.qml**
   - Сделать универсальным для всех типов меню
   - Добавить свойство `contentItem` для динамического контента
   - Добавить методы:
     - `showContextMenu(menu)` - показать PopupWindow меню
     - `showDynamicContextMenu(model, x, y, callback)` - показать меню из модели
     - `hideDynamicMenu()` - скрыть динамическое меню без закрытия окна
   - Добавить NPopupContextMenu как встроенный компонент
   - Сохранить TrayMenu loader как contentItem по умолчанию

4. **Регистрация в сервисе**
   - Добавить метод в GlobalStates или создать MenuService
   - `registerPopupMenuWindow(screen, window)`
   - `getPopupMenuWindow(screen)`
   - Альтернатива: использовать существующий механизм в GlobalStates

### Этап 3: Обновление TrayMenu (приоритет: средний)
5. **Адаптация TrayMenu.qml**
   - Оставить как есть, но добавить совместимость с новой системой
   - Методы `showAt(item, x, y)` и `hideMenu()` уже есть
   - Убедиться, что работает как contentItem в PopupMenuWindow

### Этап 4: Обновление виджетов (приоритет: средний)
6. **Обновление TrayWidget.qml**
   - Использовать новый API PopupMenuWindow
   - Вместо `trayMenu.showMenu()` использовать:
     ```qml
     const popupWindow = getPopupMenuWindow();
     popupWindow.trayMenuLoader.item.showAt(...);
     popupWindow.open();
     ```

7. **Добавление контекстных меню в другие виджеты**
   - MPRISWidget - меню управления плеером
   - StatusBar widgets - общие действия
   - Использовать `showDynamicContextMenu()` API

### Этап 5: Интеграция (приоритет: низкий)
8. **Создание MenuService (опционально)**
   - Централизованное управление меню
   - Методы для регистрации и получения PopupMenuWindow
   - Типовые модели меню для переиспользования

9. **Документация**
   - Примеры использования для разработчиков виджетов
   - API reference для компонентов меню

### Этап 6: Тестирование (приоритет: высокий)
10. **Тестирование всех сценариев**
    - Меню трея (левый/правый клик)
    - Контекстные меню виджетов
    - Позиционирование на разных позициях бара (top/bottom/left/right)
    - Клик вне меню для закрытия
    - Escape для закрытия
    - Подменю (если используются)
    - Множественные экраны

---

## 7. Структура файлов после адаптации

```
src/
├── ui/
│   └── containers/
│       ├── ContextMenu.qml           (новый - базовое popup меню)
│       ├── PopupContextMenu.qml      (новый - PopupWindow меню)
│       └── PopupMenuWindow.qml       (рефакторинг TrayMenuOverlay)
│
├── features/
│   └── statusbar/
│       ├── TrayWidget.qml            (обновлен - использует новый API)
│       ├── TrayMenu.qml              (без изменений)
│       ├── MPRISWidget.qml           (обновлен - добавлено меню)
│       └── ...
│
└── core/
    └── services/
        ├── GlobalStates.qml          (обновлен - регистрация PopupMenuWindow)
        └── MenuService.qml           (новый - опционально)
```

---

## 8. Преимущества для текущей конфигурации

После адаптации:

1. **Унификация** - единая система меню для всех компонентов
2. **Простота добавления меню** - виджеты могут легко добавлять контекстные меню
3. **Меньше кода** - переиспользование компонентов вместо дублирования
4. **Гибкость** - легко добавлять новые типы меню
5. **Совместимость** - существующий TrayMenu продолжит работать
6. **Масштабируемость** - готовность к добавлению новых функций (dashboard, dock, desktop widgets)

---

## 9. Потенциальные проблемы и решения

### Проблема 1: Конфликт с GlobalStates
- **Решение**: Постепенная миграция. Сначала добавить новые методы, потом перевести существующий функционал.

### Проблема 2: Позиционирование на разных позициях бара
- **Решение**: Использовать проверенную логику из noctalia-shell с учетом barPosition.

### Проблема 3: Z-order и слои
- **Решение**: PopupMenuWindow использует WlrLayer.Top, как и в noctalia-shell.

### Проблема 4: Производительность
- **Решение**: Использовать asynchronous: true для Loader, как в текущей реализации.

---

## 10. Приоритеты реализации

### Высокий приоритет (сейчас):
1. Создать ContextMenu.qml и PopupContextMenu.qml
2. Рефакторинг TrayMenuOverlay → PopupMenuWindow
3. Обновить TrayWidget для использования нового API
4. Тестирование базового функционала

### Средний приоритет (позже):
5. Добавить контекстные меню в другие виджеты
6. Оптимизация и улучшения

### Низкий приоритет (опционально):
7. Создание MenuService
8. Расширенная документация

---

## Заключение

Система меню из noctalia-shell значительно более гибкая и универсальная по сравнению с текущей реализацией. Адаптация позволит:
- Использовать единую систему для всех меню
- Легко добавлять контекстные меню в любые виджеты
- Подготовить базу для будущих функций (dashboard, dock, desktop widgets)
- Сохранить обратную совместимость с существующим кодом

Рекомендуется начать с этапов 1-2 (создание базовых компонентов и рефакторинг PopupMenuWindow), так как они дают максимальную пользу при минимальных изменениях в существующем коде.
