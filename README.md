# Quickshell Shell

A Hyprland shell built on [Quickshell](https://quickshell.outfoxxed.me/) with a Material Design 3 look.

## Features

| Component | Description |
|-----------|-------------|
| **Status Bar** | Configurable widgets: workspaces, active window, clock, weather, media, notifications, volume, network, battery, layout, tray. Optional auto-hide. |
| **Dock** | Per-screen application dock with running-window previews and auto-hide |
| **Dashboard** | 5-tab control center: Quick, Weather, Calendar, Audio, Network |
| **Launcher** | Application search with fuzzy matching + calculator + clipboard history |
| **Notification Center** | History panel, per-app grouping, DND |
| **OSD** | Volume and brightness overlays |
| **Toast** | Info / success / warning / error popups |
| **Screenshot** | Region selection via mouse or keyboard (hjkl), annotations through swappy |
| **Gaming Mode** | Auto-disables Hyprland animations / blur / shadows; restores them on exit |
| **Wallpaper** | Multi-monitor wallpapers with pluggable sources (local, Wallhaven) and auto-rotation |
| **Night Light** | hyprsunset wrapper with on/off and temperature IPC |
| **Power Menu** | Lock / Suspend / Reboot / Shutdown / Logout |
| **Lockscreen** | Built-in lock surface via `WlSessionLock` (optional; pair with external locker if disabled) |
| **Cheatsheet** | Interactive reference of Hyprland + shell keybindings and IPC commands |
| **Greeter** | Optional greetd greeter — separate Quickshell config (see `src/features/greeter/README.md`) |

---

## Dependencies

### Required

| Package | Purpose |
|---------|---------|
| `quickshell-git` | Shell framework (Wayland, QML) |
| `hyprland` | Compositor (uses ext-global-shortcuts, WlrLayershell, HyprlandFocusGrab) |
| `qt6-base`, `qt6-declarative` | Qt6 runtime |
| `pipewire` + `wireplumber` | Audio — volume widget and OSD |

### Optional

| Package | Purpose |
|---------|---------|
| `grim` | Screenshots (required for the Screenshot overlay) |
| `wl-clipboard` | Copy screenshots to the clipboard (`wl-copy`) |
| `swappy` | Screenshot annotations |
| `ddcutil` | External-monitor brightness via DDC/CI |
| `cliphist` | Clipboard history in the launcher |
| `qalculate-glib` | Calculator in the launcher (also a build dep for the plugin) |
| `libical` | Native calendar plugin (events, RRULE expansion) |
| `vdirsyncer` | CalDAV synchronization (Google, Yandex, iCloud, …) |
| `libnotify` | Calendar event reminders (`notify-send`) |
| `hyprsunset` | Night Light temperature shift |
| `networkmanager` | Network widget and VPN status (event-driven via `nmcli monitor`) |
| `bluez` | Bluetooth status in the Dashboard |

> Bluetooth pairing note: the shell intentionally runs **no** background pairing
> agent (an always-on auto-confirm agent would accept any nearby pairing
> request). Simple devices pair directly; devices that require passkey
> confirmation need an interactive agent such as `blueman`.

### Build dependencies (C++ plugins)

| Package | Purpose |
|---------|---------|
| `cmake` + `ninja` | Build system |
| `qt6-tools` | `moc`, `rcc` |
| `qalculate-glib` | Calculator plugin headers |
| `libical` | Calendar plugin (requires libical ≥ 4.0 — refcounted recurrence API) |

---

## Installation

### 1. Clone

```bash
git clone <repo> ~/.config/quickshell/shell
```

### 2. Build C++ plugins

```bash
cd ~/.config/quickshell/shell/src/plugins
cmake -B build -S . -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/
cmake --build build
```

Plugins built: Material Color Utilities (dynamic colors), FuzzySearch (search), Qalculate (calculator), Calendar (iCalendar via libical), SystemMonitor (system monitoring).

### 3. Create a user config

```bash
cp ~/.config/quickshell/shell/config/default.json \
   ~/.config/quickshell/config.json
```

Config is read from `$XDG_CONFIG_HOME/quickshell/config.json` (defaults to `~/.config/quickshell/config.json`). If absent, the bundled `config/default.json` is loaded as a fallback.

### 4. Configure

At minimum, set your weather coordinates and city name:

```json
"services": {
  "weather": {
    "location": "London",
    "latitude": 51.5,
    "longitude": -0.12
  }
}
```

### 5. Add keybinds to `hyprland.conf`

Hotkeys are registered as `GlobalShortcut`s and bound on the Hyprland side:

```conf
# Panels
bind = SUPER, SPACE,  global, quickshell:launcherToggle
bind = SUPER, Escape, global, quickshell:powerMenuToggle
bind = SUPER, F1,     global, quickshell:cheatsheetToggle

# Screenshots
bind = SUPER,       Print, global, quickshell:screenshot
bind = SUPER SHIFT, Print, global, quickshell:screenshotSwappy

# Audio
bind = , XF86AudioRaiseVolume, global, quickshell:audioVolumeUp
bind = , XF86AudioLowerVolume, global, quickshell:audioVolumeDown
bind = , XF86AudioMute,        global, quickshell:audioToggleMute

# Brightness (DDC/CI external monitors + backlight)
bind = , XF86MonBrightnessUp,   global, quickshell:brightnessUp
bind = , XF86MonBrightnessDown, global, quickshell:brightnessDown

# Gaming mode and night light
bind = SUPER ALT, G, global, quickshell:gamingModeToggle
bind = SUPER ALT, N, global, quickshell:nightLightToggle
```

### 6. Run

```bash
quickshell -p ~/.config/quickshell/shell
```

Or add it to Hyprland's autostart:

```conf
exec-once = quickshell -p ~/.config/quickshell/shell
```

---

## Configuration

File: `~/.config/quickshell/config.json`

**Hot-reload**: the config file is watched — changes apply without a restart.

Full field documentation: [`config/config.schema.json`](config/config.schema.json)

Reference config with defaults: [`config/default.json`](config/default.json)

### Top-level sections

```
appearance.theme         — theme (source, variant, darkMode)
appearance.fontScale     — font scale (0.5–2.0)
modules                  — on/off switch for every top-level shell element (see below)
bar                      — status bar and widgets
bar.transparent          — transparent bar background
bar.autoHide             — reveal the bar only at the top screen edge (no reserved space)
dock                     — application dock (position, auto-hide, icon size, pinned apps)
dashboard                — control-center dimensions
notifications            — popups and notification center
launcher                 — search behaviour, hidden apps
osd                      — volume / brightness overlays
lockscreen               — built-in lock screen
powerMenu                — power menu
gamingMode               — gaming mode (Hyprland overrides)
wallpaper                — wallpaper sources and per-monitor bindings
services.weather         — weather (Open-Meteo, no API key)
services.calendar        — calendar (native libical plugin), reminders, upcoming, day view
services.nightLight      — hyprsunset wrapper (default temperature, schedule)
services.vpn             — VPN status (NetworkManager)
```

### Modules (turning elements on or off)

The `modules` block is the central switch for every top-level shell element. Any element can be turned off by setting it to `false`. An absent key falls back to its default. Changes apply on the fly (hot-reload), no restart required.

```json
"modules": {
  "bar": true,           // status bar (per monitor)
  "dock": false,         // application dock (per monitor)
  "wallpaper": true,     // wallpaper layer; when false the compositor background shows through
  "dashboard": true,     // control center
  "launcher": true,      // application launcher
  "notifications": true, // notification center AND popups
  "osd": true,           // volume and brightness OSDs
  "lockscreen": false,   // built-in lock screen
  "powerMenu": true,     // power menu
  "cheatsheet": true,    // keybinding cheatsheet overlay
  "screenshot": true,    // region-selection overlay + screenshot hotkeys / IPC
  "toasts": true,        // toast notifications (ToastService)
  "popouts": true        // popout host (tray menus, etc.)
}
```

When a module is off, the corresponding element is never instantiated and its hotkeys / IPC / click-actions become no-ops.

**Things to know:**

- `lockscreen: false` — lock requests (power menu, `loginctl` / DBus `lock-session`) become no-ops. The screen is **not** locked — pair this with an external locker (e.g. hyprlock via hypridle).
- `popouts: false` — tray right-click menus and other popouts will not appear.
- `toasts: false` — `ToastService` errors/successes are silently dropped (visible only in the console log).
- `notifications: false` disables both the center and popups. The bar's bell widget is toggled separately via its own `enabled` flag in `bar.widgets` (the counter keeps updating because the underlying service still runs).

### Bar widgets

Every widget in `bar.widgets` shares these fields:

| Field | Description |
|-------|-------------|
| `type` | Widget type (see table below) |
| `enabled` | Enabled or not |
| `section` | `"left"` / `"center"` / `"right"` |
| `monitors` | `"all"`, a monitor name (`"DP-2"`), or an array |
| `clickAction` | Action triggered on click (see below) |
| `settings` | Widget-specific parameters |

Available widget types:

| Type | Description |
|------|-------------|
| `workspaces` | Hyprland workspaces with window indicators |
| `activewindow` | Active window title and icon |
| `weather` | Current weather |
| `clock` | Date / time (configurable format) |
| `media` | Current MPRIS track |
| `notifications` | Bell with badge |
| `volume` | Volume (scroll to change) |
| `network` | Wi-Fi / Ethernet status |
| `battery` | Battery level |
| `layout` | Current keyboard layout |
| `tray` | System tray |

Available `clickAction` values:

| Value | Action |
|-------|--------|
| `dashboard-quick` | Open Dashboard on the Quick tab |
| `dashboard-weather` | Open Dashboard on the Weather tab |
| `dashboard-calendar` | Open Dashboard on the Calendar tab |
| `dashboard-audio` | Open Dashboard on the Audio tab |
| `dashboard-network` | Open Dashboard on the Network tab |
| `notification-center` | Toggle the notification center |
| `launcher` | Open the launcher |

---

### Dock

Per-screen application dock showing pinned + running apps, with live window previews.

Config (`dock` section):

| Key | Default | Description |
|-----|---------|-------------|
| `position` | `bottom` | Screen edge: `bottom` / `top` (horizontal row) or `left` / `right` (vertical column). |
| `autoHide` | `true` | Hide until the cursor reaches the dock's screen edge. |
| `exclusive` | `false` | Reserve screen space (exclusive zone) for the dock. |
| `iconSize` | `48` | App icon size in logical pixels. |
| `pinnedApps` | `[]` | Pinned apps (desktop id / window class / name). Editing this list wins; runtime pin/unpin persists to `state.json` (see schema). |

Interactions:

| Action | Result |
|--------|--------|
| Left-click | Launch (if not running), focus, or cycle the app's windows |
| Middle-click | Open a new window |
| Right-click | Context menu — New window, Pin / Unpin, Close |
| Hover (running) | Live window previews — click a thumbnail to focus, `×` to close that window |
| Drag a pinned icon | Reorder pinned apps |

Runtime pin order lives in `~/.config/quickshell/state.json` (`dock.pinnedApps`); the shell never writes back to `config.json`.

---

## IPC commands

Drive the shell from outside:

```bash
qs ipc call <handler> <function> [argument]
```

### `globalstates`

```bash
# Dashboard
qs ipc call globalstates toggleDashboard
qs ipc call globalstates openDashboardTab 0   # 0=Quick 1=Weather 2=Calendar 3=Audio 4=Network

# Launcher
qs ipc call globalstates toggleLauncher
qs ipc call globalstates openLauncher
qs ipc call globalstates closeLauncher

# Notification center
qs ipc call globalstates toggleNotificationCenter
qs ipc call globalstates openNotificationCenter
qs ipc call globalstates closeNotificationCenter

# Screenshots
qs ipc call globalstates screenshot          # region → clipboard
qs ipc call globalstates screenshotSwappy    # region → swappy

# Power
qs ipc call globalstates togglePowerMenu
qs ipc call globalstates openPowerMenu
qs ipc call globalstates closePowerMenu
qs ipc call globalstates lockScreen

# Gaming mode
qs ipc call globalstates toggleGamingMode
qs ipc call globalstates enableGamingMode
qs ipc call globalstates disableGamingMode

# Night light
qs ipc call globalstates toggleNightLight
qs ipc call globalstates setNightLightTemperature 4500

# Cheatsheet
qs ipc call globalstates toggleCheatsheet
qs ipc call globalstates openCheatsheet
qs ipc call globalstates closeCheatsheet

# Misc
qs ipc call globalstates closeAll
```

### `audio`

```bash
qs ipc call audio volumeUp
qs ipc call audio volumeDown
qs ipc call audio setVolume 0.5       # 0.0 – 1.0
qs ipc call audio toggleMute
qs ipc call audio getMasterVolume     # returns current volume
qs ipc call audio isMuted
```

### `mpris`

```bash
# Playback
qs ipc call mpris play
qs ipc call mpris pause
qs ipc call mpris stop
qs ipc call mpris togglePlaying
qs ipc call mpris next
qs ipc call mpris previous
qs ipc call mpris seek 10             # offset in seconds
qs ipc call mpris setPosition 30      # jump to position (seconds)

# Player volume
qs ipc call mpris setVolume 0.8
qs ipc call mpris volumeUp
qs ipc call mpris volumeDown
qs ipc call mpris getVolume

# Modes
qs ipc call mpris toggleShuffle
qs ipc call mpris toggleLoop

# Info
qs ipc call mpris getCurrentTrack
qs ipc call mpris isPlaying
qs ipc call mpris getPosition         # current position (seconds)
qs ipc call mpris getLength           # track length (seconds)

# Player control
qs ipc call mpris raise               # raise the player window
qs ipc call mpris quit                # quit the player
```

### `wallpaper`

```bash
# Set wallpaper
qs ipc call wallpaper set DP-1 /path/to/image.jpg
qs ipc call wallpaper setAll /path/to/image.jpg

# Navigation
qs ipc call wallpaper next                  # next wallpaper on every monitor
qs ipc call wallpaper next DP-1             # next wallpaper on a specific monitor
qs ipc call wallpaper previous

# Sources (per-monitor binding to a source id from the sources[] block)
qs ipc call wallpaper setSource DP-1 wallhaven-anime
qs ipc call wallpaper loadMore wallhaven-anime      # next page (Wallhaven only)
qs ipc call wallpaper refreshSource wallhaven-anime # re-run the query

# Fill mode (Qt Image.FillMode int)
qs ipc call wallpaper setFillMode DP-1 2            # 2 = PreserveAspectCrop
qs ipc call wallpaper setFillModeAll 2

# Auto-change
qs ipc call wallpaper setAutoChange DP-1 true 300000  # monitor, enabled, intervalMs

# Status
qs ipc call wallpaper status                # current state of every monitor (text)
```

### `wallpaper-cache` (debug)

```bash
qs ipc call wallpaper-cache status          # cache base dir, file count, queue depth
qs ipc call wallpaper-cache test <url>      # queue a test download
qs ipc call wallpaper-cache evict           # force LRU eviction pass
```

---

## Keyboard-driven screenshot overlay

While the region-selection overlay is open:

| Key | Action |
|-----|--------|
| `h` / `←` | Cursor left |
| `j` / `↓` | Cursor down |
| `k` / `↑` | Cursor up |
| `l` / `→` | Cursor right |
| `Shift` + movement | Large step (40px) |
| Hold a movement key | Accelerated movement (16px/step) |
| `Space` | Drop the anchor (first press) / take the screenshot (second press) |
| `Enter` | Take the screenshot of the selected region |
| Right-click / `Esc` | Cancel |

Navigation is layout-independent.

---

## Project layout

```
shell/
├── shell.qml                    # Entry point
├── config/
│   ├── default.json             # Reference config / fallback
│   └── config.schema.json       # JSON Schema describing every field
├── src/
│   ├── core/
│   │   ├── config/
│   │   │   ├── AppConfig.qml    # Central config singleton
│   │   │   └── Tokens.qml       # Design tokens (sizes, shape, state-layer opacities)
│   │   └── services/            # All services (audio, network, weather, …)
│   ├── features/
│   │   ├── statusbar/           # Status bar and widgets
│   │   ├── dock/                # Application dock with window previews
│   │   ├── dashboard/           # 5-tab control center
│   │   ├── launcher/            # Application search
│   │   ├── notifications/       # Notification center and popups
│   │   ├── osd/                 # VolumeOSD, BrightnessOSD, ToastOverlay
│   │   ├── screenshot/          # Region-selection overlay
│   │   ├── cheatsheet/          # Keybinding reference
│   │   ├── lockscreen/          # Lock screen
│   │   ├── powermenu/           # Power menu
│   │   ├── popouts/             # Popout host (tray menus, context panels)
│   │   ├── greeter/             # Standalone greetd greeter (separate Quickshell config)
│   │   └── background/          # Wallpaper layer
│   ├── plugins/
│   │   └── src/                 # C++ plugins (require building)
│   │       ├── mcu-qml/         # Material Color Utilities
│   │       ├── fuzzy-search-qml/# Fuzzy matching
│   │       ├── qalculate-qml/   # Calculator
│   │       ├── calendar-qml/    # iCalendar via libical (events, RRULE, reminders)
│   │       └── system-monitor-qml/ # CPU / RAM / GPU / disk / network monitoring
│   └── ui/                      # Reusable MD3 components
└── AGENTS.md, CLAUDE.md         # Project conventions and hard rules (read before contributing)
```

## Contributing / conventions

Architecture, coding conventions, hard prohibitions and the project's vectors
(correctness · performance · safety · MD3) are documented in
[`AGENTS.md`](AGENTS.md) (full handbook) and [`CLAUDE.md`](CLAUDE.md) (quick reference).
Authoritative references: this README, [`ROADMAP.md`](ROADMAP.md) (open work),
and [`config/config.schema.json`](config/config.schema.json) (configuration).

---

## Persistent state

State preserved across restarts (`~/.config/quickshell/state.json`):

- **Gaming Mode** — active or not, plus saved Hyprland settings for restoration
- **Wallpaper** — current wallpaper per monitor and per-source pagination state

---

## Shell hotkeys

Full list of shortcuts for `hyprland.conf` (`bind = ..., global, quickshell:<name>`):

| Shortcut | Action |
|----------|--------|
| `launcherToggle` | Toggle the launcher |
| `closeAllPanels` | Close every open panel |
| `screenshot` | Region select → screenshot to clipboard |
| `screenshotSwappy` | Region select → open in swappy |
| `powerMenuToggle` | Toggle the power menu |
| `cheatsheetToggle` | Toggle the cheatsheet |
| `gamingModeToggle` | Toggle gaming mode |
| `nightLightToggle` | Toggle night light |
| `audioVolumeUp` | Volume +5% |
| `audioVolumeDown` | Volume −5% |
| `audioToggleMute` | Mute / unmute |
| `brightnessUp` | Brightness +5% (DDC/CI + backlight) |
| `brightnessDown` | Brightness −5% (DDC/CI + backlight) |
