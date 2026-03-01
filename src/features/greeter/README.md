# Quickshell Greeter

Greetd greeter — экран входа в систему с Material Design 3 UI.
Отдельная конфигурация Quickshell, работает независимо от основной оболочки.

## Как работает

Greetd запускает Hyprland от пользователя `greeter`, Hyprland запускает
`qs -p .../greeter`, greeter показывает форму логина и общается с greetd
через `Quickshell.Services.Greetd` IPC. После успешной аутентификации
запускает выбранную сессию и завершается.

Внизу экрана — кнопки питания (shutdown, reboot, suspend) через `systemctl`,
доступные без аутентификации.

## Структура файлов

```
greeter/
├── shell.qml                  — Entry point: PanelWindow fullscreen на каждом мониторе
├── GreeterSurface.qml         — Обои + blur + scrim + часы + форма + Greetd IPC
├── config/
│   ├── GreeterConfig.qml      — Конфиг из /etc/greetd/ + wallpaper из state.json
│   ├── GreeterTheme.qml       — Material Design 3 тема (McuTheme)
│   ├── SessionModel.qml       — Парсинг wayland-sessions/*.desktop и xsessions/*.desktop
│   └── UserModel.qml          — Пользователи из getent passwd (UID 1000–65533)
├── components/
│   └── LoginForm.qml          — Username + password + session selector + submit
└── ui/                        — Локальный UI kit (копия src/ui/base без qs.src.* зависимостей)
    ├── Tokens.qml             — Типографика, spacing, shape, motion (fontScale=1.0)
    ├── MaterialText.qml
    ├── MaterialIcon.qml
    ├── MaterialButton.qml
    ├── IconButton.qml
    ├── CircleAvatar.qml
    └── StateLayer.qml
```

## Установка

### 1. Greetd

`/etc/greetd/config.toml`:

```toml
[terminal]
vt = 1

[default_session]
command = "start-hyprland -- -c /etc/greetd/hyprland-greeter.conf"
user = "greeter"
```

### 2. Hyprland конфигурация для greeter

`/etc/greetd/hyprland-greeter.conf`:

```conf
# Настроить мониторы под своё железо
monitor = DP-1, preferred, auto, 1

exec-once = qs -p /home/<USER>/.config/quickshell/shell/src/features/greeter; hyprctl dispatch exit

misc {
    disable_hyprland_logo = true
    disable_splash_rendering = true
    disable_hyprland_guiutils_check = true
}
```

### 3. Конфигурация greeter

`/etc/greetd/greeter.json`:

```json
{
  "primaryMonitor": "DP-1",
  "darkMode": true,
  "themeVariant": "vibrant",
  "themeColor": "#6200EE",
  "showClock": true,
  "defaultUser": "",
  "defaultSession": "Hyprland"
}
```

| Параметр         | По умолчанию | Описание                                              |
|------------------|--------------|-------------------------------------------------------|
| `primaryMonitor` | `""`         | Имя монитора для выбора обоев из state.json           |
| `darkMode`       | `true`       | Тёмная тема                                           |
| `themeVariant`   | `"vibrant"`  | Вариант Material You (vibrant, tonalspot, и т.д.)     |
| `themeColor`     | `"#6200EE"`  | Fallback цвет для генерации темы (если нет обоев)     |
| `showClock`      | `true`       | Показывать часы и дату                                |
| `defaultUser`    | `""`         | Автозаполнение имени пользователя                     |
| `defaultSession` | `""`         | Автовыбор сессии по имени (e.g. `"Hyprland"`)         |
| `wallpaperPath`  | `""`         | Ручной путь к обоям (используется если state.json нет)|

### 4. Обои из основной оболочки

Greeter подхватывает текущие обои из `state.json` основной оболочки через симлинк.

#### Создать симлинк

```bash
sudo ln -sf /home/<USER>/.config/quickshell/state.json /etc/greetd/shell-state.json
```

#### ACL: доступ для пользователя greeter

Пользователю `greeter` нужен **traverse** (`x`) по цепочке директорий до `state.json`
и **read** (`r`) на сам файл и файлы обоев. Traverse не даёт права на листинг
содержимого директории — только на прохождение сквозь неё по конкретному пути.

```bash
# Traverse до state.json
setfacl -m u:greeter:x /home/<USER>
setfacl -m u:greeter:x /home/<USER>/.config
setfacl -m u:greeter:x /home/<USER>/.config/quickshell
setfacl -m u:greeter:r /home/<USER>/.config/quickshell/state.json

# Чтение обоев
setfacl -m u:greeter:rx /home/<USER>/wallpapers
find /home/<USER>/wallpapers -type d -exec setfacl -m u:greeter:rx {} \;
find /home/<USER>/wallpapers -type f -exec setfacl -m u:greeter:r {} \;
```

#### Каскад выбора обоев

1. `shell-state.json` → `wallpaper.monitors[primaryMonitor].current`
2. `shell-state.json` → первый монитор с установленными обоями
3. `greeter.json` → `wallpaperPath` (ручной fallback)
4. Нет обоев → сплошной цвет `surfaceDim` из темы

#### Безопасность

- `greeter` получает **только read** на `state.json` и файлы обоев
- `x` на директории — traverse, **не листинг** (`ls /home/<USER>` не сработает)
- `state.json` содержит только пути к обоям и UI state, никаких секретов
- Без записи, без выполнения файлов

### 5. Проверка ACL

```bash
# Должен вернуть содержимое state.json
sudo -u greeter cat /etc/greetd/shell-state.json

# Должен вернуть файл обоев
sudo -u greeter cat /home/<USER>/wallpapers/some-wallpaper.jpg > /dev/null && echo OK

# НЕ должен работать — нет права на листинг
sudo -u greeter ls /home/<USER>  # Permission denied
```

## Greetd IPC flow

```
User enters credentials
  → Greetd.createSession(username)
  → onAuthMessage(msg, error, responseRequired, echoResponse)
    → responseRequired=true → Greetd.respond(password)
  → onReadyToLaunch()
    → Greetd.launch(session.exec.split(" "), [], true)
    → quit=true → quickshell завершается → Hyprland завершается → greetd запускает сессию
  или onAuthFailure(message)
    → shake-анимация + сообщение об ошибке + retry
```

## Тестирование

### UI без greetd (в обычной сессии)

```bash
qs -p ~/.config/quickshell/shell/src/features/greeter
```

Greetd IPC недоступен — UI отобразится, но аутентификация не сработает.
Полезно для проверки визуала, парсинга сессий и пользователей.

### Полный тест через greetd

Переключиться в TTY (Ctrl+Alt+F1), залогиниться, перезапустить greetd:

```bash
sudo systemctl restart greetd
```
