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
│   ├── GreeterConfig.qml      — Config and background from /etc/greetd/ (nothing from $HOME)
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

# Installed as a package (packaging/arch, at1ass-shell-greeter): root-owned code,
# no access to the user's home needed. This file itself ships in that package.
exec-once = qs -p /usr/share/at1ass-shell/greeter || regreet; hyprctl dispatch exit

# Running straight from a checkout instead (development):
# exec-once = qs -p /home/<USER>/.config/quickshell/shell/src/features/greeter || regreet; hyprctl dispatch exit

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
  "wallpaperPath": "/etc/greetd/wallpaper.jpg",
  "darkMode": true,
  "themeVariant": "vibrant",
  "themeColor": "#6200EE",
  "themeContrast": 0.0,
  "showClock": true,
  "defaultUser": "",
  "defaultSession": "Hyprland"
}
```

| Field            | Default     | Description                                                      |
|------------------|-------------|------------------------------------------------------------------|
| `darkMode`       | `true`      | Dark theme                                                       |
| `themeVariant`   | `"vibrant"` | Material You variant (vibrant, tonalspot, etc.)                  |
| `themeColor`     | `"#6200EE"` | Fallback seed color for theme generation (when there's no image) |
| `themeContrast`  | `0.0`       | MCU contrast. `0.0` is standard M3; `1.0` is the accessibility high-contrast level, which flips `*Container` roles light in a dark scheme |
| `showClock`      | `true`      | Show clock and date                                              |
| `defaultUser`    | `""`        | Pre-fill the username                                            |
| `defaultSession` | `""`        | Pre-select a session by name (e.g. `"Hyprland"`)                 |
| `wallpaperPath`  | `""`        | Background image, e.g. `/etc/greetd/wallpaper.jpg`; also seeds the palette. Empty → solid `surfaceDim` |

### 4. Background image

The greeter reads nothing from the user's home. Copy the image into `/etc/greetd/` by hand and point `wallpaperPath` in `greeter.json` at it; to change the background, copy a new one over it:

```bash
sudo install -Dm644 ~/wallpapers/3440x1440/some.jpg /etc/greetd/wallpaper.jpg
```

The same image seeds the Material You palette (`Mcu`). Without one, `themeColor` seeds it and the background is a solid `surfaceDim`.

Earlier versions followed the shell's current wallpaper through a `/etc/greetd/shell-state.json` symlink into `~/.config/quickshell/state.json`, plus ACLs on the wallpaper directory. That needed traverse (`x`) on the home directory for the `greeter` user — and traverse on `~` also opens every world-readable file below it, not just the ones the ACLs name. Remove the leftovers if present:

```bash
sudo rm -f /etc/greetd/shell-state.json
setfacl -R -x u:greeter ~/wallpapers
```

> The greeter **code** is still loaded from `~/.config/quickshell/shell/src/features/greeter` (step 2), so `u:greeter:x` on `~`, `~/.config` and `~/.config/quickshell` stays necessary until the greeter is installed outside the home directory.

### 5. Verifying

```bash
sudo -u greeter cat /etc/greetd/greeter.json
sudo -u greeter test -r /etc/greetd/wallpaper.jpg && echo OK
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
