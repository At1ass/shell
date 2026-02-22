# Быстрый старт: Новая система цветов

## 🎯 Основные концепции

### Две палитры:
- **`ColorService.palette`** - базовая палитра от MCU
- **`ColorService.tPalette`** - обработанная с прозрачностью и коррекцией

### Функция layer() для создания глубины:
```qml
// level 0 - базовый слой (для backgrounds)
color: ColorService.layer(ColorService.palette.surface, 0)

// level 1 - первый слой (для containers)
color: ColorService.layer(ColorService.palette.surfaceContainer, 1)

// level 2 - второй слой (для elevated surfaces)
color: ColorService.layer(ColorService.palette.surfaceContainer, 2)

// level 3 - третий слой (для highlights)
color: ColorService.layer(ColorService.palette.surfaceContainer, 3)
```

## 🎨 Варианты палитр MCU

| Variant | Описание | Когда использовать |
|---------|----------|-------------------|
| **vibrant** | Максимальная chroma | Для ярких, выразительных тем |
| **tonalspot** | Пастельная, низкая chroma | По умолчанию MD3, спокойные темы |
| **expressive** | Средняя chroma, вариация hue | Для креативных дизайнов |
| **fidelity** | Точное соответствие seed | Когда важна точность цвета |
| **content** | Почти = fidelity | Альтернатива fidelity |
| **fruitsalad** | Игривая, seed hue не используется | Для необычных тем |
| **rainbow** | Радужные оттенки | Для ярких игривых тем |
| **neutral** | Близко к grayscale | Минималистичные дизайны |
| **monochrome** | Полный grayscale | Строгие, деловые интерфейсы |

## 🔆 Уровни контраста

| Уровень | Значение | WCAG | Когда использовать |
|---------|----------|------|-------------------|
| **standard** | 0.0 | ≥ 3.0 | Стандартная иерархия |
| **medium** | 0.5 | ≥ 4.5 | Улучшенная читаемость |
| **high** | 1.0 | ≥ 7.0 | Максимальная доступность |

## 📦 Surface роли (MD3)

### Три базовых surface:
- `surface` - дефолтный фон
- `surfaceDim` - затемнённый (≤ surface tone)
- `surfaceBright` - самый светлый

### Пять container уровней (от низкого к высокому emphasis):
- `surfaceContainerLowest` - минимальный
- `surfaceContainerLow` - низкий
- `surfaceContainer` - дефолтный ⭐
- `surfaceContainerHigh` - высокий
- `surfaceContainerHighest` - максимальный

### Рекомендации:
```qml
// Для основного фона
color: ColorService.tPalette.surface

// Для навигационных панелей
color: ColorService.tPalette.surfaceContainer

// Для карточек и диалогов
color: ColorService.tPalette.surfaceContainerHigh

// Для выделяющихся элементов
color: ColorService.tPalette.surfaceContainerHighest
```

## 🛠️ Примеры использования

### Простая карточка с глубиной:
```qml
Rectangle {
    color: ColorService.tPalette.surfaceContainerHigh
    radius: Config.shape.large
    border.width: 1
    border.color: ColorService.tPalette.outlineVariant
}
```

### Elevated панель:
```qml
Rectangle {
    color: ColorService.layer(ColorService.palette.surfaceContainer, 2)
}
```

### Кнопка с state layer:
```qml
Rectangle {
    color: ColorService.tPalette.primaryContainer

    Rectangle {
        anchors.fill: parent
        color: ColorService.palette.onPrimaryContainer
        opacity: mouseArea.pressed ? 0.12 : (mouseArea.containsMouse ? 0.08 : 0)
    }
}
```

### Адаптивный текст:
```qml
Text {
    color: ColorService.on(parent.color)  // Автоматический выбор
}
```

## ⚙️ Конфигурация

### Минимальная конфигурация:
```json
{
  "appearance": {
    "theme": {
      "variant": "tonalspot",
      "contrast": 0.0,
      "darkMode": true
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

### Preset'ы:

**Vibrant (яркий):**
```json
{
  "variant": "vibrant",
  "contrast": 0.0,
  "transparency": { "enabled": true, "base": 0.85, "layers": 0.40 }
}
```

**Accessible (доступный):**
```json
{
  "variant": "fidelity",
  "contrast": 1.0,
  "transparency": { "enabled": false, "base": 1.0, "layers": 1.0 }
}
```

**Minimal (минималистичный):**
```json
{
  "variant": "neutral",
  "contrast": 0.0,
  "transparency": { "enabled": true, "base": 0.80, "layers": 0.50 }
}
```

## 🎯 Миграция существующего кода

### Простая замена:
```qml
// Было:
color: Config.colors.surfaceContainerHigh

// Стало:
color: ColorService.tPalette.surfaceContainerHigh
```

### С динамическим слоем:
```qml
// Было:
Rectangle {
    color: Config.colors.primary
    opacity: 0.08
}

// Стало:
Rectangle {
    color: ColorService.layer(ColorService.palette.primary, 1)
}
```

### Elevation замена:
```qml
// Было:
Rectangle {
    color: Config.colors.surface
    Rectangle {
        color: Config.colors.primary
        opacity: Config.elevation.level2Opacity
    }
}

// Стало:
Rectangle {
    color: ColorService.layer(ColorService.palette.surface, 2)
}
```

## 🧪 Быстрая проверка

### Тест 1: Luminance работает
```qml
Text {
    text: "Wall luminance: " + ColorService.wallLuminance.toFixed(2)
}
```

### Тест 2: Layer работает
```qml
Rectangle {
    width: 100
    height: 100
    color: ColorService.layer(ColorService.palette.primary, 1)
}
```

### Тест 3: Transparency работает
```qml
Rectangle {
    width: 100
    height: 100
    color: ColorService.tPalette.surfaceContainer
    Text {
        text: "Alpha: " + parent.color.a.toFixed(2)
    }
}
```

## 📊 Сравнение: До vs После

| Аспект | До | После |
|--------|-----|--------|
| Палитры | 1 (palette) | 2 (palette + tPalette) |
| Прозрачность | Нет | Да (настраиваемая) |
| Адаптация к обоям | Нет | Да (luminance) |
| Варианты | 1 (content) | 9 (все MCU) |
| Контраст | Фиксированный | 3 уровня |
| Визуальная глубина | Минимальная | Многоуровневая |
| Доступность | Базовая | WCAG AA/AAA |

## 🔗 Полезные ссылки

- **Полный план:** `COLOR_MIGRATION_PLAN.md`
- **MD3 Color System:** https://m3.material.io/styles/color/overview
- **MCU GitHub:** https://github.com/material-foundation/material-color-utilities
- **Caelesia референс:** `../caelesia/services/Colours.qml`

---

**Совет:** Начните с миграции StatusBar и Dashboard - там будет наиболее заметное улучшение!
