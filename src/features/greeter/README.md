# Quickshell Greeter

A greetd greeter — login screen with a Material Design 3 UI. A standalone Quickshell configuration that runs independently of the main shell.

## How it works

greetd starts Hyprland as the `greeter` user, Hyprland launches `qs -p .../greeter`, the greeter shows the login form and talks to greetd through `Quickshell.Services.Greetd` IPC. On successful authentication it launches the selected session and exits.

At the bottom of the screen there are power buttons (shutdown, reboot, suspend) wired to `systemctl`, available without authentication.

## File layout

```
greeter/
├── shell.qml                  — Entry point: fullscreen PanelWindow per monitor
├── GreeterSurface.qml         — Wallpaper + blur + scrim + clock + form + Greetd IPC
├── config/
│   ├── GreeterConfig.qml      — Config from /etc/greetd/ + wallpaper from state.json
│   ├── GreeterTheme.qml       — Material Design 3 theme (McuTheme)
│   ├── SessionModel.qml       — Parses wayland-sessions/*.desktop and xsessions/*.desktop
│   └── UserModel.qml          — Users from getent passwd (UID 1000–65533)
├── components/
│   └── LoginForm.qml          — Username + password + session selector + submit
└── ui/                        — UI kit, GENERATED from src/ui via sync-ui.sh
    ├── Tokens.qml             — from src/core/config/Tokens.qml (fontScale=1.3, no AppConfig)
    ├── MaterialText.qml       — \
    ├── MaterialIcon.qml       —  |
    ├── MaterialButton.qml     —  } from src/ui/base/* and src/ui/feedback/StateLayer.qml
    ├── IconButton.qml         —  |  (Theme→GreeterTheme, qs.src.core.config→qs.config)
    ├── CircleAvatar.qml       — /
    └── StateLayer.qml
```

### Regenerating the UI kit (`sync-ui.sh`)

`ui/` contains **generated files; do not edit by hand**. The single source of truth is the main UI kit in `src/ui`. After changes to `src/ui`, sync the greeter:

```bash
src/features/greeter/sync-ui.sh
```

The script copies components from `src/ui/base` + `src/ui/feedback/StateLayer.qml` and `src/core/config/Tokens.qml`, applying mechanical rewrites (`Theme`→`GreeterTheme`, imports, `AppConfig.fontScale`→literal). This keeps the greeter from drifting from the main shell. The greeter is a separate process (greetd, before login), so its theme (`GreeterTheme`) and `Tokens` must differ from the main shell in their data source — but the component bodies are identical.

## Installation

### 1. greetd

`/etc/greetd/config.toml`:

```toml
[terminal]
vt = 1

[default_session]
command = "start-hyprland -- -c /etc/greetd/hyprland-greeter.conf"
user = "greeter"
```

### 2. Hyprland config for the greeter

`/etc/greetd/hyprland-greeter.conf`:

```conf
# Adapt monitors to your hardware
monitor = DP-1, preferred, auto, 1

exec-once = qs -p /home/<USER>/.config/quickshell/shell/src/features/greeter; hyprctl dispatch exit

misc {
    disable_hyprland_logo = true
    disable_splash_rendering = true
    disable_hyprland_guiutils_check = true
}
```

### 3. Greeter configuration

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

| Field            | Default     | Description                                                      |
|------------------|-------------|------------------------------------------------------------------|
| `primaryMonitor` | `""`        | Monitor name used to pick a wallpaper from state.json            |
| `darkMode`       | `true`      | Dark theme                                                       |
| `themeVariant`   | `"vibrant"` | Material You variant (vibrant, tonalspot, etc.)                  |
| `themeColor`     | `"#6200EE"` | Fallback seed color for theme generation (when there's no image) |
| `showClock`      | `true`      | Show clock and date                                              |
| `defaultUser`    | `""`        | Pre-fill the username                                            |
| `defaultSession` | `""`        | Pre-select a session by name (e.g. `"Hyprland"`)                 |
| `wallpaperPath`  | `""`        | Manual wallpaper path (used when state.json is unavailable)      |

### 4. Wallpaper from the main shell

The greeter picks up the current wallpaper from the main shell's `state.json` via a symlink.

#### Create the symlink

```bash
sudo ln -sf /home/<USER>/.config/quickshell/state.json /etc/greetd/shell-state.json
```

#### ACL: access for the greeter user

The `greeter` user needs **traverse** (`x`) along the directory chain down to `state.json` and **read** (`r`) on the file itself and on the wallpaper files. Traverse does not grant listing — only the ability to step through to a known path.

```bash
# Traverse to state.json
setfacl -m u:greeter:x /home/<USER>
setfacl -m u:greeter:x /home/<USER>/.config
setfacl -m u:greeter:x /home/<USER>/.config/quickshell
setfacl -m u:greeter:r /home/<USER>/.config/quickshell/state.json

# Read wallpapers
setfacl -m u:greeter:rx /home/<USER>/wallpapers
find /home/<USER>/wallpapers -type d -exec setfacl -m u:greeter:rx {} \;
find /home/<USER>/wallpapers -type f -exec setfacl -m u:greeter:r {} \;
```

#### Wallpaper selection cascade

1. `shell-state.json` → `wallpaper.monitors[primaryMonitor].current`
2. `shell-state.json` → first monitor with a wallpaper set
3. `greeter.json` → `wallpaperPath` (manual fallback)
4. None of the above → solid `surfaceDim` color from the theme

#### Security

- `greeter` only gets **read** on `state.json` and on the wallpaper files
- `x` on directories is traverse, **not list** (`ls /home/<USER>` will fail)
- `state.json` contains only wallpaper paths and UI state — no secrets
- No write, no execute

### 5. Verifying ACLs

```bash
# Should return the contents of state.json
sudo -u greeter cat /etc/greetd/shell-state.json

# Should return a wallpaper file
sudo -u greeter cat /home/<USER>/wallpapers/some-wallpaper.jpg > /dev/null && echo OK

# Should NOT work — no list permission
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
    → quit=true → quickshell exits → Hyprland exits → greetd launches the session
  or onAuthFailure(message)
    → shake animation + error message + retry
```

## Testing

### UI without greetd (in a normal session)

```bash
qs -p ~/.config/quickshell/shell/src/features/greeter
```

Greetd IPC is unavailable — the UI renders but authentication will not work. Handy for visual checks, session and user parsing.

### Full test through greetd

Switch to a TTY (Ctrl+Alt+F1), log in, restart greetd:

```bash
sudo systemctl restart greetd
```
