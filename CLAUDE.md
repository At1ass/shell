# CLAUDE.md — shell (Quickshell / Hyprland)

> **`AGENTS.md` — единый источник правды по конвенциям.** Прочитай его перед изменением кода.
> Этот файл — короткая операционная выжимка для Claude Code; при расхождении главенствует `AGENTS.md`.

## Что это
Desktop shell для **Hyprland** на **Quickshell** (QML/Qt 6) + 5 собственных **C++ плагинов**.
Слои: `core/config` → `core/services` → `features`; `ui` (MD3-библиотека) зависит только от `config`; `plugins` — нативная логика.

## Векторы (приоритет именно в этом порядке)
1. **Корректность** — без утечек, гонок, use-after-free, зомби-процессов, нереактивных биндингов.
2. **Производительность** — UI-поток неблокирующий (цель: 100% non-blocking); тяжёлое — в C++.
3. **Безопасность** — никакой конкатенации в shell-команды; аккуратный lifecycle процессов/файлов.
4. **MD3** — цвет/типографика/форма/motion только через `Theme` и `Tokens`.

## Команды
```bash
# Плагины (без сборки import Mcu/Calendar/... падает):
cd src/plugins && cmake -B build -S . -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/ \
  && cmake --build build && sudo cmake --install build
# Запуск:
QT_QPA_PLATFORMTHEME=gtk3 qs -p ~/.config/quickshell/shell
# IPC:        qs ipc call <handler> <fn> [arg]
# Линт:       tools/lint.sh <files>   # qmllint с import-путями; clean на изменённых QML
# Инварианты: tools/check.sh          # запреты §10, ratchet-базлайн; exit 1 = регресс
```

## Импорты
`qs.src.core.config` (Theme/Tokens/AppConfig) · `qs.src.core.services` (+ `GlobalStates`) ·
`qs.src.ui.{base,containers,feedback,inputs}` · `qs.src.features.<feature>`.
**`ui` НИКОГДА не импортирует `services`.** Обратных рёбер зависимостей нет.

## Как делать правильно
- **Config-first, без GUI.** Настройка только через `config.json` (+ `config.schema.json`) и IPC. GUI-настроек в проекте нет и не будет. Новый параметр: поле в `config.json` → запись в схему (`description`) → дефолт в `default.json` → геттер в `AppConfig`. Пресеты/схемы = JSON-данные + применение по IPC, не UI.
- Цвет: `Theme.<role>` / `Qt.alpha(Theme.x, a)`. Размеры/motion/типографика: `Tokens.*`.
- UI в `features/` собирать из `src/ui/*` (`Surface`, `MaterialText`, …), не из сырых `Rectangle`/`Text`.
- Сервисы: нативный API (Pipewire/Mpris/Networking/Bluetooth/Notifications) > `Process`+CLI (только где нативного нет).
- Состояние панелей/хоткеи/IPC — `GlobalStates`. Настройки — `config.json` (читать) + `state.json` (писать runtime).
- Тяжёлое/синхронное/парсинг → C++ плагин, не QML.

## ⛔ Жёсткие запреты (полный список — §10 AGENTS.md)
- **GUI-настройки в любом виде** (окно/панели настроек, declarative ConfigSwitch, DnD-переразметка, GUI-пикеры пресетов/тем) — config-first; только `config.json` + IPC. Новый ключ — обязательно в `config.schema.json` + `default.json`.
- Хардкод цвета/размера/длительности/easing/шрифта; `font.pointSize`; elevation через `opacity`.
- Сырой `Rectangle`/`Text` в `features/`; стоковые `QtQuick.Controls` для оформленного UI.
- Ссылки на `ColorService`/`palette`/`tPalette`/`.layer()` — **их нет в коде** (мёртвый план миграции, не реализован).
- Импорт `services` из `ui`; свойства состояния на `ShellRoot`; запись runtime в `config.json`.
- Синхронная работа в UI-потоке; `StackLayout` для вкладок; спавн процессов в цикле; `console.log`/`qDebug` в проде.
- `process.running=true` без `!running`; `createObject` без `destroy`; неограниченные кэши/очереди; orphan-таймеры.
- `sh -c` с конкатенацией переменных (только argv + regex-guard); хардкод путей `/home/<user>/...`.
- Коммит `build/`, `shell.zip`, `test.diff`; новые аналитические `.md`; смешение языков и emoji в комментариях.

## Важно
- Источники правды: `AGENTS.md`/`CLAUDE.md` (конвенции), `README.md`, `ROADMAP.md`, `config.schema.json`. Архив `docs/` удалён — верь коду и `AGENTS.md` (устаревшие планы/комментарии могут врать).
- Код-комментарии — на английском. Конвенции фиксируй в `AGENTS.md`, не в новых файлах.
- Менял фичу/поведение — обнови `README.md`/`ROADMAP.md`.
