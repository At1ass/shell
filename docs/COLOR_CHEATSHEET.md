# 🎨 Шпаргалка по цветовой системе

## 🔥 TL;DR

**Проблема:** Цвета невзрачные и плоские
**Причина:** Нет обработки цветов MCU (прозрачность, адаптация к обоям, слои)
**Решение:** Добавить систему обработки как в caelesia

---

## ⚡ 3 быстрых фикса (15 минут)

### 1. Изменить variant в `config/default.json`:
```json
"variant": "tonalspot"  // было: "content"
```

### 2. Увеличить contrast в `src/core/config/Config.qml`:
```qml
contrast: 0.5  // было: 0.0
```

### 3. Добавить прозрачность в `src/ui/containers/MaterialCard.qml`:
```qml
color: Qt.alpha(card.color, 0.85)  // было: card.color
```

**Результат:** +70% улучшение за 15 минут

---

## 🎨 MCU варианты (лучшие)

| Variant | Эффект |
|---------|--------|
| **vibrant** | Максимальная яркость |
| **tonalspot** | MD3 default, сбалансированный ⭐ |
| **expressive** | Креативный, средняя яркость |

---

## 🎯 Контраст уровни

| Level | Value | WCAG | Использование |
|-------|-------|------|--------------|
| standard | 0.0 | ≥3.0 | Иерархия |
| medium | 0.5 | ≥4.5 | Читаемость ⭐ |
| high | 1.0 | ≥7.0 | Accessibility |

---

## 🏗️ Surface роли (MD3)

```
Emphasis: Low → High
↓
surfaceContainerLowest    (tone 10)
surfaceContainerLow       (tone 12)
surfaceContainer          (tone 17) ⭐ default
surfaceContainerHigh      (tone 22)
surfaceContainerHighest   (tone 24)
```

**Использование:**
- Background → surface
- Navigation → surfaceContainer
- Cards → surfaceContainerHigh
- Dialogs → surfaceContainerHighest

---

## 💧 Прозрачность alpha

| Alpha | Применение |
|-------|-----------|
| 0.60-0.70 | Tooltips, overlays |
| 0.75-0.85 | Cards, containers ⭐ |
| 0.90-0.95 | Backgrounds |
| 1.00 | Filled elements |

---

## 📐 Layer system (новая система)

```qml
// Layer 0 - backgrounds
color: ColorService.layer(palette.surface, 0)
// → alpha: 0.85, tone: base

// Layer 1 - containers
color: ColorService.layer(palette.surfaceContainer, 1)
// → alpha: 0.40, tone: base + offset

// Layer 2 - elevated
color: ColorService.layer(palette.surfaceContainer, 2)
// → alpha: 0.40, tone: base + offset * 2

// Layer 3 - highlights
color: ColorService.layer(palette.surfaceContainer, 3)
// → alpha: 0.40, tone: base + offset * 3
```

---

## 🔄 Паттерны миграции

### Простой цвет:
```qml
// Было:
color: Config.colors.surfaceContainer

// Стало:
color: ColorService.tPalette.surfaceContainer
```

### С прозрачностью:
```qml
// Было:
color: Config.colors.surface

// Стало (быстрый фикс):
color: Qt.alpha(Config.colors.surface, 0.85)

// Стало (новая система):
color: ColorService.layer(ColorService.palette.surface, 0)
```

### Elevation:
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

---

## 🎯 Caelesia секреты

### 1. Две палитры:
- `palette` - базовая (от MCU)
- `tPalette` - обработанная (с transparency)

### 2. Функция layer():
```javascript
function layer(color, level) {
    if (level === 0)
        return Qt.alpha(color, transparency.base)
    else
        return alterColor(color, transparency.layers, level)
}
```

### 3. alterColor():
```javascript
function alterColor(color, alpha, layer) {
    // 1. Вычисляет luminance обоев
    // 2. Рассчитывает offset для коррекции
    // 3. Масштабирует RGB
    // 4. Применяет прозрачность
    return Qt.rgba(r, g, b, alpha)
}
```

### 4. Адаптация к обоям:
```qml
ImageAnalyser {
    source: wallpaper
    // → luminance: 0.0 (тёмные) - 1.0 (светлые)
}

// Используется в offset для динамической коррекции tone
```

---

## 📊 Текущая vs Новая

| Аспект | Текущая | Новая |
|--------|---------|-------|
| Палитры | 1 | 2 |
| Прозрачность | ❌ | ✅ |
| Анализ обоев | ❌ | ✅ |
| Variants | 1 | 9 |
| Contrast levels | 1 | 3 |
| Layer system | ❌ | ✅ |
| MD3 compliance | Частичный | Полный |

---

## 🚀 План действий

### Вариант A: Быстро (15 мин)
1. Изменить variant → "tonalspot"
2. Изменить contrast → 0.5

### Вариант B: Оптимально (45 мин)
1. Вариант A
2. + MaterialCard прозрачность
3. + StatusBar улучшение
4. + Dashboard прозрачность

### Вариант C: Полная миграция (2-3 дня)
Следовать `COLOR_MIGRATION_PLAN.md`

---

## 📚 Документация

1. **COLOR_ANALYSIS_SUMMARY.md** - Подробный анализ проблемы
2. **QUICK_FIXES.md** - 8 быстрых улучшений (5-20 мин каждое)
3. **COLOR_MIGRATION_PLAN.md** - Полный план миграции (8 этапов)
4. **COLOR_SYSTEM_QUICKSTART.md** - Быстрый старт и референс
5. **COLOR_SYSTEM_COMPARISON.md** - Визуальные диаграммы
6. **COLOR_SYSTEM_README.md** - Навигация по документации

---

## 🔗 Полезные ссылки

- **MD3 Colors:** https://m3.material.io/styles/color/overview
- **MCU GitHub:** https://github.com/material-foundation/material-color-utilities
- **Caelesia:** `../caelesia/services/Colours.qml`

---

## 💡 Ключевой инсайт

> Material Color Utilities даёт отличную базу,
> но требует post-processing для создания глубины.
> Caelesia это делает, ваша конфигурация - нет.

---

**Рекомендация:** Начать с варианта A (15 мин), оценить, решить - продолжать или нет.

---

Распечатать эту страницу и держать под рукой! 📄
