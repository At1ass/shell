# План миграции на улучшенную систему цветов

## Оглавление
1. [Введение](#введение)
2. [Проблемы текущей системы](#проблемы-текущей-системы)
3. [Цели миграции](#цели-миграции)
4. [Архитектура новой системы](#архитектура-новой-системы)
5. [Этапы миграции](#этапы-миграции)
6. [Технические детали](#технические-детали)
7. [Тестирование и валидация](#тестирование-и-валидация)

---

## Введение

Текущая цветовая система использует Material Color Utilities (MCU) напрямую без дополнительной обработки, что приводит к невзрачному и "плоскому" внешнему виду. Данный план предлагает миграцию на продвинутую систему, вдохновленную caelesia и следующую гайдлайнам Material Design 3 (Material You).

---

## Проблемы текущей системы

### Критические недостатки:
1. ❌ **Прямое использование цветов MCU** без post-processing
2. ❌ **contrast: 0.0** - минимальный контраст между цветами
3. ❌ **Отсутствие системы прозрачности** - нет визуальной глубины
4. ❌ **Нет анализа обоев** - цвета не адаптируются к wallpaper luminance
5. ❌ **Одна палитра** - нет разделения на базовую и обработанную
6. ❌ **Статичный variant "content"** - нет возможности выбора
7. ❌ **Фиксированная opacity** для elevation (0.08) - не учитывает контекст

### Результат:
- Цвета выглядят невзрачно и плоско
- Нет визуальной иерархии
- Плохая интеграция с обоями
- Недостаточный контраст для некоторых пользователей

---

## Цели миграции

### Основные цели:

1. ✅ **Визуальная глубина** через систему прозрачности и слоёв
2. ✅ **Адаптивность** к яркости обоев (wallpaper luminance)
3. ✅ **Гибкость** - поддержка всех 9 вариантов MCU палитр
4. ✅ **Доступность** - поддержка 3 уровней контраста (standard/medium/high)
5. ✅ **Соответствие MD3** - следование гайдлайнам Material Design 3
6. ✅ **Простота использования** - минимальные изменения в существующем коде

### Material Design 3 принципы:

> **Из MD3 документации:**
> - Tone-based surface roles (не привязаны к elevation)
> - 26+ color roles для правильного контраста
> - 3 уровня контраста: standard, medium, high
> - Tonal palette: 13-tone range (0-100)
> - Разница в 40 tone = WCAG ≥ 3.0, разница в 50 tone = WCAG ≥ 4.5

---

## Архитектура новой системы

### Структура файлов:

```
src/core/
├── config/
│   ├── Config.qml (обновлённый)
│   └── qmldir
└── services/
    ├── ColorService.qml (НОВЫЙ - основной цветовой сервис)
    ├── WallpaperAnalyzer.qml (НОВЫЙ - анализ обоев)
    └── qmldir
```

### Компоненты системы:

#### 1. **ColorService.qml** (Singleton)
Основной сервис для управления цветами:
- Две палитры: `palette` (базовая) и `tPalette` (обработанная)
- Функция `layer(color, level)` для создания глубины
- Функция `alterColor()` для динамической коррекции
- Поддержка transparency режима
- Интеграция с WallpaperAnalyzer

#### 2. **WallpaperAnalyzer.qml** (Singleton)
Анализ обоев для адаптации цветов:
- Вычисление luminance обоев
- ImageAnalyser из MCU или Caelestia
- Реактивное обновление при смене обоев

#### 3. **Обновлённый Config.qml**
Расширенная конфигурация:
- Выбор variant (9 опций)
- Уровень контраста (standard/medium/high)
- Настройки transparency
- Интеграция с ColorService

---

## Этапы миграции

### **Этап 1: Подготовка и создание базовых сервисов**

**Задачи:**
1. Создать `WallpaperAnalyzer.qml` с ImageAnalyser
2. Создать базовую структуру `ColorService.qml`
3. Реализовать функцию `getLuminance(color)`
4. Добавить в конфигурацию параметры transparency

**Файлы для создания:**
- `src/core/services/WallpaperAnalyzer.qml`
- `src/core/services/ColorService.qml`
- Обновить `src/core/services/qmldir`

**Критерии завершения:**
- ✅ WallpaperAnalyzer корректно вычисляет luminance
- ✅ ColorService инициализируется без ошибок
- ✅ Функция getLuminance() возвращает корректные значения (0.0-1.0)

---

### **Этап 2: Реализация системы прозрачности**

**Задачи:**
1. Добавить в Config transparency настройки:
   ```json
   "transparency": {
     "enabled": true,
     "base": 0.85,
     "layers": 0.40
   }
   ```
2. Реализовать функцию `alterColor(color, alpha, layer)`
3. Реализовать функцию `layer(color, layer)`
4. Создать `tPalette` с обработанными цветами

**Алгоритм `alterColor()` (из caelesia):**
```javascript
function alterColor(c, a, layer) {
    const luminance = getLuminance(c);

    // Динамическое смещение яркости
    const offset = (!light || layer == 1 ? 1 : -layer / 2)
        * (light ? 0.2 : 0.3)
        * (1 - transparency.base)
        * (1 + wallLuminance * (light ? (layer == 1 ? 3 : 1) : 2.5));

    const scale = (luminance + offset) / luminance;
    const r = Math.max(0, Math.min(1, c.r * scale));
    const g = Math.max(0, Math.min(1, c.g * scale));
    const b = Math.max(0, Math.min(1, c.b * scale));

    return Qt.rgba(r, g, b, a);
}
```

**Использование слоёв (MD3 подход):**
- `layer(color, 0)` - базовый слой с base alpha (для backgrounds)
- `layer(color, 1)` - первый слой с коррекцией яркости (для containers)
- `layer(color, 2)` - второй слой с большей коррекцией (для elevated surfaces)
- `layer(color, 3)` - третий слой (для highlights)

**Критерии завершения:**
- ✅ Функция layer() возвращает цвета с правильной прозрачностью
- ✅ alterColor() корректно изменяет яркость в зависимости от light/dark
- ✅ tPalette содержит все обработанные цвета

---

### **Этап 3: Поддержка вариантов палитр и контраста**

**Задачи:**
1. Добавить выбор variant в конфигурацию:
   ```json
   "theme": {
     "variant": "tonalspot",
     "contrast": 0.0
   }
   ```

2. Реализовать поддержку всех 9 вариантов MCU:
   - **vibrant** - максимальная chroma (для ярких тем)
   - **tonalspot** - пастельная палитра, низкая chroma (по умолчанию MD3)
   - **expressive** - средняя chroma, вариация hue
   - **fidelity** - точное соответствие seed color
   - **content** - почти идентичен fidelity
   - **fruitsalad** - игривая тема, seed hue не используется
   - **rainbow** - игривая тема с радужными оттенками
   - **neutral** - близко к grayscale, минимум chroma
   - **monochrome** - полный grayscale

3. Добавить поддержку 3 уровней контраста (MD3):
   - **standard** (0.0) - стандартная визуальная иерархия
   - **medium** (0.5) - улучшенный контраст для слабовидящих
   - **high** (1.0) - максимальный контраст для accessibility

**Обновление McuTheme:**
```qml
McuTheme {
    id: theme
    source: WallpaperAnalyzer.currentWallpaper
    darkMode: config.data.appearance?.theme?.darkMode ?? true
    variant: config.data.appearance?.theme?.variant ?? "tonalspot"
    contrast: config.data.appearance?.theme?.contrast ?? 0.0
}
```

**Критерии завершения:**
- ✅ Все 9 вариантов работают корректно
- ✅ Смена варианта в конфиге обновляет UI
- ✅ Уровни контраста соответствуют WCAG (Δ40 tone ≥ 3.0, Δ50 tone ≥ 4.5)

---

### **Этап 4: Интеграция с WallpaperAnalyzer**

**Задачи:**
1. Связать ColorService с WallpaperAnalyzer
2. Добавить реактивное обновление при смене обоев
3. Реализовать fallback при отсутствии обоев

**Реализация:**
```qml
// В ColorService.qml
Connections {
    target: WallpaperAnalyzer
    function onLuminanceChanged() {
        // Пересчитать tPalette с новым wallLuminance
        updateProcessedPalette();
    }
}
```

**MD3 принцип:**
> Dynamic color takes a single color from wallpaper or in-app content
> and creates an accessible color scheme assigned to elements in the UI.

**Критерии завершения:**
- ✅ Смена обоев триггерит пересчёт цветов
- ✅ Цвета адаптируются к яркости обоев
- ✅ Работает fallback на дефолтные цвета

---

### **Этап 5: Миграция компонентов UI**

**Задачи:**
1. Создать алиасы для обратной совместимости
2. Постепенно мигрировать компоненты на новую систему
3. Обновить существующие компоненты

**Стратегия миграции:**

#### A. Создать алиасы (обратная совместимость):
```qml
// В Config.qml
property alias colors: ColorService.palette
property alias processedColors: ColorService.tPalette
```

#### B. Обновить критичные компоненты первыми:
1. **StatusBar** - основная панель
2. **Dashboard** - главная панель управления
3. **MaterialCard** - базовый контейнер
4. **MaterialButton** - базовая кнопка

#### C. Паттерн миграции компонентов:

**Было:**
```qml
Rectangle {
    color: Config.colors.surfaceContainerHigh
}
```

**Стало (с прозрачностью):**
```qml
Rectangle {
    color: ColorService.tPalette.surfaceContainerHigh
}
```

**Или (с динамическим слоем):**
```qml
Rectangle {
    color: ColorService.layer(ColorService.palette.surfaceContainer, 2)
}
```

#### D. Приоритет компонентов для миграции:

**Высокий приоритет:**
- `StatusBar.qml` - основной бар
- `DashboardContent.qml` - панель управления
- `MaterialCard.qml` - базовый контейнер
- `MaterialButton.qml` - кнопки

**Средний приоритет:**
- Все dashboard tabs (QuickTab, SystemTab, WeatherTab)
- NotificationCenter
- Popouts

**Низкий приоритет:**
- Launcher
- OSD
- Специфичные виджеты

**Критерии завершения:**
- ✅ Все компоненты высокого приоритета мигрированы
- ✅ Нет визуальных регрессий
- ✅ Старые компоненты работают через алиасы

---

### **Этап 6: Улучшение Surface и Elevation систем**

**Задачи:**
1. Заменить фиксированные elevation opacity на динамические слои
2. Реализовать MD3 surface hierarchy

**MD3 Surface roles (из документации):**
- **surface** - дефолтный фон
- **surfaceDim** - затемнённый surface (≤ surface tone)
- **surfaceBright** - самый светлый surface
- **surfaceContainerLowest** - минимальный emphasis
- **surfaceContainerLow** - низкий emphasis
- **surfaceContainer** - дефолтный контейнер
- **surfaceContainerHigh** - высокий emphasis
- **surfaceContainerHighest** - максимальный emphasis

**Реализация динамического elevation:**

**Было:**
```qml
Rectangle {
    color: Config.colors.surfaceContainer
    Rectangle {
        color: Config.colors.primary
        opacity: Config.elevation.level2Opacity  // Фиксированная 0.08
    }
}
```

**Стало:**
```qml
Rectangle {
    color: ColorService.layer(
        ColorService.palette.surfaceContainer,
        2  // Динамический уровень с учётом luminance
    )
}
```

**Таблица соответствия elevation → surface roles:**

| Старый elevation | Новый surface role | Layer level |
|-----------------|-------------------|-------------|
| level0 | surface | 0 |
| level1 | surfaceContainerLow | 1 |
| level2 | surfaceContainer | 1 |
| level3 | surfaceContainerHigh | 2 |
| level4+ | surfaceContainerHighest | 3 |

**Критерии завершения:**
- ✅ Все surface roles реализованы
- ✅ Динамическое elevation работает корректно
- ✅ Визуальная иерархия улучшена

---

### **Этап 7: Оптимизация и тонкая настройка**

**Задачи:**
1. Оптимизировать производительность ColorService
2. Добавить кэширование обработанных цветов
3. Настроить параметры transparency под разные сценарии

**Оптимизации:**

#### A. Кэширование:
```qml
property var cachedTPalette: ({})

function updateProcessedPalette() {
    if (cachedWallLuminance === wallLuminance &&
        cachedTransparencyEnabled === transparency.enabled) {
        return; // Используем кэш
    }

    // Пересчитываем только при изменении параметров
    recalculateTPalette();
    cachedWallLuminance = wallLuminance;
    cachedTransparencyEnabled = transparency.enabled;
}
```

#### B. Настройка параметров под UI:

**Для светлых обоев:**
```json
"transparency": {
  "enabled": true,
  "base": 0.90,
  "layers": 0.35
}
```

**Для тёмных обоев:**
```json
"transparency": {
  "enabled": true,
  "base": 0.85,
  "layers": 0.45
}
```

**Для максимальной чёткости (accessibility):**
```json
"transparency": {
  "enabled": false,
  "base": 1.0,
  "layers": 1.0
}
```

#### C. Дополнительные утилиты:

```qml
// В ColorService
function on(color) {
    // Автоматический выбор on-color для читаемости
    if (color.hslLightness < 0.5)
        return Qt.hsla(color.hslHue, color.hslSaturation, 0.9, 1);
    return Qt.hsla(color.hslHue, color.hslSaturation, 0.1, 1);
}
```

**Критерии завершения:**
- ✅ Нет просадок производительности
- ✅ Кэширование работает корректно
- ✅ Параметры настроены оптимально

---

### **Этап 8: Конфигурация и пользовательские настройки**

**Задачи:**
1. Добавить UI для выбора variant
2. Добавить UI для уровня контраста
3. Добавить toggles для transparency
4. Создать preset'ы цветовых схем

**Структура конфигурации:**

```json
{
  "appearance": {
    "theme": {
      "source": "wallpaper",
      "variant": "tonalspot",
      "darkMode": true,
      "contrast": "standard"
    },
    "colors": {
      "transparency": {
        "enabled": true,
        "base": 0.85,
        "layers": 0.40
      }
    }
  }
}
```

**Preset'ы (для быстрого переключения):**

```javascript
const PRESETS = {
  "vibrant": {
    variant: "vibrant",
    contrast: "standard",
    transparency: { enabled: true, base: 0.85, layers: 0.40 }
  },
  "pastel": {
    variant: "tonalspot",
    contrast: "standard",
    transparency: { enabled: true, base: 0.90, layers: 0.35 }
  },
  "accessible": {
    variant: "fidelity",
    contrast: "high",
    transparency: { enabled: false, base: 1.0, layers: 1.0 }
  },
  "minimal": {
    variant: "neutral",
    contrast: "standard",
    transparency: { enabled: true, base: 0.80, layers: 0.50 }
  }
}
```

**UI для настроек (опционально):**
- Dashboard → Settings Tab → Color Settings
- Выбор variant из dropdown
- Slider для контраста
- Toggle для transparency

**Критерии завершения:**
- ✅ Все настройки доступны в конфиге
- ✅ Preset'ы работают корректно
- ✅ Изменения применяются без перезапуска

---

## Технические детали

### Структура ColorService.qml (полная версия)

```qml
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import Mcu 1.0

Singleton {
    id: root

    // ============ Состояние ============
    property bool showPreview: false
    readonly property bool light: showPreview ? previewLight : currentLight
    property bool currentLight: false
    property bool previewLight: false

    // ============ Палитры ============
    readonly property M3Palette palette: showPreview ? preview : current
    readonly property M3TPalette tPalette: M3TPalette {}
    readonly property M3Palette current: M3Palette {}
    readonly property M3Palette preview: M3Palette {}

    // ============ Прозрачность ============
    readonly property Transparency transparency: Transparency {}

    // ============ Анализ обоев ============
    readonly property real wallLuminance: WallpaperAnalyzer.luminance

    // ============ Основные функции ============

    // Вычисление luminance цвета
    function getLuminance(c) {
        if (c.r == 0 && c.g == 0 && c.b == 0)
            return 0;
        return Math.sqrt(0.299 * (c.r ** 2) + 0.587 * (c.g ** 2) + 0.114 * (c.b ** 2));
    }

    // Динамическая коррекция цвета с учётом luminance обоев
    function alterColor(c, a, layer) {
        const luminance = getLuminance(c);

        // Динамическое смещение яркости
        const offset = (!light || layer == 1 ? 1 : -layer / 2)
            * (light ? 0.2 : 0.3)
            * (1 - transparency.base)
            * (1 + wallLuminance * (light ? (layer == 1 ? 3 : 1) : 2.5));

        const scale = (luminance + offset) / luminance;
        const r = Math.max(0, Math.min(1, c.r * scale));
        const g = Math.max(0, Math.min(1, c.g * scale));
        const b = Math.max(0, Math.min(1, c.b * scale));

        return Qt.rgba(r, g, b, a);
    }

    // Применение слоя к цвету
    function layer(c, layer) {
        if (!transparency.enabled)
            return c;

        return layer === 0
            ? Qt.alpha(c, transparency.base)
            : alterColor(c, transparency.layers, layer ?? 1);
    }

    // Автоматический выбор on-color
    function on(c) {
        if (c.hslLightness < 0.5)
            return Qt.hsla(c.hslHue, c.hslSaturation, 0.9, 1);
        return Qt.hsla(c.hslHue, c.hslSaturation, 0.1, 1);
    }

    // ============ Компоненты ============

    component Transparency: QtObject {
        readonly property bool enabled: Config.data.appearance?.colors?.transparency?.enabled ?? true
        readonly property real base: (Config.data.appearance?.colors?.transparency?.base ?? 0.85)
            - (root.light ? 0.1 : 0)
        readonly property real layers: Config.data.appearance?.colors?.transparency?.layers ?? 0.40
    }

    component M3TPalette: QtObject {
        // Обработанные цвета с прозрачностью и коррекцией
        readonly property color primary: root.layer(root.palette.primary)
        readonly property color onPrimary: root.layer(root.palette.onPrimary)
        readonly property color primaryContainer: root.layer(root.palette.primaryContainer)
        readonly property color onPrimaryContainer: root.layer(root.palette.onPrimaryContainer)

        readonly property color secondary: root.layer(root.palette.secondary)
        readonly property color onSecondary: root.layer(root.palette.onSecondary)
        readonly property color secondaryContainer: root.layer(root.palette.secondaryContainer)
        readonly property color onSecondaryContainer: root.layer(root.palette.onSecondaryContainer)

        readonly property color tertiary: root.layer(root.palette.tertiary)
        readonly property color onTertiary: root.layer(root.palette.onTertiary)
        readonly property color tertiaryContainer: root.layer(root.palette.tertiaryContainer)
        readonly property color onTertiaryContainer: root.layer(root.palette.onTertiaryContainer)

        readonly property color error: root.layer(root.palette.error)
        readonly property color onError: root.layer(root.palette.onError)
        readonly property color errorContainer: root.layer(root.palette.errorContainer)
        readonly property color onErrorContainer: root.layer(root.palette.onErrorContainer)

        readonly property color background: root.layer(root.palette.background, 0)
        readonly property color onBackground: root.layer(root.palette.onBackground)

        readonly property color surface: root.layer(root.palette.surface, 0)
        readonly property color surfaceDim: root.layer(root.palette.surfaceDim, 0)
        readonly property color surfaceBright: root.layer(root.palette.surfaceBright, 0)
        readonly property color surfaceContainerLowest: root.layer(root.palette.surfaceContainerLowest)
        readonly property color surfaceContainerLow: root.layer(root.palette.surfaceContainerLow)
        readonly property color surfaceContainer: root.layer(root.palette.surfaceContainer)
        readonly property color surfaceContainerHigh: root.layer(root.palette.surfaceContainerHigh)
        readonly property color surfaceContainerHighest: root.layer(root.palette.surfaceContainerHighest)

        readonly property color onSurface: root.layer(root.palette.onSurface)
        readonly property color surfaceVariant: root.layer(root.palette.surfaceVariant, 0)
        readonly property color onSurfaceVariant: root.layer(root.palette.onSurfaceVariant)

        readonly property color outline: root.layer(root.palette.outline)
        readonly property color outlineVariant: root.layer(root.palette.outlineVariant)

        readonly property color inverseSurface: root.layer(root.palette.inverseSurface, 0)
        readonly property color inverseOnSurface: root.layer(root.palette.inverseOnSurface)
        readonly property color inversePrimary: root.layer(root.palette.inversePrimary)

        readonly property color shadow: root.layer(root.palette.shadow)
        readonly property color scrim: root.layer(root.palette.scrim)
        readonly property color surfaceTint: root.layer(root.palette.surfaceTint)
    }

    component M3Palette: QtObject {
        // Базовая палитра от MCU (заполняется из Config.colors)
        property color primary: "#000000"
        property color onPrimary: "#ffffff"
        property color primaryContainer: "#000000"
        property color onPrimaryContainer: "#ffffff"

        property color secondary: "#000000"
        property color onSecondary: "#ffffff"
        property color secondaryContainer: "#000000"
        property color onSecondaryContainer: "#ffffff"

        property color tertiary: "#000000"
        property color onTertiary: "#ffffff"
        property color tertiaryContainer: "#000000"
        property color onTertiaryContainer: "#ffffff"

        property color error: "#000000"
        property color onError: "#ffffff"
        property color errorContainer: "#000000"
        property color onErrorContainer: "#ffffff"

        property color background: "#000000"
        property color onBackground: "#ffffff"

        property color surface: "#000000"
        property color surfaceDim: "#000000"
        property color surfaceBright: "#000000"
        property color surfaceContainerLowest: "#000000"
        property color surfaceContainerLow: "#000000"
        property color surfaceContainer: "#000000"
        property color surfaceContainerHigh: "#000000"
        property color surfaceContainerHighest: "#000000"

        property color onSurface: "#ffffff"
        property color surfaceVariant: "#000000"
        property color onSurfaceVariant: "#ffffff"

        property color inverseSurface: "#ffffff"
        property color inverseOnSurface: "#000000"
        property color inversePrimary: "#000000"

        property color outline: "#000000"
        property color outlineVariant: "#000000"

        property color shadow: "#000000"
        property color scrim: "#000000"
        property color surfaceTint: "#000000"
    }

    // ============ Инициализация ============
    Component.onCompleted: {
        // Копируем цвета из Config в current palette
        updateCurrentPalette();
    }

    Connections {
        target: Config
        function onColorsChanged() {
            updateCurrentPalette();
        }
    }

    Connections {
        target: WallpaperAnalyzer
        function onLuminanceChanged() {
            // tPalette автоматически обновится через bindings
        }
    }

    function updateCurrentPalette() {
        const colors = Config.colors;
        for (let key in colors) {
            if (current.hasOwnProperty(key)) {
                current[key] = colors[key];
            }
        }
    }
}
```

### Структура WallpaperAnalyzer.qml

```qml
pragma Singleton
import Quickshell
import QtQuick
import Mcu 1.0
import qs.src.core.services

Singleton {
    id: root

    property string currentWallpaper: WallpaperService.currentWallpaper
    property real luminance: 0.0

    ImageAnalyser {
        id: analyser
        source: root.currentWallpaper

        onLuminanceChanged: {
            root.luminance = luminance;
        }
    }

    // Fallback если ImageAnalyser недоступен
    function calculateFallbackLuminance() {
        // Можно использовать время суток или дефолтное значение
        return 0.5;
    }
}
```

---

## Тестирование и валидация

### Чек-лист для каждого этапа:

#### Этап 1-2: Базовые сервисы
- [ ] WallpaperAnalyzer корректно определяет luminance
- [ ] getLuminance() возвращает 0.0-1.0
- [ ] Transparency настройки загружаются из конфига
- [ ] alterColor() изменяет яркость корректно
- [ ] layer() применяет прозрачность правильно

#### Этап 3-4: Варианты и обои
- [ ] Все 9 вариантов MCU работают
- [ ] Смена варианта обновляет UI
- [ ] Контраст соответствует WCAG
- [ ] Смена обоев триггерит обновление
- [ ] Fallback работает без обоев

#### Этап 5-6: Миграция UI
- [ ] StatusBar использует новые цвета
- [ ] Dashboard обновлён
- [ ] MaterialCard с прозрачностью
- [ ] Нет визуальных регрессий
- [ ] Surface hierarchy работает

#### Этап 7-8: Оптимизация
- [ ] Нет просадок FPS
- [ ] Кэширование работает
- [ ] Preset'ы применяются
- [ ] Конфиг сохраняется корректно

### Валидация доступности (WCAG):

Проверить контраст для комбинаций:
- [ ] onSurface на surface: ≥ 4.5:1 (AA)
- [ ] onPrimary на primary: ≥ 4.5:1 (AA)
- [ ] onSecondary на secondary: ≥ 4.5:1 (AA)
- [ ] High contrast режим: ≥ 7:1 (AAA)

### Тестирование на разных обоях:

- [ ] Светлые обои (luminance > 0.7)
- [ ] Тёмные обои (luminance < 0.3)
- [ ] Средние обои (luminance 0.3-0.7)
- [ ] Цветные обои (высокая saturation)
- [ ] Монохромные обои (низкая saturation)

---

## Риски и митигация

### Возможные проблемы:

1. **Производительность** при пересчёте цветов
   - **Митигация:** Кэширование, lazy evaluation

2. **Несовместимость** со старым кодом
   - **Митигация:** Алиасы для обратной совместимости

3. **ImageAnalyser** может быть недоступен
   - **Митигация:** Fallback на дефолтные значения

4. **Слишком тёмные/светлые** цвета после обработки
   - **Митигация:** Clamp значения, настраиваемые параметры

---

## Ресурсы и референсы

### Material Design 3 документация:
- [Color System Overview](https://m3.material.io/styles/color/overview)
- [Color Roles](https://m3.material.io/styles/color/roles)
- [Dynamic Color](https://m3.material.io/styles/color/dynamic)
- [Accessibility](https://m3.material.io/foundations/accessible-design/overview)

### Material Color Utilities:
- [GitHub Repository](https://github.com/material-foundation/material-color-utilities)
- [Cheat Sheet](https://github.com/material-foundation/material-color-utilities/raw/main/cheat_sheet.png)

### Референс реализации:
- Caelesia: `/home/at1ass/.config/quickshell/caelesia/services/Colours.qml`

---

## Заключение

Данный план миграции обеспечит:
- ✅ **Профессиональный внешний вид** следующий MD3 гайдлайнам
- ✅ **Визуальную глубину** через систему прозрачности и слоёв
- ✅ **Адаптивность** к обоям и предпочтениям пользователя
- ✅ **Доступность** с поддержкой WCAG стандартов
- ✅ **Гибкость** с 9 вариантами палитр и 3 уровнями контраста
- ✅ **Простоту использования** с минимальными изменениями в коде

Рекомендуемая последовательность: **Этапы 1-4** (базовая функциональность) → **Этап 5** (миграция UI) → **Этапы 6-8** (оптимизация и улучшения).

Ожидаемое время реализации: **2-3 дня** при полной реализации всех этапов.
