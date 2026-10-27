# Quickshell Shell

A Hyprland shell built on [Quickshell](https://quickshell.outfoxxed.me/) with a Material Design 3 look.

## Features

| Component | Description |
|-----------|-------------|
| **Status Bar** | Configurable widgets: workspaces, active window, clock, weather, media, notifications, volume, network, battery, layout, tray. Optional auto-hide. |
| **Dock** | Per-screen application dock with running-window previews and auto-hide |
| **Audio** | Compact output/microphone controls, live device selection and a lazy application mixer |
| **Connections** | Standalone Wi-Fi/Bluetooth/VPN/Ethernet panel, expandable sections, contextual actions and external profile editors |
| **Dashboard** | 3-tab overview: Quick, Weather, Calendar. System history continues while it is closed |
| **Launcher** | Application search, calculator, clipboard history and shell actions |
| **Notification Center** | History panel, per-app grouping, remembered expansion during the session, keyboard navigation through visible cards and collapsed group headers, unread badge, DND, repeat counters, per-app filters |
| **OSD** | One compact volume/brightness meter on the focused output |
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
| `qt6-base`, `qt6-declarative` | Qt 6.8+ runtime |
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
| `glib2` | Desktop entry and command-line parsing for GreeterData |
| `libical` | Native calendar plugin (events, RRULE expansion) |
| `vdirsyncer` | CalDAV synchronization (Google, Yandex, iCloud, …) |
| `hyprsunset` | Night Light temperature shift |
| `networkmanager` | Native device/profile status; UUID-based VPN activation through `nmcli` |
| `bluez` | Bluetooth support for the Connections panel |
| `libsecret` + a Secret Service provider | NetworkManager agent-owned credentials (compatible with nm-applet keyring entries) |
| `networkmanager-openvpn` | OpenVPN authentication helper, when OpenVPN profiles are used |

> Bluetooth pairing from Connections uses the shell's application-scoped BlueZ
> agent: PIN/passkey input, keyboard code display and explicit confirmation.
> It never becomes the default agent and rejects unsolicited requests.
> NetworkManager authentication uses a separate native agent; its package must be
> rebuilt before migrating away from nm-applet (see Connections below).

### Build dependencies (C++ plugins)

| Package | Purpose |
|---------|---------|
| `cmake` + `ninja` | Build system |
| `qt6-tools` | `moc`, `rcc` |
| `libqalculate` | Calculator plugin headers |
| `libical` | Calendar plugin (requires libical ≥ 4.0 — refcounted recurrence API) |
| `libsecret` | Connectivity password-store backend |
| `lm_sensors` | Optional: hwmon temperatures in SystemMonitor (built without them if absent) |

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

Plugins built: Material Color Utilities (dynamic colors), FuzzySearch (search), Qalculate (calculator), Calendar (iCalendar via libical), SystemMonitor (system monitoring), GreeterData (background session/user catalogs and parsed session argv), Connectivity (BlueZ pairing transport and NetworkManager credential agent).

#### Arch Linux: as a package

`packaging/arch/PKGBUILD` builds two packages from the **committed** state of the repo (the checked-out branch, never the working tree):

- `at1ass-shell-plugins` — the plugins above, into `/usr/lib/qt6/qml`, tracked by pacman;
- `at1ass-shell-greeter` — the greeter, into `/usr/share/at1ass-shell/greeter`, plus `/etc/greetd/greeter.json` and `/etc/greetd/hyprland-greeter.conf` as `backup` files (local edits survive upgrades; new defaults arrive as `.pacnew`).

```bash
cd ~/.config/quickshell/shell/packaging/arch
paru -B .      # builds in paru's clean chroot (Chroot/LocalRepo in paru.conf)
sudo pacman -Sy at1ass-shell-plugins at1ass-shell-greeter
```

The first install over plugins that were installed with `cmake --install`, and over hand-made `/etc/greetd` files, needs `--overwrite` for exactly those paths — pacman refuses unowned files otherwise:

```bash
sudo pacman -Sy \
  --overwrite '/usr/lib/qt6/qml/Calendar/*' --overwrite '/usr/lib/qt6/qml/FuzzySearch/*' \
  --overwrite '/usr/lib/qt6/qml/Mcu/*' --overwrite '/usr/lib/qt6/qml/Qalculate/*' \
  --overwrite '/usr/lib/qt6/qml/SystemMonitor/*' \
  --overwrite /etc/greetd/greeter.json --overwrite /etc/greetd/hyprland-greeter.conf \
  at1ass-shell-plugins at1ass-shell-greeter
```

`--overwrite` does not replace the two `/etc/greetd` files: they are `backup` files, so pacman keeps whatever is already there and writes its own copy as `.pacnew` if the contents differ. Check and swap them in, or the greeter keeps running from the old path:

```bash
ls /etc/greetd/*.pacnew
sudo mv /etc/greetd/hyprland-greeter.conf.pacnew /etc/greetd/hyprland-greeter.conf
```

The vendored `material-color-utilities` submodule is fetched over HTTPS and patched in `prepare()` (`src/plugins/patches/`), exactly as in a manual build.

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

# Brightness (DDC/CI external monitors)
bind = , XF86MonBrightnessUp,   global, quickshell:brightnessUp
bind = , XF86MonBrightnessDown, global, quickshell:brightnessDown

# Gaming mode and night light
bind = SUPER ALT, G, global, quickshell:gamingModeToggle
bind = SUPER ALT, N, global, quickshell:nightLightToggle
```

### 6. Run

```bash
QT_QPA_PLATFORMTHEME=gtk3 quickshell -p ~/.config/quickshell/shell
```

The GTK platform theme makes application and tray icons follow GTK's selected
icon theme. For a systemd user service, add `Environment=QT_QPA_PLATFORMTHEME=gtk3`
to its `[Service]` section; this overrides a session-wide `qt6ct` setting for the
shell. The Qt 6 GTK platform plugin must be installed (`libqgtk3.so`, provided by
`qt6-base` on Arch Linux).

Or add it to Hyprland's autostart:

```conf
exec-once = env QT_QPA_PLATFORMTHEME=gtk3 quickshell -p ~/.config/quickshell/shell
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

Only a fully validated snapshot is published. Invalid JSON, wrong types and invalid
per-monitor bindings leave the last good configuration active. On an invalid first
load the bundled defaults are used. `tools/shell-ctl config validate` reports the
latest rejected file, including syntax errors, rather than validating the retained
snapshot. Schema and default files must be present in the installation.

`notifications.popup.margin` controls notification placement. The old `bar.margin`
key remains a deprecated fallback when the new key is absent; it never moves the bar.

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
bar.autoHide             — reveal the bar only at its configured screen edge (no reserved space)
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
services.nightLight      — hyprsunset wrapper (default temperature; runtime toggle in state.json)
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

### Native greeter catalogs

`GreeterData 1.0` scans trusted `/usr/local/share` and `/usr/share` session directories
and the local `/etc/passwd` file on an independent worker. It publishes bounded DTO
snapshots; QML does no filesystem scanning or Exec parsing. Desktop entry values
and quoted arguments are decoded with GLib, field codes expand once, and greetd
receives a captured argv list. No shell, variable expansion or command substitution
runs during parsing. Hidden/NoDisplay entries, missing executables and TryExec are
filtered; higher-priority entries mask duplicates by session ID. Nonlocal accounts
remain available through Other user and are authenticated by greetd.

Build/install the updated plugins and greeter together before using this greeter.
Native tests: `greeter_data_test`; the real QML bridge is checked with
`python3 tools/test-greeter-data.py` (set QML_IMPORT_PATH to a temporary install root
when testing an uninstalled build). UI/auth tests retain fake greetd and catalogs.

### Greeter content

The standalone greetd UI uses the same compact password row and has no outer form
backplate. User switching is explicit; session selection appears only with multiple
sessions. Power actions share a confirmed inline menu. Its own root-owned
`/etc/greetd/greeter.json` controls profile, font scale, motion and element visibility;
`src/features/greeter/config/greeter.schema.json` supplies validation. See the
[greeter README](src/features/greeter/README.md) for defaults, packaging and tests.
Updating checkout files does not update the installed greeter; rebuild its package
from committed source. `python3 tools/test-greeter.py` uses fake authentication and
power actions, plus offscreen native previews.

### Lockscreen content

The lockscreen has no notifications. Its centered password form is immediately
available, with keyboard layout switching, Caps Lock feedback and reserved error
space. Track title/artist and previous/play-pause/next appear below the form when
a player is available; controls respect the player's capabilities. Text elides
instead of scrolling. Power is one button opening an inline menu; restart and
shutdown require confirmation with Cancel focused first. System power policy and
inhibitors are respected; failures are displayed on the lockscreen.

Configure visibility through `lockscreen` in config.json:

```json
{
  "lockscreen": {
    "blurWallpaper": true,
    "showClock": true,
    "showDate": true,
    "showUsername": true,
    "showWeather": false,
    "showBattery": true,
    "showNetwork": false,
    "showPower": true,
    "showMedia": true,
    "mediaShowPaused": true,
    "mediaShowArt": false
  }
}
```

Clock and date visibility are independent. Battery status only appears when a
battery is present; weather requires fresh data. The password form and necessary
authentication feedback are always available. The form starts on the focused
output; other outputs show the clock/date. Click another output to move the form
there. Disconnecting the selected output falls back to an available output. Small
outputs and large fonts scroll, keeping the focused password field visible.

### Temporary DND and Caffeine

Use `: dnd 30` or `: caffeine 90` in the launcher to enable a mode for that many
minutes. Without a duration, the action catalog offers presets from
`temporaryModes.durationsMinutes` (default `[15, 30, 60, 120]`). An empty list hides
preset rows; direct duration actions and IPC accept whole minutes from 1 to 1440.
Quick tiles show the expiry time while a temporary mode is active.

```sh
tools/shell-ctl dnd for 30
tools/shell-ctl caffeine for 90
tools/shell-ctl dnd until
tools/shell-ctl caffeine until
# Raw IPC equivalents:
qs ipc call notifications setDndFor 30
qs ipc call globalstates setIdleInhibitorFor 90
```

Deadlines live in state.json and survive shell restart without restarting the
countdown. Sleep/resume and the shared clock recheck wall time. Expiry releases
only the relevant manual mode; automatic fullscreen DND still applies. Manual
on/off/toggle cancels the deadline; explicit on makes the mode permanent. Starting
a duration replaces its prior deadline, including a previously permanent mode.
The `until` calls return an ISO UTC deadline or an empty string for a mode without
a timer. Caffeine expiry releases the inhibitor and lets the usual idle policy run.

`python3 tools/test-timed-modes.py` tests state loading, expiry, manual overrides,
restart, resume and CLI arguments with isolated state and a fake idle effect.

### Notification history and Undo

Clear all offers Undo in the centre, also available with Ctrl+Z while the undo
window is open. `notifications.panel.clearUndoTimeout` sets that window in
milliseconds (default 8000). The pending operation survives panel unloading and
shell restart; a second clear replaces the previous undo opportunity. The IPC
`notifications clear` command remains permanent and invalidates pending Undo.

New arrivals stay above restored older records. Restoration is batched, respects
the history cap and TTL, and preserves read state, grouped ordering and updated
content/actions. Clearing history leaves live popups alone. Expired clients are
not resurrected by Undo. History limits apply after startup and config reload;
the centre indicates when the cap is reached. Tightening rate-limit queues also
drops excess queued work through the normal lifecycle policy.

### Launcher modes

Type an application name, `= expression` to calculate, `> text` to search clipboard
history, or `: action` to find shell actions. Examples: `: audio`, `: calendar`,
`: dnd`, `: lock`. Only enabled modules contribute actions; Power menu opens its
existing choices. Arrow keys or Tab/Shift+Tab select results, PageUp/PageDown move
by a page, Enter activates and Escape closes. Tab/Shift+Tab keep the search editor
focused while selecting results, with both empty and nonempty queries. Home/End
remain text-editing keys.
The footer names the current mode and action. Empty results and pending
calculations have explicit messages. Enter flushes a pending text search before
activating; calculations expose a copy action only for the current expression.
Opening the launcher resets its query, selection and scroll position.

### Passive OSD and toasts

Volume and brightness share one compact meter: the latest action replaces the
previous one and restarts the hide timeout. OSD and toast windows pass pointer
input through and never grab focus. Position and dimensions respect the bar,
output bounds and font scale. Toast text is plain, wraps and is limited to three
lines; queued messages keep the output on which they were requested. Locking
clears overlays and queued messages.

`osd.monitorPolicy` defaults to `"focused"`: new actions choose the focused output.
Use `"all"` to retain presentation on every output. `osd.timeout` remains the meter
hide timeout after the final action. Configuration remains in config.json.

### Weather and calendar overview

Weather shows current conditions, feels-like temperature and the seven-day
forecast first. The seven days stay in one row, with high/low temperatures stacked
in each card. Narrow panels allow horizontal scrolling with arrow buttons while
keeping labels readable. Wind, humidity, pressure and daylight are behind Weather details;
their components load only while expanded. The last update is visible. A failed
refresh keeps the last successful values with an explicit status, and the initial
loading/error state shows no fabricated zero readings.

Calendar uses side-by-side month/day views when space permits and a scrollable
column otherwise. Empty days show a short summary instead of an empty 24-hour
ruler. Timed events retain their timeline and editor. Weekday headings follow the
system locale and configured first weekday; Today/T resets month and selection.

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
| `priority` | `null` for automatic ordering, or 0–100; higher stays visible longer |

The bar first shortens titles and labels, then uses compact widget presentations.
If space remains insufficient, lower-priority widgets move into “More”; expanding
the screen restores them automatically. More retains actions, media controls,
workspace switching and the application tray. Clock and workspaces have the
highest automatic priorities; a low battery gets extra priority. With popouts
disabled, a horizontally scrollable strip keeps every control accessible.
The bar follows top/bottom placement and grows when larger fonts require it.

Dashboard Quick keeps modes, destination tiles, brightness and system/media
information. Audio controls live in the Audio panel, and the header shows the
date without duplicating the bar clock.

Night Light retries repeated helper exits with a capped backoff. Explicit temperature
changes remain fast; stopping waits for the old helper before starting another.

Brightness DDC commands run serially with deadlines. Initial values are published
only after valid VCP reads; writes use each display's reported maximum, coalesce
to the latest requested level and read back the result. `python3 tools/test-brightness.py --native` tests the transport with an absolute fake executable, without changing
hardware brightness.

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

Bar primary clicks open the configured `clickAction`. Clock, weather and the media
body also retain their former right-click shortcut. Volume opens Audio by default;
right-click toggles mute and scrolling adjusts volume. Individual media buttons
control playback without opening a panel. Existing explicit click actions are
respected; bundled clock defaults now open Calendar.

Clock/date and media keep a stable width on hover. `clock.settings.showDate`
shows a persistent inline date. `media.settings.compact` shows an icon and play/pause;
full mode adds bounded track text and previous/next buttons. Hover reveals details
in a tooltip rather than moving adjacent controls.

Quick → System statistics shows CPU/GPU usage and temperature trends, current
percentages, CPU load average (1/5/15 minutes), memory and storage usage, and disk
read/write rates. The native worker samples in the background; closing Dashboard
or collapsing statistics does not pause history. Each series retains at most 120
samples (about four minutes at the default two-second cadence), in memory until
the shell reloads/restarts. Temperature trends use a fixed 0–120 °C scale; usage
trends use 0–100%. Unsupported temperature sensors are marked unavailable.


Storage expands into local mounted filesystems and physical devices. Repeated
Btrfs/bind mounts share one capacity row. Network/pseudo/loop mounts are omitted;
boot mounts are excluded by default. Each volume shows available/total space and
an occupancy indicator; its details show mount paths, filesystem type, device and
read-only state. Device rows show I/O and temperature where sysfs exposes it.
Aggregate I/O counts whole leaf devices once, without adding partition/dm/md
counters again. Filesystem capacities are never summed into a misleading total.
Low-space state remains visible on the collapsed System statistics header, with
no toast or blinking. Defaults: warning at <=10% available, critical at <=5%.
The native storage API requires an updated SystemMonitor plugin; older installed
plugins retain the system-volume summary until the package is upgraded.

```json
"storage": {
  "warningFreePercent": 10,
  "criticalFreePercent": 5,
  "excludedMounts": ["/boot", "/boot/efi", "/efi"],
  "order": ["/", "/home"],
  "labels": {"/mnt/games": "Games"}
}
```

Names and order use primary mount paths. A read-only volume or failed space probe
never raises a low-space indicator. Thresholds apply to space available to the
current user; critical is clamped to warning if configured larger. Discovery and
space/temperature reads run on the existing worker slow cadence (5 s), while I/O
uses the existing fast cadence. `python3 tools/test-statistics.py` checks native
sampling/UI; set `STORAGE_PLUGIN_IMPORT` to a build's parent of `SystemMonitor/`
to exercise an uninstalled plugin. `storage_test` covers grouping, thresholds and
counter resets with fixtures.

Bar, dock and local hints share the UI kit's tooltip surface: a short hover delay,
plain text, bounded wrapping and a single fade. Passive bar hints never take input
focus. Closing a panel-suppressed tooltip retains its last native position and size
until the window is unmapped, avoiding a jump to the screen edge. Long text is ellipsized after eight lines or at the available screen height.
Tray menus scroll within the screen, show checkbox/radio states, and support
Up/Down, Home/End and Tab. Right opens a submenu; Left/Escape returns one level;
Enter/Space activates the focused action. Submenus also have a visible Back row.
The dock context menu supports keyboard focus and Escape. Configuration remains
file-only.


Available `clickAction` values:

| Value | Action |
|-------|--------|
| `dashboard-quick` | Open Dashboard on the Quick tab |
| `dashboard-weather` | Open Dashboard on the Weather tab |
| `dashboard-calendar` | Open Dashboard on the Calendar tab |
| `audio` | Toggle the standalone audio panel |
| `dashboard-audio` | Compatibility alias for the audio panel |
| `connections` | Toggle the compact connections panel |
| `connections-wifi` | Open/toggle Connections with Wi-Fi expanded |
| `connections-bluetooth` | Open/toggle Connections with Bluetooth expanded |
| `dashboard-network` | Compatibility alias for Connections / Wi-Fi |
| `notification-center` | Toggle the notification center |
| `launcher` | Open the launcher |

---

### Dock

Per-screen application dock showing pinned + running apps, with live window previews.
Icon motion pauses while hidden. Reduced motion and gaming mode use a static
urgency indicator; launch tracking continues without animation. App-name hints
retain their text and geometry until the closing fade ends. Hover and delayed
preview targets follow app keys through list reordering; removing an app cancels
its pending preview. Preview thumbnails shrink to preserve the title when space
is limited; preview and menu bounds account for the dock's screen edge.

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
qs ipc call globalstates openDashboardTab 0   # 0=Quick 1=Weather 2=Calendar; legacy 3 opens Audio, 4 opens Connections / Wi-Fi

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
qs ipc call notifications clear           # permanently wipe history; discard pending undo
qs ipc call notifications undoClear       # restore the latest undoable Clear all
qs ipc call notifications canUndoClear    # whether its undo window is still open
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
│   │   ├── dashboard/           # 3-tab overview
│   │   ├── launcher/            # Application search
│   │   ├── notifications/       # Notification center and popups
│   │   ├── osd/                 # SystemOSD, OsdMeterContent, ToastOverlay
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
│   │       ├── greeter-data-qml/ # Native greeter catalogs and session argv
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
| `brightnessUp` | Brightness +5% (DDC/CI) |
| `brightnessDown` | Brightness −5% (DDC/CI) |

Notification regressions can be checked with `tools/test-notifications.py`. It runs
the real list, cards and history in an isolated offscreen shell with temporary
XDG directories. It checks wrapped actions, text updates, async images, resizing,
scrolling and keyboard selection. On a collapsed group header, Enter expands the
group and Delete/X removes that group from history.


## Foundation regression checks

```bash
tools/test-foundation.py
tools/test-network.py
python3 tools/test-network-auth.py
python3 tools/test-network-info.py
tools/check.sh
cmake -B /tmp/shell-plugins-test -S src/plugins -G Ninja -DBUILD_TESTING=ON
cmake --build /tmp/shell-plugins-test
QT_QPA_PLATFORM=offscreen ctest --test-dir /tmp/shell-plugins-test --output-on-failure
```

Network agent tests use a private D-Bus manager. To exercise libsecret writes,
run `python3 tools/test-network-keyring.py /path/to/network_agent_test`: it starts
an isolated GNOME Keyring and verifies its temporary data directory before any
write. It never writes to the session's real keyring. `QML_IMPORT_PATH` can point
to the built plugin directory for lint/compile checks before installation.

The foundation checks use temporary configuration/state directories, a local HTTP
server and a fake logind transport. They cover rejected config edits and recovery,
IPC diagnostics, real request timeout/cancellation, foreign-session signals and
compile probes that fail to start or never finish. They never modify the running
shell's config or send lock/unlock commands to logind.

Retained panels keep their UI trees but stop radio discovery when closed. Clipboard
history reads pause while the launcher is closed; visible image rows own preview requests.
Caffeine, night light and gaming mode restore independently of dashboard loading.
Calendar/SystemMonitor workers finish cooperatively after their facade is removed;
MCU and calculator results use facade-owned future watchers. UI destruction neither
terminates a worker nor waits for unfinished I/O. Retiring SystemMonitor workers
share refcounted, serialized libsensors state across reloads.

C++ changes require rebuilding the installed plugin package and restarting the
shell after checking that it is unlocked. Building the test targets does not
replace installed plugins.


## Workspace overview

An on-demand overlay shows workspace miniatures with window previews and their
relative positions, including existing workspaces outside the configured empty
workspace range. The interaction is inspired by the local ii overview; the model,
UI and commands use this shell's own services and kit.

Open with `qs -c shell ipc call globalstates toggleOverview`, the global shortcut
`quickshell:overviewToggle`, or a workspace chip's right-click when no explicit
clickAction is configured. A widget can set `clickAction: "overview"`.

Search by window title, application or workspace name. Alt+J/K select windows;
Alt+H/L select workspaces from any control, including search. Outside the editor,
bare J/K and H/L do the same. In the destination picker, J/K (also with Alt)
move between enabled destinations. These bindings use physical key positions on
all layouts; ordinary H/J/K/L still type into search. Up/Down also select matches;
Enter or clicking a preview switches to its window. PgUp/PgDn select a workspace,
including empty ones; Enter from search switches to an empty selected workspace
when there is no query. Workspace arrows switch to
that workspace. Physical Ctrl+M (including non-Latin layouts), the move button, Menu or right-clicking a preview opens a
keyboard-accessible destination picker; the move keeps the overview open. Escape
closes the picker or overview. Initial selection follows the active window.

Physical Ctrl+W closes the selected window, including from search; a close button
appears on the selected or hovered preview. Closing requests the application's
normal close operation without focusing its workspace or force-killing it. Its
preview capture is stopped before the close request. If the application keeps the
window open (for example, after cancelling a save dialog), reopening overview
restores its live preview. The
overview stays open and updates from the native window model; applications may
show their usual unsaved-changes confirmation. Closing is disabled during a drag
or while the destination picker is open.

Drag a window preview (or icon/title when previews are disabled) onto another
workspace card. A highlighted target and ghost label show the destination; release
moves the window and leaves overview open. Escape, an outside drop, or removal of
the source cancels. Holding near the grid edge scrolls; the source delegate stays
alive without overwriting its position bindings. Background tint marks the selected
workspace and a separate outline marks the drop target.

Tiled insertion remains Hyprland's normal layout placement, as in ii; dropping on
a card does not choose a split relative to a particular window. Exact split
placement would need a separate compositor integration, not cursor/focus tricks.

```json
"overview": {
  "firstWorkspace": 1,
  "workspaceCount": 9,
  "columns": 3,
  "includeSpecial": true,
  "showPreviews": true
}
```

`modules.overview` gates all entry points. Columns adapt to narrow outputs, and
card height is capped by the rows and viewport height so nine workspaces fit both
ultrawide and portrait outputs. Workspace canvases preserve monitor aspect ratio.
At large counts or short viewports, minimum readable card height wins and the grid
scrolls to selection. Captures are limited to visible workspace cards
and resolution-constrained. Previews use the same Wayland ScreencopyView source as the dock and update live
while their cards are visible. Set `overview.showPreviews` to false for icons and
titles with no capture objects or buffers. Unavailable capture uses an icon, and closing unloads the UI
and clears search/capture state. The destination picker retains its original
source and target IDs across unrelated model updates; a disappearing source
cancels it. All normal commands are validated and routed through HyprlandDispatch;
see [Hyprland dispatchers](https://wiki.hypr.land/configuring/core/dispatchers/).

## Keyboard and compact layouts

The minimal pack is the primary desktop profile; MD3 uses the same components
with its own density tokens. Shared buttons, fields, icon buttons and launcher
rows follow those tokens and the configured font scale.

- Dashboard: Tab/Shift+Tab traverse controls; Ctrl+Tab/Ctrl+Shift+Tab change
  sections from any focused control, except while a modal is open. Inside the
  section strip, Left/Right and Home/End select a tab; Up/Down do not move calendar
  days behind it. Tab enters the content. Bare number/media/vi panel shortcuts
  apply only when the panel background itself has focus.
- Power menu: actions wrap by screen width and scroll to keyboard focus on short
  screens. Tab/Shift+Tab, arrows and Home/End navigate; Enter/Space or physical
  letter shortcuts activate. Holding a key cannot confirm a destructive action.
  Moving to another action cancels confirmation; Escape cancels it before closing.
- Audio/Connections: Enter or Space activates device rows; radio/switch actions remain
  controlled by the native services. Bluetooth list updates preserve focus by
  device address. Busy operations cannot be activated again from their row.
- Calendar: Tab enters/leaves the date grid; arrows or H/J/K/L move its focused day
  and Enter selects it. Tab reaches events; Enter opens the editor and scrolls the timeline
  to the focused card. The Today button or T within the date grid returns to the current day.
  Month and day views stack on narrow panels; Tab reveals actions below the fold.
  The event editor scrolls to focused fields. Description grows with text and
  follows the caret; Tab/Shift+Tab leave it for adjacent fields.
- Mode tiles show on/off state; destination tiles have arrows and command tiles
  have no state marker. Unavailable VPN, Night Light and disabled Screenshot
  actions are omitted from Quick. Tiles support Space and Enter. Combo boxes support arrows, Home/End,
  Space/Enter and Escape.
- Selection fields keep externally owned selections synchronized after keyboard
  choices and catalog updates. Empty/disabled lists do not open blank menus.
- Clipboard history reads stop when the launcher closes. Image-cache setup waits
  until a thumbnail is requested; copy actions continue after closing the launcher.
- Buttons activate with Enter, keypad Enter or Space in both design packs.
- Dialogs keep keyboard traversal inside the nearest open modal and restore
  the previous focus on close. Editors have a single Tab stop.
- Dashboard and launcher sizes are limited to the active screen. Quick controls
  and weather cards reflow and scroll on narrower outputs; scroll containers
  reveal a focused control automatically.
- The launcher uses the shared text field. Its existing search debounce, Enter
  activation and clipboard navigation remain in place.

Run `tools/test-ui.py` for isolated Qt Quick tests with real key events and mock
system services. It checks both packs, font scales 1/1.3/2, modal focus, compact
and wide dashboard/weather layouts. Rendered fixtures are saved under
`/tmp/shell-ui-renders`; they contain no live desktop or user data.


## Connections panel

The standalone panel replaces Dashboard's Network tab. One section is expanded
at a time: Wi-Fi, Bluetooth or VPN. Ethernet appears as a compact connected row.
Quick's Wi-Fi/Bluetooth actions open the corresponding section; VPN is available inside Connections.

Ethernet status comes from Quickshell's native activation state, independently
of IPv4/IPv6 address assignment. Connection details for Ethernet and connected
Wi-Fi list IPv4 and IPv6 addresses with prefixes and their separate gateways,
including IPv6 link-local addresses. They update while the details dialog is open.
An absent gateway is shown as None; connection status does not claim internet
reachability. IP configuration is read asynchronously from NetworkManager D-Bus
by Connectivity.NetworkInterfaceInfo, with no nmcli queries or sysfs reads for
Ethernet. Adapter/daemon changes clear old details and late replies are ignored.
Rebuild/install Connectivity to enable the new IP details; link status remains
usable with the previously installed plugin.

The read-only `python3 tools/test-network-info.py --native` probe also loads the
actual Quickshell device model and IP reader. Native `network_info_test` runs
against a private fake NetworkManager, covering IPv6-only/dual-stack, configuration
replacement, address removal, daemon changes and delayed replies. Neither test
changes connections, radio state or system IP configuration.

```bash
qs ipc call globalstates toggleConnections
qs ipc call globalstates openConnections wifi
qs ipc call globalstates openConnections bluetooth
qs ipc call globalstates closeConnections
# Optional Hyprland binding:
# bind = SUPER, N, global, quickshell:connectionsToggle
```

`modules.connections` enables the panel. `connections.width` (420) and
`connections.maxHeight` (640) set its preferred logical dimensions; both are
clamped to the output and long lists scroll. `performance.keepPanelsLoaded` can
include `connections`. User configuration is never rewritten.

VPN profiles and active states are discovered through NetworkManager D-Bus when
`services.vpn.enabled` is true. Rows use UUIDs, so renaming a profile and duplicate
names do not change the action target. Multiple active profiles are represented
individually. A general VPN action opens the selector; `services.vpn.name` is now
ignored and retained in the schema only for config compatibility. Additions,
renames, removals and active-state changes update the list without reopening it.
Refresh failures keep the last working snapshot and show an inline error.

Activation/disconnection use `nmcli connection up/down uuid …` with one owned,
bounded command at a time; the deadline allows credential entry. Submitted
credentials are handled by the existing secret agent, never passed as CLI arguments.
Profile discovery never calls GetSecrets. The global `nmcli monitor` process and
separate list/state query processes are no longer needed. Rebuild/install the
Connectivity plugin for the new VpnProfiles reader; an older plugin leaves the
shell running but cannot provide the new VPN list.

`python3 tools/test-vpn.py` tests actions using a non-spawning process and fake
metadata. `--native` additionally reads the real profile/model bridge, without
activation, profile changes or secret requests. `vpn_profiles_test` exercises a
private D-Bus manager, including duplicate/control-character names, rename/removal,
multiple active states, stale replies, restart, errors and pending destruction.

The network bar widget supports `connections`, `connections-wifi` and
`connections-bluetooth` click actions. Its `settings.showLabel` defaults to false;
connection names remain available in the tooltip. Existing explicit click actions
are respected. Openings from the widget stay on its monitor and hold that bar open.

Enter/Space activates rows. Connected rows open actions instead of disconnecting
immediately. Menus support arrows/Home/End, and Escape returns focus to the initiating
control. Forgetting a network/device requires confirmation. A personal Wi-Fi
password can be entered or retried inside the panel. WPA/WPA2 Personal and SAE
use the native [Quickshell 0.3.2 connectWithPsk API](https://quickshell.org/docs/v0.3.2/types/Quickshell.Networking/WifiNetwork/),
with no `nmcli` process or password retained by the service. The network object
identifies the target; SSIDs are never interpreted as CLI arguments. Legacy WEP,
enterprise and unknown security use the external connection editor. OWE networks
connect without a password.

NetworkManager credential requests are handled by the native Connectivity agent.
The panel opens on demand, including after a rejected Wi-Fi password, and shares
its existing modal focus grab. Supported fields cover Personal/WEP, passwords and
private-key passwords in saved 802.1X profiles, PPPoE/mobile credentials, and the
installed OpenVPN helper's multiple fields and challenge responses. Other VPN
plugins and WireGuard-specific credentials are not implemented. Profile creation,
certificates and advanced editing stay in **nm-connection-editor**.

`connections.networkAgent` defaults to true. The request deadline is
`connections.authenticationTimeout` (120 seconds, including input and storage).
The agent honors interactive/new-secret requests and secret ownership flags.
Agent-owned passwords use the session Secret Service with nm-applet-compatible
attributes; system-owned passwords remain managed by NetworkManager. Unsaved
secrets and OpenVPN challenge answers are never persisted. Config, runtime state,
logs and process arguments never contain the submitted passwords. Storage and
VPN field discovery run outside the UI thread.

Closing the panel, leaving the requested section, locking, resuming or losing
NetworkManager cancels an interactive request. Noninteractive stored-credential
lookups can run while locked without opening the panel or unlocking the keyring.
Stale tokens cannot submit a replacement request. Errors never include provider
messages or credential values.

```bash
qs ipc call networkauth registered
qs ipc call networkauth busy
qs ipc call networkauth cancel
```

Rebuild/install the plugin package and restart the unlocked shell before migrating
away from nm-applet. The optional native loader keeps an older installation usable
with the existing external agent; a build directory alone does not update it.
Confirm registration and test wrong -> correct Wi-Fi password with Connections
left open, then OpenVPN/keyring behavior. Only after this acceptance disable
nm-applet's XDG autostart with a user `nm-applet.desktop` override containing
`Hidden=true`, and stop its running process. This migration does not remove
nm-connection-editor or change blueman-applet. To roll back, restore nm-applet
and set `connections.networkAgent` to false.

Wi-Fi discovery runs only in the visible expanded Wi-Fi section and stops after
20 seconds of idle discovery. The deadline pauses during a connection attempt.
Discovery waits until the adapter is ready and resumes after a radio/device restart
without reopening the panel; explicit retries refresh discovery after its deadline.
Disabling Wi-Fi clears the previous attempt/error, and late failures cannot restore
that message. PSK retries wait for network and adapter teardown to finish. An
ambiguous association timeout asks the user to check both password and signal,
rather than declaring that the SSID does not exist.
Bluetooth discovery starts from **Pair new device**, stops after
30 seconds, and ends when leaving the section or closing the panel. Connection
operations belong to services and can finish after the panel closes.

Bluetooth pairing prompts stay inside Connections and share its focus grab. PINs,
passkeys, matching-code confirmations and service authorization require an explicit
answer; keyboard codes show entered-digit progress. The agent handles only a device
selected in this panel, verifies the BlueZ sender and rejects stale answers. Closing
the panel, leaving Bluetooth, locking, resuming, disabling the adapter or losing the
device cancels pairing. Ordinary connect/disconnect operations can finish in the
background. The bounded deadline defaults to 120 seconds:

```json
"connections": {
  "width": 420,
  "maxHeight": 640,
  "networkAgent": true,
  "authenticationTimeout": 120,
  "bluetoothAgent": true,
  "pairingTimeout": 120
}
```

`bluetoothAgent: false` keeps pairing on the external default agent. The native
`Connectivity 1.0` module must be rebuilt and installed for the integrated prompts;
a missing module is isolated by a loader and leaves the shell running with external
agent fallback. Registration is [application-scoped](https://bluez.readthedocs.io/en/latest/agent-api/):
it never requests default-agent ownership. Retain blueman-applet until the remaining
Bluetooth hardware scenarios pass; nm-applet migration is independent (see above).
**Edit connections** opens nm-connection-editor; **Bluetooth manager** opens
blueman-manager through AppLaunchService. There are no shell settings in the panel.


Tray menu actions use compact rows (36 px in Minimal, 48 px in MD3 before text
measurement), with short separators rather than list-sized blank rows. Large fonts
and custom slots can increase the measured height; long menus retain scrolling
and keyboard navigation through all actions and submenus.

Dashboard uses a stable Wayland surface within the available screen height.
The card follows the actual content extent without a second resize animation.
Player controls and occupied height share one morph; statistics and weather details
keep their lazy content alive through the clipped collapse, then release it.
Tab changes apply the newly measured height directly, so no empty background trails
the smaller tab. The input region follows the card; transparent space passes clicks
through. Initial/hidden changes and reduced motion apply immediately, and long
content stays scrollable within the screen bounds.

The cheatsheet discovers IPC handlers and signatures with `qs ipc show` on every
open. Local descriptions enrich those commands without defining a second list.
The query has a deadline and retry state; failed refreshes retain the last valid
surface. Filters update after discovery, including new Connections commands.


## Audio panel and bounded tray

Audio is a standalone panel; Dashboard contains Quick, Weather and Calendar.
Left-clicking the volume widget opens Audio (including legacy `dashboard-audio`
click actions), right-click toggles mute, and the wheel adjusts output volume.
Without a ready output device the bar shows `--%`; mute and wheel commands wait
for its audio interface, while opening the device panel remains available.
Quick offers a direct Audio action; system diagnostics are collapsed by default.

```bash
qs ipc call globalstates toggleAudio
qs ipc call globalstates openAudio
qs ipc call globalstates closeAudio
# Optional Hyprland binding:
# bind = SUPER, A, global, quickshell:audioToggle
```

`modules.audio` enables the panel; `audio.width` defaults to 420 and
`audio.maxHeight` to 640. Geometry is clamped to the active output. The panel shows
output and microphone volume/mute, live device pickers and an application mixer
that only binds stream nodes while expanded and visible. Missing devices retain a
short status row without disabled sliders. Tab traverses controls; device lists
also accept arrows/Home/End. Escape closes the picker, then the expanded mixer,
then the panel. `performance.keepPanelsLoaded` may include `audio`.

Tray widget settings now include:

```json
"settings": {
  "iconSize": 20,
  "spacing": 8,
  "maxVisible": 4,
  "pinnedIds": []
}
```

At most `maxVisible` icons occupy the bar; the rest are available from its overflow
button in a scrollable list with application names. Set 0 for an overflow-only
tray. `pinnedIds` lists exact StatusNotifierItem IDs, in priority order; pinning
respects the same visible limit. App registration order otherwise remains stable.
A dot on the overflow button signals hidden items requesting attention.

Left/middle/right actions and wheel input remain available on bar icons. Overflow
rows activate with Enter/Space; arrows/Home/End navigate, Menu/Shift+F10 or the
trailing button opens the application menu. Switching from overflow into a menu
keeps a surviving bar anchor. If popouts are disabled, all icons stay on the bar
so they remain reachable. Hidden icons keep their applications and authentication
agents running; hiding an icon does not disable its applet.


Wallpaper replacement keeps the previous image visible until the next asynchronous
decode finishes (`Image.retainWhileLoading`, Qt 6.8+). The background window clears
to Theme.surface on initial load and in letterboxed areas, rather than the default
white. Decode size remains capped to each screen; changing wallpaper does not
block the UI thread. See [Qt Image retention](https://doc.qt.io/qt-6/qml-qtquick-image.html#retainWhileLoading-prop).
