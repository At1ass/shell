# Quickshell Shell

A Hyprland shell built on [Quickshell](https://quickshell.outfoxxed.me/) with a Material Design 3 look.

## Features

| Component | Description |
|-----------|-------------|
| **Status Bar** | Configurable widgets: workspaces, active window, clock, weather, media, notifications, volume, network, battery, layout, tray. Optional auto-hide. |
| **Dock** | Per-screen application dock with running-window previews and auto-hide |
| **Dashboard** | 5-tab control center: Quick, Weather, Calendar, Audio, Network. System-stat polling runs only while it is open |
| **Launcher** | Application search with fuzzy matching + calculator + clipboard history |
| **Notification Center** | History panel, per-app grouping, unread badge, DND (critical always gets through), repeat counters, per-app filters |
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
| `app2unit` | Launches apps (launcher, dock, settings buttons) into their own systemd scopes; Terminal=true entries via `xdg-terminal-exec` |

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

The config is **validated against the schema on load**, including on hot-reload. A mistyped or
misplaced key, a wrong type, a value outside its range or outside an `enum` is reported as a toast
and logged with its path and a suggestion:

```
config.json — bar.heigth: unknown key — did you mean one of: height, widgets, margin?
```

Before this, a typo was simply ignored: the accessor fell back to its default and nothing said so.

### Top-level sections

```
appearance.theme         — theme (source, variant, contrast, darkMode)
appearance.fontScale     — font scale (0.5–2.0)
appearance.reduceMotion  — disable all shell animations (accessibility)
appearance.motionScale   — multiplier on every motion duration (1.0 = Material defaults)
performance.keepPanelsLoaded — panels kept alive after their first open instead of being
                           rebuilt on every open (see below)
modules                  — on/off switch for every top-level shell element (see below)
bar                      — status bar and widgets
bar.transparent          — transparent bar background
bar.autoHide             — reveal the bar only at the top screen edge (no reserved space)
dock                     — application dock (position, auto-hide, icon size, pinned apps)
dashboard                — control-center dimensions
notifications            — popups and notification center
notifications.dnd        — Do Not Disturb policy (fullscreen suppression)
notifications.rateLimit  — burst protection (ingress budget + popup pacing)
notifications.filters    — per-app noPopup / noHistory lists
launcher                 — search behaviour, hidden apps
osd                      — volume / brightness overlays
lockscreen               — built-in lock screen
powerMenu                — power menu
gamingMode               — gaming mode (Hyprland overrides)
wallpaper                — wallpaper sources and per-monitor bindings
services.weather         — weather (Open-Meteo, no API key)
services.calendar        — calendar (native libical plugin), reminders (timed + all-day), day view
services.nightLight      — hyprsunset wrapper (default temperature, schedule)
services.vpn             — VPN status (NetworkManager); tracking is OFF by default,
                           set services.vpn.enabled to start it
```

### Colour scheme contrast

`appearance.theme.contrast` is a Material contrast level, not a brightness dial.
`0.0` (default) is standard M3. Positive values are the accessibility
high-contrast variants, and in a **dark** scheme they invert container polarity —
every `*Container` role becomes light and its `on*` colour black:

| role | `contrast: 0.0` | `contrast: 0.5` |
|---|---|---|
| `errorContainer` | `#93000A` | `#FF5449` |
| `onErrorContainer` | `#FFDAD6` | `#000000` |
| `primaryContainer` | `#4D3D75` | `#9887C5` |

Raise it only if you actually want that. `appearance.theme.variant` accepts
`tonalspot`, `vibrant`, `expressive`, `content`, `fidelity`, `neutral` and
`monochrome` — all seven are implemented.

### Multi-monitor behaviour

Per-screen elements (bar, dock, wallpaper, OSD, toasts, screenshot overlay) are
instantiated once per output. The single-window overlays — dashboard, launcher,
power menu, cheatsheet, notification centre — open on the **focused** monitor,
resolved at open time, and stay there while they are up.

Notification popups are configurable via `notifications.popup.monitor`:

```jsonc
"popup": { "monitor": "focused" }   // default
"popup": { "monitor": "DP-2" }      // pin to one output
```

With `"focused"`, a popup opens on the focused monitor — but only when the stack
is empty. Popups never migrate once mapped, so if each card picked its own
monitor a burst that spanned a focus change would split one logical stack across
two screens, both columns starting at the top margin, while `maxVisible` counted
them globally and evicted from the screen you were not looking at. Keeping an
existing stack on its output avoids that; pin the output if you want popups in a
fixed place regardless of focus. An output name that is not currently connected
falls back to the focused monitor rather than dropping the notification.

### Modules (turning elements on or off)

### `performance.keepPanelsLoaded`

Every panel is built when it opens and torn down when it closes, so the second
open costs as much as the first. That construction runs on the UI thread and
blocks it for its whole duration — measured on a 9950X3D at 13 ms for the
launcher and 32 ms for the cheatsheet, which is two to five dropped frames at
144 Hz, and it scales with the machine rather than the GPU.

Listing a panel here keeps its tree alive after the first open:

```json
"performance": {
  "keepPanelsLoaded": ["launcher", "dashboard", "notificationCenter", "cheatsheet"]
}
```

That is the default. Measured effect: launcher 13 → 7 ms, dashboard 12 → 7 ms,
cheatsheet 32 → 12 ms of UI thread per open. Memory is not the trade one would
expect — twelve open/close cycles grew RSS by 27 MB with retention on and
186 MB with it off, because a rebuilt panel does not hand its allocations back.

Valid entries: `dashboard`, `launcher`, `notificationCenter`, `cheatsheet`,
`powermenu`. An empty list restores rebuild-on-every-open. `powermenu` is out
of the default because it is small and rarely opened; the lock screen is not
eligible at all, since its window owns a Wayland session lock.

### `modules.polkit`

An in-shell polkit prompt, so a privilege request looks like the rest of the
shell instead of a separate toolkit's dialog. **Off by default**, and that is a
deliberate default rather than a shy one: polkit allows exactly one
authentication agent per session, Hyprland setups normally start
`hyprpolkitagent`, and whichever registers second simply logs an error and does
nothing.

To use the shell's:

```bash
systemctl --user disable --now hyprpolkitagent
```

```json
"modules": { "polkit": true }
```

With the module off nothing in `PolkitService` is constructed and no agent is
registered, so the external agent keeps working untouched. Check which one won
with `tools/shell-ctl polkit registered`.

> **Any prompt that does not end in success costs a login attempt.** `/usr/lib/pam.d/polkit-1`
> includes `system-auth`, so polkit authentication runs through `pam_faillock`
> — and a conversation that ends without success is recorded exactly like a
> wrong password. That covers cancelling it, switching administrator, and
> simply walking away: an unanswered prompt expires after a few seconds and is
> counted too. With the stock `deny=3` / `unlock_time=600`, three dismissed
> prompts lock the account for ten minutes, for **every** PAM service including
> `sudo` and the lock screen. This is the system's PAM configuration, not the
> shell's, and it applies to any agent (hyprpolkitagent included).
>
> The prompt is therefore deliberately hard to dismiss by accident: only the
> Cancel button and Escape close it — clicking outside does not.
>
> **Switching administrator in the selector costs an attempt too.** Choosing a
> different identity cancels the running PAM conversation and starts a new one
> as that user, and the cancelled half is recorded the same way. The selector
> only appears for `auth_admin` actions on machines with more than one
> administrator.
>
> If you dismiss prompts often, give polkit its own stack in
> `/etc/pam.d/polkit-1` without `pam_faillock`, or raise `deny` in
> `/etc/security/faillock.conf`. `faillock --user "$USER"` shows the current
> count and `sudo faillock --user "$USER" --reset` clears it.

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

### What survives a restart

`state.json` also holds the user-owned toggles, so they are restored on the next start and across a QML reload:
`idleInhibitor.enabled` (caffeine), `nightLight.enabled`, `notifications.doNotDisturb`, `gamingMode.active`,
and the per-monitor wallpaper selection. Toggles backed by the system rather than the shell — WiFi, Bluetooth,
VPN — are not stored here; they are read back from NetworkManager and bluetoothd.

---

## IPC commands

Drive the shell from outside. `tools/shell-ctl` is the front door — it discovers
the handler list from the running shell, so its help and its tab completion can
never drift from what the shell actually exposes:

```bash
tools/shell-ctl help                 # the live IPC surface, plus the shortcuts
tools/shell-ctl status               # instance, config paths, schema validation
tools/shell-ctl config validate      # check config.json without restarting
tools/shell-ctl launcher             # shortcuts over the same calls
tools/shell-ctl caffeine on
tools/shell-ctl notifications count  # any handler/function, straight through

tools/shell-ctl completion > ~/.zsh/completions/_shell-ctl
```

Symlink it onto `PATH` (`ln -s ~/.config/quickshell/shell/tools/shell-ctl ~/.local/bin/`)
if you want it without the path prefix.

The raw form works too, and is what the shortcuts call:

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
qs ipc call globalstates locked               # bool — is the lock screen up?
                                              # loginctl's LockedHint does NOT answer this:
                                              # hypridle calls lockScreen() over IPC directly,
                                              # never through `loginctl lock-session`.

# Gaming mode
qs ipc call globalstates toggleGamingMode
qs ipc call globalstates enableGamingMode
qs ipc call globalstates disableGamingMode

# Night light
qs ipc call globalstates toggleNightLight
qs ipc call globalstates setNightLightTemperature 4500
qs ipc call globalstates nightLight           # bool — is it on?

# Caffeine (idle inhibitor)
qs ipc call globalstates toggleIdleInhibitor  # returns the new state
qs ipc call globalstates setIdleInhibitor true
qs ipc call globalstates idleInhibitor        # bool — is it on?

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

### `notifications`

```bash
qs ipc call notifications toggleDnd       # returns the new DND state
qs ipc call notifications setDnd true
qs ipc call notifications isDnd           # manual toggle only
qs ipc call notifications dndActive       # toggle OR fullscreen suppression
qs ipc call notifications dismissAll      # close every visible popup
qs ipc call notifications clear           # wipe history
qs ipc call notifications markAllRead     # clear the unread badge
qs ipc call notifications count           # history entries
qs ipc call notifications unread          # unread entries (what the bar badge shows)
qs ipc call notifications activeCount     # popups currently on screen
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

### Using the UI kit

`src/ui` is the single point for anything visual. A feature reaching past it
needs a reason, and the reason belongs in a comment — the three recorded ones
today are `ToastOverlay` (severity colour + its own per-screen surface), the
dashboard tab bar (MD3 Tabs, which the kit does not have) and the cheatsheet
keycaps (a static token, not a Chip).

Two conventions worth knowing:

- **Motion goes through `MotionAnimation` / `MotionColorAnimation`.** `curve:`
  sets both halves of the easing at once. Hand-writing `easing.type` plus
  `easing.bezierCurve` is what let a broken curve reach 100+ sites, and
  `easing-pairs-by-hand` now holds it at zero.
- **Colour goes through a role where one exists** — `colorRole: "onSurface"`
  rather than `Theme.onSurface`. `MaterialText`, `MonoText`, `MaterialIcon`,
  `IconButton` and `MaterialIndicator` take roles; raw colour properties remain
  as escape hatches for genuinely computed values.

Before pushing, run `tools/check.sh` (mechanical invariants, ratcheted against
`tools/check-baseline.txt`) and `tools/lint.sh <files>` (qmllint with the right
import paths). Two invariants worth knowing about, because both cover mistakes
that look correct on the page:

- `easing-points-arity` — `easing.bezierCurve` needs groups of **three** points
  (6 reals, last = `1.0, 1.0`). A 4-value CSS-style curve is dropped by Qt
  *without a warning* and the animation runs linear.
- `greeter-ui-drift` — `src/features/greeter/ui/*` is generated. Edit
  `src/ui/`, then re-run `src/features/greeter/sync-ui.sh`.

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
