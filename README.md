# at1ass-shell

A keyboard-oriented desktop shell for **Hyprland**, built with
[Quickshell](https://quickshell.org/) and Qt 6. The primary visual profile is
**Minimal**; **MD3** is also supported. Configuration lives in JSON files, with
schema validation and hot reload. There is no settings GUI.

The shell provides a status bar, optional dock, application launcher, workspace
overview with live window previews, notifications, audio and connection panels,
weather/calendar dashboard, system statistics, wallpapers, screenshots, recording,
and an optional lockscreen. A separate greetd greeter is available.

It does not install a complete Hyprland configuration or configure the machine's
network, audio, idle policy or login manager. Those remain explicit setup steps.

## Contents

- [Install from AUR](#install-from-aur)
- [Configure the shell](#configure-the-shell)
- [Start with uwsm](#start-with-uwsm)
- [Start without uwsm](#start-without-uwsm)
- [Finish session integration](#finish-session-integration)
- [Use the shell](#use-the-shell)
- [Optional greetd greeter](#optional-greetd-greeter)
- [Update and troubleshoot](#update-and-troubleshoot)
- [Development](#development)

## Install from AUR

Arch Linux on x86_64 is the packaged target. Use a working Hyprland session with
**Quickshell 0.3.2+**, **Hyprland 0.56+** and **Qt 6.10+**. The compositor integration
uses Hyprland's Lua dispatcher API; other Wayland compositors are not supported.

Prepare the normal Arch build environment, then install with an AUR helper such
as paru (run the helper as your regular user):

```bash
sudo pacman -Syu --needed base-devel git
paru -S --aur at1ass-shell-git
```

| Package | Purpose |
|---|---|
| [at1ass-shell-git](https://aur.archlinux.org/packages/at1ass-shell-git) | Shell, bundled defaults/schema, CLI and systemd user service |
| [at1ass-shell-plugins-git](https://aur.archlinux.org/packages/at1ass-shell-plugins-git) | Seven native QML plugins; installed automatically with the shell |
| [at1ass-shell-greeter-git](https://aur.archlinux.org/packages/at1ass-shell-greeter-git) | Optional login screen for greetd; install separately |

Without an AUR helper, clone the public AUR recipe, review it, build, then install
shell and plugins together:

```bash
git clone https://aur.archlinux.org/at1ass-shell-git.git
cd at1ass-shell-git
makepkg -s
sudo pacman -U ./at1ass-shell-git-*.pkg.tar.zst ./at1ass-shell-plugins-git-*.pkg.tar.zst
```

The split recipe also builds the optional greeter. You do not need to install it
to use the desktop shell. Sources come from public GitHub HTTPS URLs; no SSH key
or checkout under `~/.config` is needed.

Packages install code under `/usr/share/at1ass-shell`, plugins under
`/usr/lib/qt6/qml`, and `at1ass-shell.service` under `/usr/lib/systemd/user`.
They do not write files into your home, enable services or replace your login
manager. Required dependencies are installed automatically; optional features
need the packages and services listed below.

## Dependencies and Arch packages

The authoritative dependency declarations are in `packaging/arch/PKGBUILD`.
Dependencies below are checked against QML imports, CMake, external command call
sites, ELF NEEDED entries and Arch file ownership; disabling a UI module does not
remove a linked native library requirement. Supported baseline: Quickshell 0.3.2,
Hyprland 0.56+ Lua dispatch and Qt 6.10+. Current runtime checks use Qt 6.12.
These are minimum supported versions,
not a promise of compatibility with future breaking compositor/framework changes.

| Category | Required packages | Reason |
|---|---|---|
| Shell engine | `quickshell>=0.3.2`, `hyprland>=0.56` | Native QS modules including Networking, Bluetooth, PipeWire, PAM, Polkit and Hyprland; compositor Lua IPC and focus grabs |
| QML runtime | `qt6-base`, `qt6-declarative`, `qt6-wayland`, `qt6-svg` | Controls, layouts, effects, LocalStorage, Wayland rendering and SVG application icons |
| Native plugins | matching `at1ass-shell-plugins-git` | All seven QML modules are shipped as one versioned set |
| Plugin shared libraries | `glibc`, `libgcc`, `libstdc++`, `qt6-base`, `qt6-declarative`, `libical>=4.0`, `libqalculate`, `lm_sensors`, `glib2`, `libsecret` | Direct native linkage; in this package SystemMonitor is built with libsensors, so lm_sensors is required at runtime |
| Application launching | `app2unit`, `xdg-terminal-exec` | Separate systemd scope per application; Terminal=true desktop entries |
| Commands/session | `bash`, `coreutils`, `findutils`, `gawk`, `grep`, `sed`, `glib2`, `systemd`, `pam`, `util-linux`, `which` | Packaged CLI, local wallpaper/cache operations, gdbus/logind, lockscreen PAM `login` policy and capability probes |
| Default appearance | `ttf-material-symbols-variable`, `ttf-roboto`, `ttf-dejavu`, `hicolor-icon-theme` | Sharp/Rounded icon cuts, MD3 text, portable minimal monospace and desktop icon fallback |
| Build only | `base-devel`, `git`, `cmake`, `ninja`, `pkgconf`, `python`, `rapidfuzz-cpp`, plus native library headers | base-devel is the Arch build environment; RapidFuzz is header-only and uses the system CMake package, with configure-time downloads disabled |
| Review/test only | `namcap`, `devtools` | Dependency/lint review and clean-chroot validation; not installed with the shell |

`qt6-tools` is not a separate build requirement: moc/rcc and QML build tools come
from the Qt base/declarative packages. A different Quickshell build must include
the modules imported by this project; a package name alone cannot guarantee that.

Optional packages enable these features; their absence must not prevent core UI
startup. Installing a package is separate from starting its system/user service.

| Optional packages | Feature and additional setup |
|---|---|
| `ca-certificates` | HTTPS trust for weather and wallpaper feeds |
| `xdg-utils` | External calendar URL opening through Qt desktop services |
| `nvidia-utils` | Optional NVIDIA NVML GPU statistics; loaded dynamically, not linked as a mandatory plugin library |
| `pipewire-pulse` | Optional PulseAudio compatibility for applications; shell controls use native PipeWire |
| `xdg-desktop-portal`, `xdg-desktop-portal-hyprland` | Required for recorder `capture.target=portal` (the default), together with a running PipeWire service and session portal backend |
| `pipewire`, `wireplumber` | Audio controls need a running PipeWire graph and a session policy manager; wireplumber is the supported default |
| `networkmanager` | Wi-Fi/Ethernet/VPN need the running NetworkManager service; VPN activation uses nmcli |
| `bluez` | Bluetooth requires bluetooth.service and supported/unblocked hardware |
| `upower` | Battery/power-device information in the bar, lockscreen and optional greeter; UPower service needed |
| `accountsservice` | Optional dashboard/greeter avatars through system D-Bus; no direct `.face` lookup |
| `gnome-keyring` or another Secret Service provider | Persists agent-owned network credentials; libsecret itself is already a mandatory plugin library |
| `networkmanager-openvpn` | Supplies `/usr/lib/nm-openvpn-auth-dialog` for OpenVPN authentication; other VPN plugins are profile-specific |
| `nm-connection-editor`, `blueman`, `pwvucontrol` | Explicit external network profile, Bluetooth and advanced audio actions |
| `grim`, `wl-clipboard` | Screenshot capture/copy; the basic screenshot action needs both |
| `swappy` | Screenshot annotation, together with grim |
| `cliphist`, `wl-clipboard` | Clipboard history also needs external `wl-paste --watch cliphist store` ingestion; installing cliphist alone does not collect history |
| `gpu-screen-recorder`, `procps-ng` | Recording needs both gpu-screen-recorder and its `gsr-cli` control binary; pgrep detects recordings. A working GPU encoder/driver is also needed. Verify gsr-cli exists in the chosen build; the current host uses gpu-screen-recorder-git |
| `ddcutil` | Brightness requires DDC/CI-capable displays and I2C/device permissions; package installation alone is insufficient |
| `hyprsunset` | Night-light temperature changes |
| `curl` | Remote wallpaper downloads; local wallpapers do not require curl |
| `qt6-imageformats` | Additional image codecs beyond the base Qt image readers |
| `hypridle` | Caffeine idle inhibition and idle lock/suspend policy; explicitly connect locking to the packaged IPC command |
| `vdirsyncer` | External CalDAV synchronization into local calendar stores |
| `uwsm` | Optional graphical-session environment/lifetime management; a correctly imported systemd user environment works without it |

Native status/auth agents replace the need for nm-applet/blueman-applet; those
applets are not dependencies. pactl/playerctl/bluetoothctl are also not required
for the native PipeWire/MPRIS/Bluetooth controls. Polkit authorization is separate from Secret Service
storage: use the shell's optional polkit module or another session agent, not two.

## Configure the shell

The user configuration is
`$XDG_CONFIG_HOME/quickshell/config.json`, normally
`~/.config/quickshell/config.json`. With no user file, bundled defaults are used.

For a first installation, create the directory and copy the complete defaults
without overwriting an existing configuration:

```bash
mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"
cp -n /usr/share/at1ass-shell/config/default.json \
  "${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/config.json"
```

Edit that file with your editor. Add this top-level field for editor completion:

```json
"$schema": "/usr/share/at1ass-shell/config/config.schema.json"
```

The complete reference is [config.schema.json](config/config.schema.json);
[default.json](config/default.json) contains all defaults. Both are also installed
under `/usr/share/at1ass-shell/config/`. Examples below show fields to edit or merge
into your file, not additional files to load. Use strict JSON: no comments or
trailing commas. Keep the top-level `"version": 1` from the defaults. An omitted setting uses its individual fallback; arrays such as
`bar.widgets` replace the whole corresponding list.

### First settings to review

The shipped defaults currently select **MD3** at font scale **1.3**. To use the
primary Minimal profile, change:

```json
"appearance": {
  "designSystem": "minimal",
  "fontScale": 1.0,
  "theme": {
    "source": "wallpaper",
    "variant": "tonalspot",
    "contrast": 0.0,
    "darkMode": true
  },
  "reduceMotion": false
}
```

`contrast: 0.0` is standard Material contrast; positive values select increased
contrast. `reduceMotion` disables animations. Theme colours follow the wallpaper.

| Section | Configure |
|---|---|
| `modules` | Enable/disable shell features; dock, lockscreen and polkit agent are off by default |
| `bar` | Top/bottom placement, height, transparency, auto-hide and ordered widgets |
| `dock` | Position, auto-hide, icon size and pinned applications |
| `services.weather` | Your coordinates, location label, units; disable if unused |
| `services.vpn.enabled` | Set `true` to list and control saved VPN profiles; default is `false` |
| `wallpaper` | Default image, local/remote sources and per-monitor bindings |
| `notifications` | Popup monitor/position/timeouts, grouping, filters and history |
| `overview` | Workspace range, columns, special workspaces and live previews |
| `lockscreen` | Clock/date, user, media, battery, weather/network and power visibility |
| `storage` | Free-space warning thresholds, excluded mounts, ordering and labels |
| `recorder` | Capture target, output directory, encoder and audio sources |
| `performance.keepPanelsLoaded` | Panels retained after first use for faster reopening |

Weather defaults to London. Set your location, or disable it:

```json
"services": {
  "weather": {
    "enabled": true,
    "location": "London",
    "latitude": 51.5,
    "longitude": -0.12,
    "units": "metric",
    "refreshMinutes": 15
  },
  "vpn": { "enabled": true }
}
```

For a single wallpaper, set `wallpaper.defaultWallpaper` to an absolute image path.
For a local collection, use an actual monitor name from `hyprctl monitors`:

```json
"wallpaper": {
  "defaultWallpaper": "/absolute/path/to/background.jpg",
  "sources": [
    { "id": "local", "type": "local", "path": "/absolute/path/to/wallpapers" }
  ],
  "monitors": {
    "DP-1": {
      "sourceId": "local",
      "autoChange": { "enabled": true, "intervalMs": 300000 },
      "randomOrder": true
    }
  }
}
```

Do not run a second wallpaper daemon on the same outputs when using the shell's
wallpaper layer. Disable `modules.wallpaper` to keep an external wallpaper tool.

### User avatar and system summary

Quick has a compact header showing the current user avatar/name, distribution,
window manager and uptime. Its two parts can be disabled independently:

```json
"dashboard": {
  "showAvatar": true,
  "showSystemSummary": true
}
```

Avatar metadata comes from **AccountsService** (`accountsservice` on Arch), not
from a direct `.face` lookup. The shell and greeter are read-only clients. Install
the service if you want account images; normal D-Bus activation starts it on demand.
The avatar follows account changes, including replacement of an image at the same
path. A missing daemon, unset/unreadable image or failed decode uses a neutral
user icon. Uptime refresh runs only while the summary is visible.

To set the system account image from a terminal, use AccountsService itself
(with your normal polkit authorization agent available):

```bash
account_path=$(busctl --system call org.freedesktop.Accounts \
  /org/freedesktop/Accounts org.freedesktop.Accounts FindUserById x "$(id -u)" \
  | cut -d '"' -f 2)
busctl --system call org.freedesktop.Accounts "$account_path" \
  org.freedesktop.Accounts.User SetIconFile s /absolute/path/to/avatar.png
```

`SetIconFile` copies the image into the account service's shared icon store.
The reader accepts shared paths under `/var/lib/AccountsService/icons`,
`/usr/share` and `/usr/local/share`, and rejects home paths and symlinks escaping
those roots. This lets the login screen display the image without home access or
ACL changes. In `/etc/greetd/greeter.json`, `showAvatar` independently controls the
selected-user avatar. It is hidden for manual username entry.

### Validation and persistent state

Changes to `config.json` apply automatically. Invalid edits keep the last valid
snapshot active; an invalid first launch uses bundled defaults. Once running:

```bash
shell-ctl config path
shell-ctl config validate
shell-ctl config state
```

The shell never writes your `config.json`. Runtime selections and toggles live in
`~/.config/quickshell/state.json` (or its XDG equivalent): wallpapers, dock pin
order, DND, caffeine, night light and gaming mode. Notification history and launch
frequency are stored separately. Wi-Fi/Bluetooth/VPN state comes from the system.
Package upgrades do not replace these user files.

## Start with uwsm

[uwsm](https://github.com/Vladimir-csp/uwsm) manages the graphical session,
activation environment and shutdown of its user services. This is the preferred
setup for the packaged service.

```bash
sudo pacman -S --needed uwsm
systemctl --user enable at1ass-shell.service
```

From your display manager choose **Hyprland (uwsm-managed)**. From a login TTY,
start the ordinary Hyprland desktop entry through uwsm:

```bash
exec uwsm start -- hyprland.desktop
```

Do not start another compositor from a terminal inside an existing graphical
session. The shell starts when `graphical-session.target` becomes active. You do
not need an additional `exec-once` for it in Hyprland.

For an already running uwsm session, start it now:

```bash
systemctl --user start at1ass-shell.service
```

Verify from a desktop terminal:

```bash
systemctl --user is-active graphical-session.target at1ass-shell.service
shell-ctl config validate
```

Both units should be active and validation should report no errors. If the shell
is skipped or cannot reach Hyprland, check that the user manager has
`WAYLAND_DISPLAY` and `HYPRLAND_INSTANCE_SIGNATURE`. Follow uwsm's
[environment/finalization instructions](https://github.com/Vladimir-csp/uwsm#readme)
for your compositor version; do not hardcode a display socket or instance ID.

## Start without uwsm

A plain Hyprland session does not automatically manage
`graphical-session.target`. For this setup, start the shell from Hyprland in a
separate systemd scope using the already required
[app2unit](https://github.com/Vladimir-csp/app2unit). This variant does not use
`at1ass-shell.service` or require uwsm.

Leave the packaged service disabled for this variant:

```bash
systemctl --user disable at1ass-shell.service
mkdir -p ~/.local/bin
```

Create `~/.local/bin/start-at1ass-shell`:

```sh
#!/bin/sh
set -eu

export XDG_CURRENT_DESKTOP="${XDG_CURRENT_DESKTOP:-Hyprland}"
export XDG_SESSION_TYPE=wayland

dbus-update-activation-environment --systemd \
  WAYLAND_DISPLAY DISPLAY HYPRLAND_INSTANCE_SIGNATURE \
  XDG_CURRENT_DESKTOP XDG_SESSION_TYPE

exec app2unit -c -t scope -s session.slice -u at1ass-shell.scope -- /usr/bin/at1ass-shell
```

Make it executable and add the following to `hyprland.conf`:

```bash
chmod +x ~/.local/bin/start-at1ass-shell
```

```conf
exec-once = ~/.local/bin/start-at1ass-shell
```

Start your ordinary Hyprland session through its display-manager entry or
`start-hyprland` from a login TTY. The script runs after Hyprland has created its
Wayland socket, imports the environment for D-Bus/systemd-activated applications,
and launches the shell outside the compositor's cgroup. `-c` avoids dependence on
`graphical-session.target`; the fixed scope name prevents duplicate instances.
The shell exits when the compositor's Wayland connection closes. This scope does
not provide the packaged service's automatic restart on failure.

For the first launch in an existing plain session, run
`~/.local/bin/start-at1ass-shell` from a desktop terminal. A Hyprland config reload
alone does not rerun `exec-once`. Check with:

```bash
systemctl --user status at1ass-shell.scope
shell-ctl config validate
```

Use exactly one startup method. When switching an existing installation between
service and scope, unlock first, stop the old instance, then start the chosen
method. Hyprland's Lua configuration users should express the same startup and
bindings through their compositor configuration API; the snippets here use the
classic `hyprland.conf` syntax.

## Finish session integration

### Audio, network and hardware services

Install only the optional features you use. For example, on a machine that will
use NetworkManager, Bluetooth and PipeWire:

```bash
sudo pacman -S --needed networkmanager bluez pipewire wireplumber pipewire-pulse \
  nm-connection-editor blueman pwvucontrol
sudo systemctl enable --now NetworkManager.service bluetooth.service
systemctl --user start pipewire.socket wireplumber.service
```

Keep your existing network/audio stack if it already works; do not start competing
network managers or session policy managers. The shell consumes their state and
does not configure them during installation. UPower normally starts through D-Bus
when installed. DDC/CI brightness additionally needs display support and device
permissions; installing `ddcutil` alone is insufficient.

The Connections panel handles Wi-Fi, Bluetooth and saved VPNs. Advanced profile
creation, certificates and editing open **nm-connection-editor**. Audio's
**Advanced audio…** action opens **pwvucontrol**.

The integrated network secret agent is enabled by default. Verify:

```bash
at1ass-shell ipc call networkauth registered
```

It should report `true`. Agent-owned saved credentials require a running,
unlocked Secret Service provider such as gnome-keyring; `libsecret` alone is not
a keyring daemon. Configure its startup/PAM unlocking for your login method.
OpenVPN prompts additionally need `networkmanager-openvpn`. Other VPN plugins and
WireGuard-specific credential prompts do not have full parity with nm-applet.

When migrating, test the networks/VPNs you use before disabling nm-applet.
Remove its explicit autostart or use a user XDG autostart override with
`Hidden=true`. To keep it as your authentication agent, set
`connections.networkAgent: false`. Bluetooth has a separate
`connections.bluetoothAgent` switch; integrated pairing covers devices selected
in Connections, rather than taking ownership as BlueZ's global default agent.
Keep an external Bluetooth agent if you need unsolicited pairing requests.

### Avoid duplicate session components

Remove old autostart commands/services for components replaced by this shell:
another bar/dock, notification daemon, wallpaper daemon or an old Quickshell
checkout. If another notification server is running, only one can own its D-Bus
name. Hiding an applet's tray icon does not stop the applet or its auth agent.

Polkit authorization is independent of network credential storage. Either keep an
external agent such as hyprpolkitagent, or enable `modules.polkit` and stop the
external one. The built-in agent is **off by default**; run one agent per session.

### Keybindings

The package does not modify Hyprland bindings. Add or adapt these to your config:

```conf
bind = SUPER, SPACE, global, quickshell:launcherToggle
bind = SUPER, W, global, quickshell:overviewToggle
bind = SUPER, N, global, quickshell:connectionsToggle
bind = SUPER, A, global, quickshell:audioToggle
bind = SUPER, Escape, global, quickshell:powerMenuToggle
bind = SUPER, F1, global, quickshell:cheatsheetToggle
bind = SUPER, D, exec, at1ass-shell ipc call globalstates toggleDashboard
bind = SUPER, L, exec, at1ass-shell ipc call globalstates lockScreen

bind = , XF86AudioRaiseVolume, global, quickshell:audioVolumeUp
bind = , XF86AudioLowerVolume, global, quickshell:audioVolumeDown
bind = , XF86AudioMute, global, quickshell:audioToggleMute
bind = , XF86MonBrightnessUp, global, quickshell:brightnessUp
bind = , XF86MonBrightnessDown, global, quickshell:brightnessDown
bind = SUPER, Print, global, quickshell:screenshot
bind = SUPER SHIFT, Print, global, quickshell:screenshotSwappy
```

The lock binding requires `modules.lockscreen: true`. Choose free key combinations
and remove conflicting existing bindings. The `quickshell:` namespace identifies
global shortcuts; it does not change when the config is installed as a package.
IPC commands target the installed instance via `at1ass-shell`, not `qs -c shell`.

### Lockscreen and idle policy

The built-in lockscreen is **disabled by default**. Enable it before pointing
lock/suspend automation at it:

```json
"modules": { "lockscreen": true }
```

If you keep an external locker, leave this module disabled and retain that
locker's hypridle commands. Shell lock requests with the module disabled do not
lock the session. The greeter is a separate login screen and does not replace a
session locker.

For the built-in locker, install `hypridle` and configure
`~/.config/hypr/hypridle.conf`:

```conf
general {
    lock_cmd = /usr/bin/at1ass-shell ipc call globalstates lockScreen
    before_sleep_cmd = loginctl lock-session
    inhibit_sleep = 3
}

listener {
    timeout = 600
    on-timeout = /usr/bin/at1ass-shell ipc call globalstates lockScreen
}
```

`inhibit_sleep = 3` waits for the compositor's lock notification before allowing
sleep. Start hypridle after the shell is available. With uwsm:

```bash
systemctl --user enable --now hypridle.service
```

Without uwsm, add the following to Hyprland and leave `hypridle.service`
disabled:

```conf
exec-once = app2unit -c -t scope -u at1ass-shell-idle.scope -- hypridle
```

Keep only one idle daemon. Test a manual lock and unlock before relying on
automatic locking/suspend on a new machine.

### Clipboard, capture and calendar

For clipboard history, install `cliphist` and `wl-clipboard`, then add these
watchers to Hyprland (do not duplicate watchers you already have):

```conf
exec-once = app2unit -c -t scope -- wl-paste --type text --watch cliphist store
exec-once = app2unit -c -t scope -- wl-paste --type image --watch cliphist store
```

Screenshots need `grim` and `wl-clipboard`; annotation adds `swappy`. Recording
needs `gpu-screen-recorder` **and its `gsr-cli` executable**, a supported encoder,
and `procps-ng`. The default portal capture mode also needs PipeWire,
`xdg-desktop-portal` and its Hyprland backend, with a correct session environment.

Calendar reads local iCalendar stores, by default
`~/.local/share/khal/calendars`, and can use existing khal calendar definitions.
CalDAV synchronization belongs to an external tool such as vdirsyncer; the shell
does not store server credentials or set up synchronization.

## Use the shell

The bar opens the relevant panel; the dashboard contains Quick, Weather and
Calendar. Audio and Connections have separate panels. Panels open on their source
or focused monitor and stay there while open. Notification output policy is
configured separately by `notifications.popup.monitor`.

### CLI and keyboard

```bash
shell-ctl help
shell-ctl status
shell-ctl launcher
shell-ctl dashboard
shell-ctl notifications
shell-ctl dnd for 30
shell-ctl caffeine for 60
shell-ctl wall next
at1ass-shell ipc call globalstates toggleOverview
at1ass-shell ipc show
```

Caffeine inhibits automatic idle actions through the session D-Bus
`org.freedesktop.ScreenSaver` service provided by hypridle. Keep
`ignore_dbus_inhibit = false` in hypridle. The dashboard marks Caffeine active only
after the service confirms the request; failures remain visible with a Retry action.
The requested mode and its deadline survive shell restarts. Manual locking and
locking before suspend remain available. Inspect requested and confirmed state with
`at1ass-shell ipc call caffeine status`; use `caffeine retry` after a failure.

`shell-ctl help` discovers available handlers and signatures from the running
instance. `shell-ctl <handler> <function> [argument]` can call them directly.
`at1ass-shell` always addresses `/usr/share/at1ass-shell`, including for IPC.

Tab/Shift+Tab traverse controls, Enter/Space activate, and Escape closes the
nearest menu/dialog before the panel. Dashboard tabs use Ctrl+Tab/Ctrl+Shift+Tab;
calendar arrows or H/J/K/L move between days when its date grid has focus.
Letter shortcuts use physical key positions across keyboard layouts.

| Launcher input | Action |
|---|---|
| Application name | Search installed desktop entries, with remembered launch frequency |
| `= expression` | Calculate with Qalculate |
| `> text` | Search clipboard history |
| `: action` | Search shell actions |
| `@ text` | Find an open window by title, application or workspace and switch to it |

Tab/Shift+Tab select launcher results while keeping the search field focused;
Enter activates the result. The launcher resets its query when reopened.

The `:` catalogue includes panels, workspace overview, screenshot copy/edit,
screen recording (start/stop and pause/resume), night light, gaming mode, DND
and caffeine. Search aliases include `: windows`, `: nightlight` and `: awake`.
Toggle names describe the next action and update while the launcher is open.
Missing recorder/night-light dependencies leave a readable unavailable result;
selecting it shows the full reason below the list. Disabled modules are excluded.
Each action rechecks its state and availability before execution. Applications
remain the default search scope; shell action text is never executed as a command.

Add frequently used commands under `launcher.actions` in your `config.json`:

```json
{
  "launcher": {
    "actions": {
      "audio-mixer": {
        "name": "Audio mixer",
        "description": "Open pwvucontrol",
        "icon": "multimedia-volume-control",
        "keywords": ["sound", "mixer", "звук"],
        "command": ["pwvucontrol"]
      },
      "files": {
        "name": "Files",
        "desktopEntry": "org.kde.dolphin"
      }
    }
  }
}
```

Merge this section into the existing config and use programs installed on your
system. Search with `: mixer`, `: звук` or `: files`. The object keys are stable
action IDs; custom actions cannot replace built-in actions. `name` and exactly
one of `command` or `desktopEntry` are required. Description, icon and keywords
are optional; `enabled: false` hides an action. Changes apply immediately.

`command` is an argv array: the executable followed by separate literal arguments.
Spaces inside an argument are preserved; `$HOME`, `~`, pipes and the search query
are not expanded. For compound operations, call your own script. `desktopEntry`
uses the exact Quickshell ID, without the final `.desktop` file extension
(`org.kde.dolphin.desktop` becomes `org.kde.dolphin`). Terminal entries follow the
normal application launch path. Missing desktop entries remain visible with an
explanation and become available when installed. Both launch paths use
`AppLaunchService` and app2unit. A command executable must be installed/on PATH
(or named by its absolute path); command execution errors are not preflighted by
spawning probes during search.

### Timer and Pomodoro

Dashboard **Quick** contains a compact timer block. Start the default countdown
or Pomodoro, then pause/resume or stop it in the same place. The launcher offers
configured countdown presets, `: timer 23` for an arbitrary whole-minute duration,
`: pomodoro`, `: pause timer`, `: resume timer` and `: stop timer`.

Configure defaults in `config.json`:

```json
{
  "timers": {
    "enabled": true,
    "showInDashboard": true,
    "defaultMinutes": 10,
    "presetsMinutes": [5, 10, 25],
    "notify": true,
    "pomodoro": {
      "workMinutes": 25,
      "shortBreakMinutes": 5,
      "longBreakMinutes": 15,
      "cyclesBeforeLongBreak": 4
    }
  }
}
```

One countdown or Pomodoro cycle runs at a time. Pomodoro automatically alternates
work and short breaks, uses a long break after four work intervals by default,
then repeats until stopped. Each duration accepts 1–1440 minutes. Duration
changes apply to the next run; active runs retain their duration snapshot.

Runtime state is saved in `state.json`. Pause freezes elapsed time; sleep and
shell downtime count toward a running timer. After resume/restart, Pomodoro
calculates the current phase and sends at most one catch-up notification. An
expired countdown stays finished. Notifications use normal urgency and follow
the existing DND/history policy. Second-by-second display updates run only while
the Dashboard block is visible. `showInDashboard: false` hides the block while
keeping IPC/launcher control; `enabled: false` pauses a run until manually resumed.

```bash
at1ass-shell ipc call timer start 10
at1ass-shell ipc call timer pomodoro
at1ass-shell ipc call timer pause
at1ass-shell ipc call timer resume
at1ass-shell ipc call timer stop
at1ass-shell ipc call timer status
```

Mutating calls return a boolean; starting another run while one is active returns
false. `status` returns JSON with the current phase, remaining time and state.

### Recovering failed operations

Weather keeps the last successful readings and the failure explanation while
retrying. Use **Retry** in the weather tab; it is disabled during
a request or while updates are paused by gaming mode. Successful updates clear
the error. Changes to coordinates/units cancel the old request and discard its
dataset, so old values cannot appear under new labels.

VPN failures remain visible when reopening Connections, with the profile name.
**Retry** in the VPN section repeats the original profile UUID and connect/disconnect
direction. It rechecks that the profile exists, its state still needs the action
and no operation is running. Deleted profiles explain why retry is unavailable;
the connection editor remains accessible from **More connection actions**.
Success, including a later observed completion, clears the failure.

Technical details are available as JSON through IPC:

```bash
at1ass-shell ipc call weather status
at1ass-shell ipc call vpn status
```

Both handlers also expose `retry`; it returns false when the operation cannot
be repeated. Weather diagnostics include the transport/response error, and VPN
diagnostics include the failed UUID and nmcli exit code.

Recording and night-light failures remain available in Dashboard Quick, with
Retry where the target is still valid. Launcher actions also expose recovery.
Recording pause/resume is confirmed after the control command succeeds; replies
for an old recording cannot change a newer recording's state. Night light keeps
its failure explanation through automatic restarts until the process has stayed
healthy; the enabled mode remains switchable even if its executable disappears.
Use `nightlight status`, `nightlight retry`, `recorder diagnostics` and
`recorder retry` through `at1ass-shell ipc call` for diagnostics/recovery.

### Notification history

Search the application name, title and body in the notification centre. Ctrl+F
focuses search; **All time / Today / Last 7 days** restrict the current view.
Filtered groups initially expand to reveal matches; these expansion choices stay
local to the search. Retention and grouping policy remain in `config.json`.

Use the copy icon to copy the title and plain text body. Removing one message
offers Undo, just like **Clear all**; Ctrl+Z works when focus is outside the search
editor. Clear all still clears the entire history, including rows hidden by a
filter. Undo restores history content; it does not recreate expired application
notifications or make their old actions live again.

### Battery warnings

Battery state and warnings work independently of the bar widget. The widget's
tooltip includes UPower's remaining-time estimate when available. Configure:

```json
{
  "battery": {
    "warnings": {
      "enabled": true,
      "lowPercent": 15,
      "criticalPercent": 5,
      "hysteresisPercent": 3
    }
  }
}
```

The critical threshold is capped to the low threshold. A warning is rearmed after
the charge rises by the configured hysteresis above its threshold, or charging
starts. Saved warning markers prevent repeated alerts after shell restarts.
Low warnings follow DND; critical warnings use critical urgency. Obsolete queued
warnings are cancelled after recovery. `at1ass-shell ipc call power status`
reports battery state, remaining time and notification delivery diagnostics.

### Calendar editing

Dates use strict local `yyyy-MM-dd` input: impossible days/months are rejected
rather than silently moved to another date. Field errors explain invalid dates,
times, ordering and repeat-until limits; all-day end dates remain inclusive in the
form and exclusive in calendar storage. The initial one-hour event can cross
midnight without producing an invalid end date.

Saving keeps the editor open until the calendar backend confirms the write.
While saving, editing and duplicate submissions are disabled. On failure, the
draft remains in the form with an error and Retry action. A failed unrelated or
previous operation cannot close the current editor. Cancelling the recurrence
scope question also retains the pending field/time changes.

Calendar icons next to the date fields open a keyboard-accessible picker while
preserving manual input. Arrows or physical H/J/K/L move between days; Enter/Space
selects a date. Cancelling leaves the field unchanged and returns focus to it.

The calendar tab also provides event search (Ctrl+F) across the displayed one-year
range around the viewed month. It searches title, description, location and
calendar name, including recurring occurrences. Select a result to jump to its
date. Results are chronological and bounded; refine the query if the first 20
results do not include the desired event. **Upcoming events** expands a short
agenda for the next 14 days. Search and agenda use a separate asynchronous request
and do not replace the month/day data.

### Workspace overview

Search windows by title, application or workspace. Click a live preview or press
Enter to focus it. Disable `overview.showPreviews` to show icons/titles without
capture buffers.

| Input | Action |
|---|---|
| Alt+H / Alt+L | Select workspace, including while typing in search |
| Alt+J / Alt+K | Select window |
| Ctrl+M / right-click window | Choose a destination workspace |
| Drag window onto a workspace | Move window without leaving overview |
| Ctrl+W / preview close button | Request normal window close |
| Ctrl+Shift+M / workspace header menu | Move workspace to monitor or transfer its windows to another number |

Bare H/J/K/L also navigate outside the search editor. Closing does not force-kill
an application; its unsaved-changes dialog can still appear. Moving to another
monitor keeps the workspace number/layout. Transferring to another number moves
all its windows, merging into an occupied target; Hyprland determines placement
and the original tiling tree is not preserved.

### Workspaces in the bar

Each workspace has a persistent number. Occupied workspaces group their application
icons beside that number; the active workspace has the configured pill/dot marker,
and the active window has its own highlight/underline. Hover an icon for the app,
window title and workspace. Hit areas remain larger than the icon drawing; hover
never changes the bar width. Compact presentation retains workspace numbers.

Click a number to switch workspace, or an icon to focus its window. Right-click a
group/window opens Overview at that workspace (unless a custom clickAction is
configured); click `+N` to view additional windows in Overview. Previews are
created by Overview according to `overview.showPreviews`, not by bar hover.

The workspace widget is one Tab stop. After focusing it, physical H/L or Left/Right
select a workspace, J/K or Down/Up select a window, Enter/Space activates selection,
and Menu/Shift+F10 opens the workspace context action. Escape returns selection to
the workspace number; Tab/Shift+Tab leave the widget. Letter keys follow physical
positions across keyboard layouts. These commands operate while the bar has focus;
they do not install global shortcuts.

### Bar, tray and lockscreen

`bar.widgets` controls order, monitor visibility, `enabled`, `clickAction` and
widget-specific `settings`. Available types are `workspaces`, `activewindow`,
`weather`, `clock`, `media`, `notifications`, `volume`, `network`, `battery`,
`layout` and `tray`. The network and battery widgets are disabled in bundled
defaults; enable their entries if needed. Useful click actions include
`dashboard-quick`, `dashboard-weather`, `dashboard-calendar`, `audio`,
`connections`, `connections-wifi`, `connections-bluetooth`, `overview`,
`notification-center` and `launcher`.

The tray's `settings.maxVisible` defaults to 4; excess icons go into overflow.
Use 0 for overflow-only, and `settings.pinnedIds` to prioritize exact tray IDs.
These settings limit bar space; they do not disable the applications.

The lockscreen has no notifications. Media title/controls are available when a
player exists. `lockscreen.showMedia`, `showClock`, `showDate`, `showPower`,
`showBattery`, `showWeather`, `showNetwork` and related schema fields control its
content. Necessary authentication feedback always remains visible.

## Optional greetd greeter

The greeter is independent of your shell config and runs as the `greeter` user.
Install it only if you want to use greetd as your login manager:

```bash
paru -S --aur at1ass-shell-greeter-git
```

Review these root-owned files:

| File | Purpose |
|---|---|
| `/etc/greetd/config.toml` | greetd session/VT configuration; not replaced by the package |
| `/etc/greetd/hyprland-greeter.lua` | Lua configuration for the separate Hyprland instance; generic monitor defaults |
| `/etc/greetd/greeter.json` | Appearance, visible content, default user/session |

In `/etc/greetd/config.toml`, configure the greeter command, keeping the other
settings appropriate for your system:

```toml
[terminal]
vt = 1

[default_session]
command = "start-hyprland -- -c /etc/greetd/hyprland-greeter.lua"
user = "greeter"
```

The separate compositor configuration launches the installed QML greeter. The
optional `greetd-regreet` package provides its fallback if Quickshell fails.

The greeter compositor template targets Hyprland 0.57+ and uses Lua. The package
also keeps `/etc/greetd/hyprland-greeter.conf` as a small Lua compatibility entry
point that loads the `.lua` file, so existing greetd commands continue to work.
New installations should use the `.lua` path above.

Pacman preserves local edits. If you customized the old `.conf`, move its display
settings into the `.lua` file, convert any old hyprlang syntax and update the
command in `config.toml`. Review `.pacnew` files before switching: a locally
modified `.conf` is preserved rather than automatically replaced by the wrapper.
Logo/splash options belong to `misc`; the full guiutils option name is
`disable_hyprland_guiutils_check`. See the installed
`/usr/share/hypr/stubs/hl.meta.lua` for the options supported by your version.

Validate the file you actually use before leaving the current desktop:

```bash
Hyprland --verify-config -c /etc/greetd/hyprland-greeter.lua
```

`tools/test-greeter.py` also checks the bundled compositor template using this
validator when Hyprland is available and the tests run as a non-root user.

The login screen discovers sessions from system `wayland-sessions`/`xsessions`
directories. For uwsm, choose **Hyprland (uwsm-managed)**; without uwsm, choose
**Hyprland** and use the startup integration above. Set `defaultSession` in
`greeter.json` to the displayed session name if desired. Unlike this login
manager, the discovery code does not read user-home session definitions.

Wallpaper paths must be readable by the greeter. Put an image in `/etc/greetd`
and set `wallpaperPath` to it; do not point at a private home or change its ACLs.
The greeter has its own schema at
`/usr/share/at1ass-shell/greeter/config/greeter.schema.json`. See the
[greeter reference](src/features/greeter/README.md) for fields and authentication
behaviour. Its settings do not inherit from the user's `config.json`.

After reviewing the setup, disable your previous display manager's boot
activation and enable greetd for the **next boot**:

```bash
sudo systemctl enable greetd.service
```

Do not run two display managers on the same VT. Enabling does not require
restarting greetd or ending the current desktop. Both package-owned
`/etc/greetd` configuration files preserve local edits through pacman's backup
handling; review `.pacnew` files after upgrades.

## Update and troubleshoot

### Updating packages

This is a VCS (`-git`) package. Use your helper's development-package update mode
or explicitly rebuild it to get newer source; do not rely only on the version
shown in AUR metadata. Versions derive from release tags: `v0.1.0` produces
`0.1.0.r0.g<hash>`; twelve commits later the version is `0.1.0.r12.g<hash>`.
The distance from the tag orders development builds; the hash identifies their
source. All normal release tags use `vMAJOR.MINOR.PATCH` and remain immutable.
Keep installed shell, plugin and greeter packages at matching
versions. Include `at1ass-shell-greeter-git` if installed, and ensure the matching
plugin package is upgraded in the same transaction. Build as your normal user.
The following examples stop the shell before asking paru to rebuild/install.
`--aur` explicitly selects the public AUR recipe: with paru's LocalRepo enabled,
a repository such as `[aur]` can otherwise supply an older prebuilt package even
when `--rebuild` is specified. Include all three installed split packages when
forcing a development rebuild.

**Before installing replacement native plugins, unlock the session and stop its
shell and idle daemon.** Replacing loaded `.so` files can crash the running shell;
a crash while locked can leave Hyprland without a usable lock client. Never
restart the shell while `globalstates locked` reports `true`:

```bash
at1ass-shell ipc call globalstates locked
```

For the service setup, after confirming `false`:

```bash
systemctl --user stop hypridle.service at1ass-shell.service
paru -S --aur at1ass-shell-git at1ass-shell-plugins-git --rebuild
# Include at1ass-shell-greeter-git above if you have it installed.
systemctl --user daemon-reload
systemctl --user start at1ass-shell.service
# Only if you use hypridle:
systemctl --user start hypridle.service
```

For the scope setup, after confirming the session is unlocked:

```bash
# Only if you use the idle scope configured above:
systemctl --user stop at1ass-shell-idle.scope
systemctl --user stop at1ass-shell.scope
paru -S --aur at1ass-shell-git at1ass-shell-plugins-git --rebuild
# Include at1ass-shell-greeter-git above if installed.
~/.local/bin/start-at1ass-shell
```

Then restart your idle command from another terminal (the scope launcher stays
attached while the shell runs). A checkout's QML edits do not change the installed
runtime; package updates do not require copying anything into `/usr/share` by hand.

### Diagnostics

```bash
shell-ctl status
shell-ctl config validate
at1ass-shell ipc call networkauth registered
systemctl --user status at1ass-shell.service
journalctl --user -u at1ass-shell.service -b
```

For the non-uwsm setup, use `at1ass-shell.scope` in the status/journal commands
instead. A scope's application output also follows the compositor's output;
for interactive diagnostics, launch the startup script from a desktop terminal.

| Symptom | Check |
|---|---|
| Service skipped / no Wayland display | Correct session startup and activation environment; no hardcoded socket/instance IDs |
| Two bars or IPC reaches an old shell | Remove old checkout/service autostart; use `at1ass-shell` or installed `shell-ctl` |
| Configuration change ignored | `shell-ctl config validate`; strict JSON and schema path |
| No network or Bluetooth devices | Running system service, hardware/rfkill state and supported adapter |
| No VPN rows | `services.vpn.enabled: true`, saved NetworkManager VPN profiles |
| Credentials repeatedly requested | Agent registration and an available/unlocked Secret Service provider |
| No audio devices | Running PipeWire and WirePlumber |
| Empty clipboard history | Running `wl-paste` ingestion watchers |
| Lock command does nothing | `modules.lockscreen` is off by default; enable it or configure an external locker |
| Recording cannot start | `gsr-cli`, encoder support, PipeWire and the selected portal backend |

### Migrating an old checkout installation

Keep user config/state, but remove old startup entries and convert
`qs -c shell ipc call …` to `at1ass-shell ipc call …`. Stop the old shell while
unlocked before installing plugins. Disable the old `quickshell.service`, then
select one startup method above. Retain the checkout only for development.

Existing greetd installations should back up their `/etc/greetd` settings and
review the new defaults without discarding machine-specific output/session
settings. Hyprland 0.56 uses `hyprctl dispatch 'hl.dsp.exit()'` for the greeter's
compositor exit command.

For an assisted migration from a development checkout, the repository contains
`tools/install-from-aur.sh` and `tools/migrate-installed.py` (preview by default).
Review their output before applying; they preserve user config and save backups
under `$XDG_STATE_HOME/at1ass-shell/migrations`.

## Development

```bash
git clone --recurse-submodules https://github.com/At1ass/shell.git
cd shell
```

The architecture is `plugins → config → services → features`, with the shared UI
kit depending only on config. QML lives under `src/core`, `src/ui` and
`src/features`; seven C++17 plugins live under `src/plugins`.
Read [AGENTS.md](AGENTS.md) before changing code.

To build packages from a committed local revision without changing the public
AUR recipe:

```bash
tools/build-arch.sh /tmp/at1ass-shell-build
```

The helper does not install packages. `python3 tools/check-package.py --help`
describes installed-payload checks. For release validation, build the public
recipe in a clean chroot with devtools; a successful build on a configured desktop
does not establish that all build dependencies were declared.

For an explicit development instance, use `qs -p /absolute/path/to/checkout` and
that checkout's `tools/shell-ctl`. Stop the installed instance first while unlocked.
Do not use `cmake --install` over pacman-owned plugins.

Relevant checks:

```bash
tools/lint.sh path/to/changed.qml
tools/check.sh
tools/compile-check.sh
python3 tools/test-ui.py
python3 tools/test-package-migration.py
```

Native unit tests and feature-specific probes are documented in AGENTS.md.
The private D-Bus notification probes in `tools/test-timers.py` and
`tools/test-power.py` additionally need `python-gobject` (Gio) and the D-Bus
daemon/tools. These are development dependencies. `session_idle_test` starts its
own private bus; it never contacts the user's real idle service.
On slower test hardware, use `SHELL_UI_TEST_TIMEOUT=300 python3 tools/test-ui.py`
to extend the total QtTest-suite deadline. Individual control assertions keep
their own deadlines. QtTest arguments can be passed through for focused runs,
for example `python3 tools/test-ui.py ShellControls::test_event_form_keyboard_scroll`.
Tests must not move/close real windows, change the user's connections or invoke
host lock/power actions.

## License

Original shell code and plugins: **GPL-3.0-or-later**, see [LICENSE](LICENSE).
Material Color Utilities retains Apache-2.0; RapidFuzz retains MIT. Their notices
are included in the native plugin package. The shell is independently implemented,
with pointwise attributed inspiration from Caelestia and other configurations.
