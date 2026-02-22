План рефакторинга бара под JSON конфигурацию

  Этап 1: Унификация интерфейса виджетов

  Коммит: refactor(bar): unify widget configuration interface

  - Расширить BarWidgetLoader для передачи полного widgetConfig в виджеты
  - Добавить в каждый виджет свойство property var widgetConfig
  - Добавить в каждый виджет свойство property var widgetSettings: widgetConfig?.settings ?? {}
  - Создать базовую документацию интерфейса виджета (комментарии в BarElement или отдельный файл)

  ---
  Этап 2: Применение settings из конфигурации

  Коммит: refactor(bar): apply widget settings from config

  - WorkspaceWidget: заменить хардкод wsCount и wsBaseIndex на widgetSettings.count и widgetSettings.showWindows
  - ClockWidget: заменить хардкод формата времени на widgetSettings.format и widgetSettings.showDate
  - VolumeWidget: применить widgetSettings.scrollable и widgetSettings.showPercentage
  - MPRISWidget: применить widgetSettings.compact, widgetSettings.showIcon, widgetSettings.maxWidth
  - Добавить fallback значения для всех settings (на случай отсутствия в конфиге)

  ---
  Этап 3: Реализация clickAction и недостающих виджетов

  Коммит: feat(bar): implement clickAction and missing widgets

  - Добавить обработку widgetConfig.clickAction во все виджеты через GlobalStates
  - Убрать хардкод clickAction из виджетов (MPRISWidget, VolumeWidget, ClockWidget)
  - Создать NetworkWidget.qml с базовой реализацией
  - Создать BatteryWidget.qml с базовой реализацией
  - Реализовать TrayWidget.qml (убрать заглушку из BarWidgetLoader)
  - Добавить новые виджеты в switch-case BarWidgetLoader

  ---
  Этап 4: Исправление layout и финальная очистка

  Коммит: refactor(bar): fix layout structure and cleanup

  - Исправить позиционирование center section в StatusBar.qml (убрать anchors.centerIn, использовать Layout правильно)
  - Добавить Item { Layout.fillWidth: true } spacer'ы между секциями для корректного выравнивания
  - Удалить весь закомментированный код из StatusBar.qml
  - Удалить fallback на Config.bar.entries (оставить только Config.data.bar.widgets)
  - Проверить, что все виджеты корректно позиционируются в left/center/right секциях
  - Убедиться, что все хардкоженные значения заменены на конфигурационные

  ---
  Итоговая архитектура

  После завершения рефакторинга:
  - Все виджеты получают конфигурацию через widgetConfig
  - Settings применяются динамически из JSON
  - clickAction обрабатывается единообразно
  - Layout работает корректно для всех трех позиций
  - Нет захардкоженных значений
