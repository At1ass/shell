# Патчи для вендоренного material-color-utilities

`0001-drop-abseil-keep-double-abs.patch` — применяется к сабмодулю
`external/material-color-utilities` (коммит 07b2c68).

**Зачем.** Плагин `Mcu` был единственным, что тянуло abseil-cpp: 40 SONAME вида
`libabsl_*.so.NNNN`, где NNNN — дата релиза. Каждое обновление abseil делало
установленный `/usr/lib/qt6/qml/Mcu/libmcuqml.so` незагружаемым, из-за чего
падал весь QML-конфиг, а вместе с ним greetd. Реального absl в MCU было на
четыре строки: `flat_hash_map` в квантователе и `StrCat(Hex())` в `HexFromArgb`.

**Ловушка.** Заголовок `absl/container/flat_hash_map.h` транзитивно затягивал в
`wsmeans.cc` вещественную перегрузку `abs`. После его удаления голый `abs()` в
строке `abs(sqrt(a) - sqrt(b))` молча резолвился в `abs(int)`, обрезал дельту в
ноль, замораживал переназначение точек в k-means и менял палитру. Поэтому в
патче стоит явный `std::fabs`.

**Проверено.** Квантователь и сквозной конвейер темы (7 вариантов схемы x
dark/light x 2 уровня контраста x 23 роли) дают побайтово тот же результат, что
сборка с abseil. `HexFromArgb` сверен со старой реализацией на всех 2^24 младших
значениях — расхождений нет.

**Апстрим не поможет.** `cpp/` в material-color-utilities не менялся с
2024-10-01; на HEAD (5b3618b, 2026-08-21) баг с `abs` и зависимость от absl на
месте, и от нашего 07b2c68 каталог `cpp/` не отличается ничем. Обновление
сабмодуля этот патч не отменяет.

## Исправление `abs` в остальных пяти файлах (30.08.2026)

Тот же неквалифицированный `abs()` на double выбирал целочисленную перегрузку
ещё в пяти файлах: `contrast/contrast.cc` (2 места),
`dynamiccolor/material_dynamic_colors.cc` (3), `dynamiccolor/dynamic_color.cc`
(1), `palettes/tones.cc` (1), `temperature/temperature_cache.cc` (3, плюс файл
вовсе не включал `<cmath>`). Все десять заменены на `std::fabs`.

Это именно ошибка порта, а не решение: Dart (`.abs()`), TypeScript
(`Math.abs`) и Java (`Math.abs`) во всех десяти местах используют вещественный
модуль. Соответствие проверялось построчно.

**A/B-отчёт** (10 seed-ов x 7 вариантов схемы x dark/light x 4 уровня контраста
x 23 роли, плюс прямые пробы правленых функций — 15482 значения):

| Что проверялось | Значений | Изменилось |
|---|---|---|
| `Lighter`/`Darker`/`*Unsafe` (contrast.cc) | 1092 | 0 |
| `TonalPalette` key color и `get(tone)` (tones.cc) | 1440 | 0 |
| `GetRelativeTemperature` | 10 | 0 |
| `GetComplement` | 10 | 10 |
| `GetAnalogousColors` | 50 | 40 |
| Роли схемы | 12880 | 499 (3.9%) |

Изменения ролей затрагивают **только варианты `fidelity` и `content`** и почти
только роли `tertiary*` — это подпись `TemperatureCache`, из которого эти две
схемы выводят третичную палитру. Отдельная сборка, где исправлен только
`temperature_cache.cc`, воспроизводит 541 из 549 расхождений; оставшиеся 8 —
`secondaryContainer`/`onSecondaryContainer` у двух seed-ов, отклонение до 3 из
255, источник — `material_dynamic_colors.cc`.

Варианты `tonalspot`, `vibrant`, `expressive`, `neutral`, `monochrome` не
изменились ни на один цвет. Рабочая конфигурация (`appearance.theme.variant =
vibrant`) попадает в эту группу: 0 из 1840 её ролей сдвинулось.
