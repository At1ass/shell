# ROADMAP

Open work. The active stream is the root-cause refactor below; feature extensions are deferred behind it.

Recent history that informs the items below:
- 2026-08: **layer/module audit** — layer graph verified clean (no back-edges); seven behavioural defects found and fixed (see below). Root cause of the two largest: assumptions about Qt/Quickshell behaviour encoded into shared infrastructure and then guarded by tooling that shared the same assumption.
- 2026-07: **full-project audit** (all QML + all 5 C++ plugins, architecture, config contract, MD3, security). ~120 verified findings distilled into the phased refactor plan below. Former Tier 1–3 quick-fix lists were folded into the phases.
- `feat(config): unify per-feature enabled flags into modules on/off map` — every top-level UI element is now toggled via `modules.*`
- `fix(calendar): adopt libical 4.0 refcounted rrule; fix all-day overlap`
- MD3 overhaul (`md3-overhaul` branch): elevation, pixelSize typography, pill buttons, MaterialSwitch/MaterialText adoption, greeter UI kit unified via `sync-ui.sh`
- Notifications subsystem split into 4 focused singletons; wallpaper subsystem with pluggable provider model + Wallhaven
- Decision: **config-first, no GUI** — settings only via `config.json` + IPC (see `AGENTS.md` §0/§10)

---

## What each feature costs on a weak machine (2026-08)

CPU consumed by the shell for one action, sampled from its own utime+stime,
same script on both machines, each action confirmed by its layer surface
actually appearing.

| действие | 9950X3D | N3050 | x |
| --- | --- | --- | --- |
| дашборд Quick | 180 мс | 580 мс | 3.2 |
| дашборд Weather | 30 мс | 390 мс | 13 |
| дашборд Calendar | 60 мс | 500 мс | 8.3 |
| дашборд Audio | 60 мс | 290 мс | 4.8 |
| дашборд Network | 30 мс | 270 мс | 9 |
| лаунчер | 70 мс | 500 мс | 7.1 |
| центр уведомлений | 60 мс | 400 мс | 6.7 |
| читшит | 80 мс | 730 мс | 9.1 |
| смена обоев + палитра MCU | 270 мс | 770 мс | 2.9 |
| **первая всплывашка уведомления** | **220 мс** | **2710 мс** | **12.3** |
| каждая следующая в очереди | ~25 мс | ~660 мс | ~26 |

**The notification popup was the outlier — and it is now fixed.** Showing one
popup cost 2.7 s of CPU on two 1.6 GHz cores. The cost turned out to be per
UPDATE, not per popup: it scaled linearly with how long the popup stayed on
screen (1 s -> 580 ms, 7 s -> 2690 ms), while a popup sitting there with its
countdown disabled cost 30 ms over 8 s.

The countdown was a NumberAnimation spanning the whole duration, so
`progressValue` changed every frame and each change repainted and committed the
popup's whole layer surface. A 10 Hz Timer instead: **2500 ms -> 820 ms** on
the N3050, and 70 ms on the 9950X3D. Second, smaller cause: ProgressIndicator's
circular Canvas tracked `value` whatever the type was, so a linear indicator
drove a hidden software repaint per update (2690 -> 2500 ms). See commit
`bae71a34`.

Wallpaper rotation turned out **cheap**, against my expectation that MCU palette
extraction would dominate: 770 ms on the N3050, under 3x the desktop. The
prediction was wrong and the measurement corrected it.

**Confirm the action happened, every single time.** Two conclusions in this
investigation were drawn from runs where the popup never appeared, and both
were wrong — including a "the Timer changes nothing, revert it" that would have
thrown away the actual fix. Cost harnesses must assert the thing they are
timing actually occurred (here: the `shell:notification-popup` layer surface
appeared) and print that assertion next to the number.

**Harness lesson, hit three times before it was believed.** A detached process
on the remote machine inherits no Wayland environment, so `qs ipc` silently
addresses nothing and `hyprctl` stays quiet — panels never open and every
action measures as suspiciously cheap. Always export `WAYLAND_DISPLAY` and
`HYPRLAND_INSTANCE_SIGNATURE` explicitly, and **confirm the action happened**
(the expected layer surface appeared) before believing a number. The same class
of silent failure produced "80 keystrokes cost less than idle" twice, and a
`hyprlock` grab that swallowed synthetic input into a password field once.

---

## Design packs: the minimal pack is not cheaper (2026-08)

Measured on the N3050 under both packs, median CPU ms per action, every run
confirmed by the panel's layer actually appearing.

| action | md3 | minimal | as shipped | md3 @0.55 | minimal | equal durations |
|---|---|---|---|---|---|---|
| launcher | 510 | 420 | **-18%** | 405 | 390 | -4% |
| cheatsheet | 790 | 730 | **-8%** | 685 | 705 | +3% |
| dashboard | 510 | 440 | **-14%** | 470 | 475 | +1% |
| notification | 720 | 660 | **-8%** | 675 | 645 | -4% |

The left half compares the packs as they ship. The right half equalises the
animation duration - MD3 at `motionScale: 0.55` against the minimal pack, whose
own 0.55 multiplier lands on the same effective durations - and the difference
collapses to between -4% and +3%, with the sign flipping between actions.
Repeat-to-repeat spread inside one configuration was 10-80 ms, larger than what
is left.

**The whole saving is the shorter animation.** Dropping the shadow `Loader`,
flattening the corners and drawing a hairline border is performance-neutral on
the weakest hardware here. The saving is also not exclusive to the pack:
`appearance.motionScale` buys exactly the same thing under MD3.

This falsifies the performance argument written into the original design
research; the artifact has been corrected. Pick the pack for how it looks. If
the goal is a cheaper shell, turn the motion scale down, and that decision is
independent of the design system.

RSS was not established either way - it drifted in both directions during the
runs, and this shell has an open memory-growth investigation that makes a single
sample worthless.

---

## Power menu review (2026-08)

The dangerous part is fine. `executePowerAction` builds argv arrays
(`["systemctl", "poweroff"]`) with no shell in the path, closes the panel
before it fires, guards against a second concurrent action, and routes logout
through `HyprlandDispatch`. Confirm-on-destructive is a config key, the action
list is config-ordered, and the hotkeys go through `Keycodes` so they survive a
non-Latin layout.

What was broken was the motion, and not only here. Every overlay panel sits
behind a `LazyLoader` gated on its own open flag, so the panel is **created**
with that flag already true — and a `Behavior` never runs for a value computed
during initialization. Six animation declarations across four files were dead
code: the shared `Scrim`, the power menu's opacity and scale, the launcher's
fade and slide, the cheatsheet's opacity and scale. Each panel appeared fully
formed in one frame.

Measured, not assumed. Frames 74 ms apart on the N3050 after opening the power
menu, as a fraction of the transition:

| | o0 | o1 | o2 | o3 | o4 | o5 |
|---|---|---|---|---|---|---|
| before | 0.00 | 0.00 | **1.00** | 1.00 | 1.00 | 1.00 |
| after | 0.00 | 0.00 | 0.66 | 0.84 | 0.92 | 1.00 |

Before the fix o2-o5 were byte-identical to the settled frame (mean abs delta
0.00) against a declared 400 ms — no intermediate frame existed. The launcher
on the desktop now runs 0.16, 0.49, 0.79, 0.92, 1.00.

Fixed in commit 75b9e8e8 with a `_ready` flag that holds each binding at its
start value for one pass. Doing it inside `Scrim` fixed the scrim for all four
panels at once.

**Exit is still instant** and stays that way for now: the loader destroys the
panel the moment the flag drops, so there is nothing left to animate. Making
exit real means keeping panels resident past close, which is the same
RAM-versus-latency decision still open from the memory work — worth taking as
one decision rather than four hacks.

---

## Lockscreen review (2026-08)

This module is the real locker on the desktop: hypridle's `lock_cmd` and its
idle timeout both call `qs ipc call globalstates lockScreen`, and `check.sh`
still carries the scar of a config load failure that took the shell down while
it held the session lock. Reviewed accordingly.

Fixed (commit 281cc441):

- **Enter could silently do nothing.** `onAccepted` called `pam.start()` and
  discarded the result. Every other `start()` in the file checks it and arms
  `pamRetryTimer`; this one did not, so a failed start left no auth in flight,
  no error on screen and no retry pending.
- **The plaintext outlived the attempt.** A failure cleared the visible field
  but not `_pendingPassword`, so a PAM stack that failed before ever asking for
  a response left the password in that string for the rest of the lock.
- **The date was frozen.** `Qt.formatDate(new Date(), ...)` is not a binding —
  evaluated once when the surface appeared. Lock before midnight, unlock after,
  and the date was wrong. `DateTime.clock` already drives the clock above it.

Two things looked at and deliberately left alone:

- **One `PamContext` per screen.** `WlSessionLockSurface` is instantiated per
  output, so a two-monitor desktop opens two `login` conversations for the whole
  lock. It is waste rather than a defect, and it is why typing works from either
  screen: whichever surface the compositor focuses answers with its own context.
  Hoisting PAM into a service would centralise the error state at the cost of
  that property.
- **logind `Unlock` drops the lock with no authentication.** The DBus listener
  in `GlobalStates` honours `Unlock` as well as `Lock`, so `loginctl
  unlock-session` opens the session without a password. hyprlock and swaylock do
  not honour it. It is also the only recovery path if the shell dies while
  holding the lock, which is a failure this repo has actually had — so the
  trade-off is deliberate, but it is a trade-off: any code already running as
  the user can end the lock. **Not tested live** — the check would have meant
  locking a session and unlocking it without the password, so it stands on
  reading `GlobalStates.qml:146-165`, not on a measurement.

Verified absent: there is no `unlock` IPC function, so PAM success and that
logind signal are the only two ways out.

---

## OSD review (2026-08)

Nothing to fix. The module gets the things the rest of the shell had to learn
the hard way already right:

- one `PanelWindow` per screen via `Variants` with `screen: modelData`, which
  is the documented way to stop the compositor mapping every copy onto one
  output;
- `visible: shown || opacity > 0.01`, so the fade-out actually plays — the
  idiom the popouts card still lacks;
- the toast queue is bounded at 16 and written as a fresh array each time,
  because assigning a `var` back to itself is not a change notification;
- every toast duration has a fallback, so no path can set a zero interval.

Verified in use on both machines: a volume change raises the OSD on **every**
screen (2 surfaces on the desktop, 1 on the laptop), shows icon/title/percent
with the bar, and clears on the 2 s timeout. Cost on the N3050: **220-250 ms**
per show, three repeats, each confirmed by the surface appearing — the cheapest
panel-class action measured, against 500-600 ms for the launcher, Quick tab and
cheatsheet.

Observed and deliberately left alone: when toasts are queued, `hideTimer` sets
`shown = false` and calls `_showNext()` in the same handler, so a queued toast
replaces its predecessor with no fade between them. It only shows up during a
toast burst, and adding a gap would change timing behaviour to fix something
nobody has reported seeing.

---

## Cheatsheet and Quick tab: looked, found nothing worth changing (2026-08)

Both are the next most expensive actions on the N3050 after the notification
popup (730 ms and 580 ms). Both turned out to be **creation-dominated, with no
single culprit** — unlike the popup, holding them open costs almost nothing:

| held for | читшит | дашборд Quick |
| --- | --- | --- |
| 1 s | 590 мс | 540 мс |
| 4 s | 600 мс | 430 мс |
| 10 s | 800 мс | 570 мс |

Two hypotheses were tried and **both refuted by measurement**; recorded so they
are not tried again:

- **"The cheatsheet re-runs `hyprctl -j binds` on every open."** It does, and it
  costs 25 ms with a 0.4 ms parse. Not the problem.
- **"Nested Repeaters materialise every bind row up front."** They do — 91 rows
  on the desktop. Rewriting `KeybindingsTab` as a flat sectioned `ListView`
  with `reuseItems` changed nothing on either machine (desktop 60-80 ms before
  and after; laptop 590-600 before, 610-650 after) and was reverted. Row count
  is not what the open costs.

For Quick, bisecting by disabling one element at a time put only
`SystemMonitoringElement` above the ±18% run-to-run noise, at roughly 140 ms of
~500. `MediaPlayer` with its two `MultiEffect` blurs — the obvious suspect on
weak Intel graphics — cost nothing measurable.

So both panels are simply "a lot of components, each modest, on a slow
machine". The one lever that would remove the cost outright is not building
them again on every open: today `LazyLoader { active: ...Open }` destroys each
panel on close by design. Keeping them resident after first use trades RAM for
latency, which is a decision to take deliberately given the open memory-growth
question, not a defect to fix.

---

## Slow-machine calibration (2026-08)

A second machine exists for measuring: an Intel Celeron N3050 laptop (2 cores,
1.6-2.16 GHz, 3.7 GB, Intel Braswell, 1366x768) reachable over SSH, running the
same Arch, the same Hyprland 0.56.2, the same Qt 6.11.2 and — verified — the
same Quickshell revision `1a4716c`, so behavioural differences can be assigned
to hardware rather than versions.

**Cost of one keystroke in the launcher**, measured from the shell's own
utime+stime, three repeats each, typing 20 characters in a single `ydotool
type -d 120` invocation:

| | per keystroke | .desktop entries |
| --- | --- | --- |
| 9950X3D | 6.5 ms (3x identical) | 270 |
| N3050 | 96 ms (94.5 / 96.0 / 98.0) | 63 |

**~15x, and that is a lower bound** — the laptop carries 4.3x fewer entries, and
the fuzzy pass scales with corpus size.

At 60 Hz a frame is 16.7 ms, so on the N3050 one keystroke costs about six
frames. The same number that reads as "comfortably inside the frame budget" on
the reference machine is visible lag on ordinary hardware. **Use the multiplier
before calling anything cheap.**

Harness notes, learned the hard way:

- Drive input with ONE `ydotool type -d N` call. A shell loop calling `sudo
  ydotool` per key silently delivered nothing on the slow machine and produced
  "80 keystrokes cost less than idle".
- Verify the launcher is actually open (`hyprctl layers` for the `quickshell`
  namespace) before and after every window; a crashed shell sends the keys to
  whatever terminal is underneath.
- `pgrep -x qs` misses a stray `/usr/bin/quickshell` (the crash reporter), so
  check for extra instances before trusting a per-PID CPU sample.
- Do not equalise the corpus by copying `.desktop` files onto the other
  machine: it changes which icons exist and which theme paths are taken, which
  distorts exactly the icon behaviour under study. Report both corpus sizes
  instead.

---

## Launcher: doubled first row fixed, missing icons still open (2026-08)

**Fixed — doubled first row.** `LauncherService.filteredApps` is a singleton
property that outlives the launcher window, so the list model bound to the
PREVIOUS session's results at creation, populated delegates from them, and was
then replaced by `Component.onCompleted`'s first search. The outgoing
delegates stayed drawn over the incoming ones permanently. The model now stays
empty until the first search of the current session has run. Reproduce the old
behaviour by typing a query, closing, and reopening.

**Fixed — application icons sometimes blank.** Root cause: every keystroke
rebuilt the result list, which rebinds delegates and cancels their in-flight
asynchronous icon loads, and a cancelled load leaves Quickshell's icon provider
holding an empty result for that icon NAME for the rest of the session. The
search is now coalesced over 120 ms so the list holds still long enough for the
loads to finish; Enter flushes a pending search.

What the measurements pinned down, in the order that mattered:

- A freshly started shell never shows it. Wallpaper rotation, 20 launcher
  cycles, 2 config reloads and 20 distinct queries at a human pace all leave it
  clean — so it is triggered, not gradual.
- Fast typing reproduces it on demand, and the blank then survives every
  later open of the launcher.
- The poisoned entry is keyed by NAME, not size (40 -> 41 is still blank), and
  sits below QQuickPixmapCache (`cache: false` does not avoid it).
- It is shell-wide: the same app then loses its icon in the bar's workspace
  chips, which is what first made it look like two unrelated bugs.
- The dock's pinned icons never break, because they load once at startup and
  nothing cancels them. That is why the working set was exactly `pinnedApps`.

Related and fixed with it: the list's `remove` transition animated `scale` and
`opacity` ON the delegate while ScriptModel reuses delegates by `resultId`, so
an interrupted transition left a row stuck shrunk — smaller the faster you
typed, down to nearly invisible. The transition is gone and a rebound delegate
resets its own scale and opacity.

**Note for later:** the debounce is load-bearing for correctness now, not just
for the ~6.5 ms per keystroke measured above. Removing it brings the icon
poisoning back.

---

## Launcher review (2026-08)

One real defect: `launcher.maxResults` is documented in the schema as 1..50,
but `ApplicationProvider` capped itself at a hardcoded 10 in both paths (the
fuzzy limit and the empty-query slice), so raising it changed nothing.
Verified fixed by round-tripping the live config — 13 rows plus one clipped at
the fold with maxResults 20, against exactly 10 before.

**Per-keystroke cost measured, deliberately not changed.** The search field has
no debounce, so every keystroke runs the full provider sweep. Measured on the
running shell by reading its own utime+stime across a typed word, against an
idle baseline of 0 ms:

| query | ms CPU per keystroke |
| --- | --- |
| normal (all providers) | 12.5 |
| `>` prefix (applications skipped) | 6.2 |
| `=` prefix (calculator only) | 6.2 |

So the fuzzy pass over 270 desktop entries is ~6.3 ms and the rest is the
baseline cost of a keystroke reaching the field. That fits inside a 16.7 ms
frame and no lag was reported, so no debounce was added — a debounce only
collapses bursts anyway, and the standing goal of a fully non-blocking UI
thread would need the search moved off-thread, not delayed.

Checked and clean: no `Process` or `createObject` in the launcher, the one
Timer is the calculator's internal 150 ms eval debounce, the result-wrapper
cache is bounded at 1000 with liveness-aware eviction, thumbnail requests are
deduped/queued/serialised behind a 48-entry LRU, the search corpus is cached
and invalidated on both app-list and config changes, and the two `Image`
caching decisions are correct in opposite directions with `sourceSize` set on
both.

---

## Hyprland 0.56 broke every dispatch (2026-08)

Reported as "the workspace widget is unreliable". It was not the widget.
Hyprland 0.56 moved dispatching to Lua and dropped the string form: the
compositor wraps whatever arrives on the IPC socket as
`return hl.dispatch(<text>)`, so `dispatch workspace 2` became a Lua syntax
error and never ran. Quickshell sends exactly that string, so all five call
sites died at once and silently — bar workspace click and scroll, the
per-window icons, the dock's focus and close — plus logout, which went through
`hyprctl dispatch` and speaks the same protocol.

Every framing of the old form was checked against the raw socket (`/dispatch`,
bare, `[[BATCH]]`, and quoting the argument). The working form sends only the
dispatcher expression and lets Hyprland supply the wrapper:

    hl.dsp.focus({workspace=N})
    hl.dsp.focus({window="address:0x..."})
    hl.dsp.window.close({window="address:0x..."})

`HyprlandDispatch` now owns that syntax alone, and validates ids and addresses
before interpolating them into a Lua expression — the same discipline argv
construction gets, because this is pasting into code.

**Lesson:** a compositor-API break shows up as a feature that quietly does
nothing, not as an error the user can see. The shell logs the failure, but
only if its output goes somewhere.

### Workspace chips show application icons

The Material Symbols category glyphs are gone from workspace chips; each
window shows its own themed icon, resolved through `DockService.resolveEntry`
(the one cached class -> DesktopEntry resolver). The glyph remains the
fallback for both failure modes — no desktop entry, and an icon name the theme
cannot produce, which only appears as `Image.Error`. Focused-workspace
emphasis moved from tint to opacity, since an app icon cannot be tinted.

---

## Dashboard + backing services review (2026-08)

The dashboard is a thin view layer — no `Process`, no `createObject`, no timers
of its own — so the review followed each tab into the service behind it. The
codebase already has a convention for this class of work: **poll only while
something is on screen to read the result** (`SystemMonitorService.isMonitoring`
bound to `dashboardOpen`, `KeyboardLayoutService.lockStateWatchers`). Two
services had not adopted it, and one had a request race.

- **`DateTime`** re-read `/proc/uptime` every 3 s for the whole session to feed
  one label in the Quick tab, formatted at minute granularity. Now watcher-gated
  at 60 s. Measured with `strace` on the running shell, dashboard closed: **24
  opens per 70 s before, 0 after**.
- **`NotificationRateLimiter`** refilled a full token bucket every second —
  86 400 no-op wakeups a day. `running` now tracks `_tokens < ingressLimit`.
- **`Weather`** allowed overlapping fetches from four callers, so an older reply
  could overwrite a newer forecast. A new fetch now aborts the one in flight.

Checked and found clean: `MprisController`'s position timer (already gated on
`isPlaying && positionSupported && dashboardOpen`), `SystemMonitorService`,
Wi-Fi/Bluetooth scanner lifecycle (both stopped in `Component.onDestruction`),
`NetworkService`'s passphrase handling (stdin, never argv).

Two hypotheses were **disproved by measurement** and are recorded so they are
not re-investigated: a config value of `0` reaching a `Timer.interval` does NOT
cause an every-frame loop — a repeating timer with `interval: 0` never fires at
all (measured: 0 ticks in 2 s, vs 1892 at `interval: 1`). And the `interval: 0`
+ `repeat: false` + `restart()` coalescing idiom in `NotificationHistory` does
fire exactly once, as intended.

---

## Notification popup stack (2026-08)

The popup stack is one wlr-layer surface per screen with the cards as Items
inside it, not a `PanelWindow` per card. That removed 84 `set_margin` round
trips per burst, and introduced three defects that only a frame-by-frame
capture could find:

- **Swipe-to-dismiss was dead.** The card animates its own `x`, but the slot
  anchored it left AND right, and an anchored item ignores writes to `x`. The
  card now owns `swipeX`/`swipeOpacity`; the slot supplies `width` and
  multiplies the swipe fade into its own entrance/exit fade.
- **Exit slid the card 20px into its neighbour.** A per-card window used to
  clip that overshoot; a shared surface does not, so two same-coloured cards
  fused into one block and the upper card's bottom edge appeared to be yanked
  down. Exit is now fade + shrink, no vertical translate.
- **Surface height fought the layout.** It was set to the target layout while
  cards were still sliding into it (clipping them), and every shrink made
  Hyprland animate the layer geometry (`animation = layers`, easeOutQuint,
  ~380 ms) over stale pixels — a card-shaped ghost in the slot just vacated.
  The surface now grows only, collapses when the stack empties, and masks its
  input region to the cards.

Verified by capturing the popup corner with `grim` at ~40 ms and printing the
occupied row bands per frame: every frame of a removal is now exactly one card
height, with no fusion and no ghost.

---

## Memory profile (2026-08)

Measured, not estimated. Startup figures are RSS ~10 s after launch from probe
instances driven with a substituted `XDG_CONFIG_HOME`, so the live shell was
never modified. Run-to-run variance is ~15 MB; smaller differences are noise.

### Startup composition

| what | RSS | delta |
|---|---|---|
| Qt6 + QML + Quickshell + NVIDIA GL, empty `ShellRoot` | 259 MB | the floor |
| project tree present, `shell.qml` emptied | 260 MB | +0 |
| + config layer (Theme / Tokens / AppConfig) | 278 MB | +18 |
| + `GlobalStates` and the services it pulls | 286 MB | +8 |
| + `CalendarBackend` | 291 MB | |
| + `WallpaperManager` | 329-341 MB | +51-63 |
| whole shell, every module OFF | 462 MB | |
| whole shell, every module ON | 549 MB | +87 for ALL UI |

**Two thirds of a ~400 MB startup is framework floor** that no config can
change. Every C++ plugin is +0..4 MB on import, Quickshell's own native
services +0..6 MB, a surface ~10 MB — none of those are the cost.

### Growth over 135 minutes

  half-hour means:  848 -> 823 -> 896 -> 915 -> 920 MB
  RSS band:         720-984 MB, moving both directions
  HWM steps:        876 -> 984 (+14m) -> 1895 (+52m), then flat for 83 min

A slow drift of roughly +35 MB/hour, plus one transient ~1 GB allocation.

**A wallpaper-rotation hypothesis was RAISED AND REFUTED.** The minute log
showed jumps 15 minutes apart, matching `intervalMs: 900000`, which looked
conclusive. A 5-second sampler watching `state.json` then caught two real
rotations and measured them at -8/-14 MB and +4/+10 MB with the peak unmoved.
The pattern was noise read as signal; recorded because the coarse log invited
exactly that mistake.

Panel cycling is likewise NOT a leak: 15 launcher open/close cycles added
58 MB, and the NEXT 15 added 80 KB — one-time initialisation. A single-batch
test would have misreported it.

### QML-level profiling (Qt's own tooling)

Quickshell exposes a QML debugger port and `qmlprofiler` attaches to it:

```bash
qs -c shell --debug 3768
qmlprofiler -a localhost -p 3768 --interactive \
    --include memory,pixmapcache,creating          # then: f <file>, q
```

Features: javascript, memory, pixmapcache, scenegraph, animations, painting,
compiling, creating, binding, handlingsignal, inputevents, debugmessages. The
trace is XML and parses without Qt Creator.

**The JS heap is not where the memory goes** — 45 s under load moved ~11 MB
(186 k SmallItem = 5.3 MB, 80 HeapPage = 5.8 MB) against a process holding
800+. 186 k allocations in 45 s is real GC pressure even so.

**SECURITY: `--debug` listens on `*:PORT`, all interfaces**, and a QML debugger
connection can execute arbitrary JavaScript in the shell. Use it only while
profiling; never leave it running.

The `creating` feature found one concrete defect: opening the calendar tab
created 1382 objects, its 42-cell delegates 168 times — four full grid
rebuilds, because `generateCalendar()` cleared and refilled the ListModel.
Fixed by updating rows in place; re-measured at 794 objects, and month
navigation no longer tears delegates down at all.

### heaptrack — the spike is IMAGE DECODING

`heaptrack qs -c shell`, 104 s of exercised load:

  allocation calls        3 199 850  (30 652/s)
  temporary allocations     661 130  (~20% pure churn)
  peak heap                  460 MB
  still held at exit         157 MB

**`QImageData::create` is 307 MB of the 460 MB peak**, split almost evenly
between two decoders of the SAME wallpaper: `McuTheme::extractSeedFromImage`
for the palette and QtQuick's `Image` for display. That attributes the 1.9 GB
peak the RSS capture could not explain.

Why it gets that large, measured:

- The collection is 369 files totalling **9.5 GB fully decoded**, averaging
  26 MB. `UbuntuGnome.png` alone is **506 MB decoded**; one JPEG is 8640x4860
  for a 3440x1440 monitor.
- **PNG supports NEITHER ScaledSize NOR ClipRect NOR ScaledClipRect** in Qt's
  handler, so `sourceSize` cannot bound it: the full image is decoded and only
  then scaled. 163 of the 369 files are PNG.
- JPEG does support scaled decoding and `McuTheme::readDownscaled` uses it
  correctly — fed `leaves.jpg` (68 MB full) it returns 160x106 / 0.06 MB with
  no peak. The plugin is not at fault there.

A rotation landing on a large PNG therefore decodes it twice with no
in-process way to bound either. Fix options, in order of value:

1. Downscale the collection to screen resolution — no code needed.
2. Generate downscaled proxies on disk so neither decoder sees the original;
   `WallpaperCache` already owns a disk cache and is the natural home.
3. `McuTheme` already survives it (`setAllocationLimit(128)` fails loudly
   rather than allocating); QtQuick's `Image` has no such guard.

`tools/mem-watch.sh` logs RSS/HWM/threads/fds every minute for sessions longer
than a profiling window.

---


## Done — calendar: all-day events off by a day, and duplicated (2026-08)

Reported symptom: a birthday authored on 20 Oct showed on the 19th, while khal
showed it correctly. Two independent defects, both in `IcalParser::expandRange`,
both invisible in UTC and west of it — which is why they shipped.

**1. Floating dates routed through UTC.** A `VALUE=DATE` denotes a calendar day,
not an instant: it has no zone to convert from. The expander built the
iterator's DTSTART from `ev.start.toUTC()` and kept only the date part, so in
MSK (UTC+3) 20 Oct 00:00 became 19 Oct 21:00 UTC and every yearly occurrence
landed on the 19th. All-day now takes the authored date verbatim with a null
zone; timed events keep the UTC→authoring-zone path they need.

**2. DTEND is exclusive, and the range filter ignored it.** `end >= rangeStart`
meant an all-day event on the 15th (DTEND the 16th) also appeared on the 16th —
EVERY all-day event was duplicated onto the following day, and every timed one
onto the moment it ended. Replaced with one `intersects()` predicate used by all
four call sites (non-recurring, expanded occurrences, overrides, and the
recurrence loop), with zero-length events kept as points.

**3. Found while fixing the above:** all-day series were excluded from the
iterator fast-forward, so they replayed from DTSTART into a 5000-iteration
safety cap — a DAILY all-day event authored in 2005 produced ZERO occurrences in
2026. Fast-forward now runs for all-day too, seeking with a DATE-typed value
(handing a timed value to a date rule is what made it unsafe) and backing off by
the event's span so multi-day occurrences overlapping the range survive.

Three regression tests added, each demonstrated to FAIL before its fix:
the birthday date (pinned to Europe/Moscow, since the bug is invisible in UTC),
the exclusive-end boundary, and the long daily series. Suite: 26 → 29, all green.

The test suite existed but nothing documented how to run it, which is why it was
never run — `AGENTS.md` §4 now carries the command.

**Follow-up review of the whole subsystem** found two more RFC 5545 violations
in the same parse step, both fixed with tests (suite 29 → 31):

- **`DURATION` was never read.** DTEND and DURATION are mutually exclusive
  alternatives; a DURATION-only event got `end = start`, i.e. zero length —
  and a zero-length event only matches a range containing its exact start, so
  it also disappeared from most queries. Apple/iCloud and Nextcloud emit
  DURATION on recurring events.
- **A bare all-day event lasted zero time.** RFC 5545 §3.6.1: a DATE-valued
  DTSTART with neither DTEND nor DURATION lasts ONE DAY. It got `end = start`.

Verified sound during the same pass, so they need no further attention: the
worker-thread model (no parent → moveToThread, queued connections, bounded
shutdown with terminate fallback), atomic writes via QSaveFile, the delete path
(safe iteration over multi-VEVENT files, orphan file removal), timezone-aware
DTSTART/DTEND writing across all four cases (date / TZID / UTC / floating), and
the config contract — schema, defaults, AppConfig getters and the `shell.qml`
Bindings that feed them into the C++ backend all line up.

## Done — calendar brought to an acceptable state (2026-08)

Everything the subsystem review listed as open, closed. Suite 31 → 38 tests,
each new one demonstrated FAILING before its fix.

**Expansion is now driven by the RRULE, not by the editor's enum.** The guard
read `ev.recurrence == Recurrence::None`, an editor-facing vocabulary with no
HOURLY/MINUTELY/SECONDLY, so `FREQ=HOURLY;COUNT=5` rendered exactly once. An
unparseable RRULE now degrades to a single event instead of `continue` —
dropping the whole series was the worst possible reading of "I don't
understand this".

**RDATE is read.** Explicit extra occurrences were ignored, so a server using
RRULE+RDATE silently lost the RDATE ones, and an RDATE-only VEVENT showed a
single date. Expansion now funnels every occurrence — RRULE- and RDATE-derived
— through ONE emit path, so range filtering, EXDATE and override suppression
cannot drift apart between them. PERIOD-valued RDATEs are skipped, not
mis-read.

**UNTIL matches DTSTART's value type.** Every series was written with a bare
DATE UNTIL; RFC 5545 §3.3.10 requires a UTC DATE-TIME when DTSTART is a
DATE-TIME. The user picks a day, so a timed series now runs to the end of it.

**Unknown edit/delete scopes are refused.** `editScopeFromString` fell back to
`EditScope::All`, so a typo or stale caller would rewrite or delete an entire
series. The existing test asserted exactly that behaviour and has been
rewritten — it was blessing the bug.

**The watcher sees content edits.** Qt emits `directoryChanged` on
add/remove/rename but not on an in-place rewrite, so the .ics files are watched
too (216 watches here against a 524288 limit).

**All-day events can remind.** They were skipped outright — "N minutes before"
is meaningless without a start time — so a birthday could never remind. They
now raise once on the day itself at `services.calendar.reminders.allDayTime`
(default 09:00, new config key). Verified end to end: the notification lands in
this shell's own history with `appName=Calendar`.

**Reminders no longer spawn `notify-send`.** They go out over QtDBus directly.
The destination is unchanged — this shell IS the notification server — so DND,
history and grouping apply exactly as before, minus a process spawn per
reminder. `libnotify` dropped from the README's dependencies.

NOTE ON THE CHOSEN APPROACH: the request was to route reminders through a QML
signal into `NotificationService`. That service is a *server* — its pipeline is
built on real `Notification` objects with `id`, `tracked` and `expire()`, and
faking one is exactly how earlier leaks happened. Direct D-Bus reaches the same
place without that risk.

**The event dialog can express dates.** There was no date input at all: start
and end were composed from `selectedDate` plus the times, so multi-day and
midnight-crossing events were inexpressible and editing the times of a
multi-day event collapsed it to one day. Start/end date fields added; for
all-day events the end shown is the LAST covered day (how humans read
"15-17 March") and is converted to RFC's exclusive next day on save.

**"This and future" exists.** Only "only this" and "whole series" did. The
master's RRULE is truncated with an UNTIL just before the cut, overrides at or
after it are removed (expandRange emits overrides independently of their
master, so they would otherwise survive as exactly the occurrences the user
asked to delete), and for an edit the tail becomes a new VEVENT with a fresh
UID. Cutting at or before the first occurrence degrades to whole-series rather
than leaving an empty stub.

**Cancelling the scope prompt no longer discards the edit.** The form is
already filled in by the time that modal appears; cancel now hands the composed
fields back and reopens the editor.

### Calendar — still open

- PERIOD-valued RDATE (start/duration pairs) is skipped.
- The event dialog's date fields are plain `yyyy-MM-dd` text, not a picker.
- The three-button scope prompt and the new date fields are lint- and
  compile-verified but were not seen rendered — driving synthetic input into a
  focused panel did not work here.

### Calendar — resolved items from the 2026-08 subsystem review

All of the below are now FIXED — kept for the reasoning. None affected the
data set at the time (checked: 0 VEVENTs using DURATION, 0 using RDATE, 0
sub-daily FREQ, 0 without DTEND); they were spec gaps that would bite on a new
calendar source.

- **RDATE is not read at all.** It adds explicit occurrences to a series; a
  server that uses RRULE+RDATE loses the RDATE ones silently.
- **FREQ=HOURLY / MINUTELY / SECONDLY map to `Recurrence::None`**, and
  `expandRange` treats "None" as non-recurring — such an event renders exactly
  once instead of on its schedule. Either map them or reject them loudly.
- **UNTIL is truncated to a date on write.** `recurrenceUntil` is a QDate, so
  editing a series whose RRULE carried `UNTIL=...T235959Z` rewrites it as a
  DATE. Harmless in practice, lossy in principle.
- **All-day events never produce reminders** (`ReminderEngine::tick` skips
  `allDay`). Defensible for a timed reminder, but it means a birthday — the
  archetypal all-day event — can never remind. Wants a separate "morning of"
  path rather than the minutes-before one.
- **`ReminderEngine` shells out to `notify-send`** instead of using a native
  API. Functionally fine — it round-trips over D-Bus into this shell's OWN
  notification server, so DND and history do apply — but it is a process spawn
  per reminder and deviates from §7's "native > CLI".
- **`QFileSystemWatcher` watches directories only.** Qt fires
  `directoryChanged` on add/remove/rename, not on in-place content edits, so an
  editor that writes an .ics in place without renaming is missed until the next
  rescan. vdirsyncer/khal write atomically, so this is currently theoretical.

---

## Done — keyboard navigation was Latin-only (2026-08)

Reported symptom: notification-centre navigation worked only on a US layout.
The cause is general, and it hit every panel.

`event.key` and `event.text` carry the SYMBOL the active layout produces, not
the key that was pressed. On a Cyrillic layout the physical J key arrives as
`Qt.Key_O` with text "о", so `event.key === Qt.Key_J` simply never matched.
Every vi binding in the shell was dead: j/k/x/g in the notification centre,
h/j/k/l/g/n on the calendar, h/l for dashboard tab switching, Ctrl+F in the
cheatsheet, and the digits 1-5 (which also break on AZERTY, where the unshifted
digit row produces &é"'( ).

The fix is to match the PHYSICAL key — `event.nativeScanCode`, the XKB keycode,
identical on every layout. New `Keycodes` singleton in `core/config` (the only
layer everything else may import) exposes `key(event)` → `Qt.Key_*` and
`letter(event)` → "A".."Z". Call sites keep their shape; `event.key` becomes
`Keycodes.key(event)` and non-letter keys fall through untouched.

Two places already had the right idea in isolation and are now folded in:
`ScreenshotOverlay` carried a four-entry hjkl table, and `PowerMenu` a
five-entry one — the latter with an `event.text.toUpperCase()` fallback, i.e.
the exact layout-dependent read it was trying to avoid, so any action key
outside those five still failed.

Verification, since the mapping is the whole fix:
- All 36 letter/digit scancodes checked against `/usr/include/linux/input-event-codes.h` — 0 discrepancies.
- The evdev+8 offset confirmed by a real event on this machine (Super: scancode 133 = KEY_LEFTMETA 125 + 8).
- `Keycodes` exercised against synthesised Cyrillic events (physical J reported as `Qt.Key_O`/"о" → resolves to `Qt.Key_J`): 8/8.
- New `layout-dependent-keys` invariant holds it at zero; its pattern was validated against 11 synthetic cases, and it ignores comment lines so the fix can describe the bug it removed.

Not yet confirmed end to end by a human pressing keys on a RU layout — driving
synthetic input into a focused panel did not work here.

---

## Done — the lock screen died and the session was unrecoverable (2026-08-13)

An incident worth writing down, because the tooling could not see it coming.

`BindRow.qml` ended up with two `pragma ComponentBehavior` lines. qmllint accepts
that file — exit 0, no diagnostic. The Quickshell loader does not, and a failed
load is all-or-nothing: the whole configuration went down, including the
`WlSessionLock` client. Hyprland was left locked with no lock client and showed
its "lockscreen app died" recovery screen.

Two separate failures, both worth keeping distinct:

- **Tooling.** A fatal load error was invisible to the linter. Fixed with
  `tools/compile-check.sh`, which builds every component through the real engine
  via `Qt.createComponent` — no objects, no surfaces, safe against a live
  session — plus the `duplicate-pragmas` and `qml-compile-failures` invariants.
  Both were verified by planting the real defect and confirming they go red; the
  compile check reports the full cascade (one bad pragma → 4 dead components).
- **Process.** The edits were made while the session was already locked. The
  shell owns the lock screen, so editing it then is editing the only way back
  in. `hypridle` locks after 600 s idle here, and IPC calls and screenshots do
  NOT reset the idle timer — an unattended automated session will lock itself.
  Recorded as a rule in `AGENTS.md` §4.

**No working recovery is known.** Hyprland's own screen suggests
`hyprctl --instance 0 eval 'hl.clear_crashed_lockscreen()'` from another tty.
The function does exist on 0.56.2 and responds, but it did NOT resolve the
incident — the machine had to be rebooted. Likely reason, unverified: the `qs`
process SURVIVES a failed config load (`pgrep -x qs` returned a live pid while
the log said "Failed to load configuration"), so the lock client process is
still around; the same screen's second suggestion — kill the lock process and
re-run the eval — would mean `pkill -x qs` here, not `killall hyprlock`. Nobody
is going to test that on a live session, so prevention is the whole answer.

---

## Done — qmllint ratchet burn-down (2026-08)

212 → 49 warnings; unqualified access 150 → 4. The four that remain are qmllint
limitations, not defects: Quickshell's `margins` grouped property on PanelWindow
(×2) and two ids reached from inside an attached-property scope in
`TooltipManager`. `Repeater.itemAt()` returning `QQuickItem` accounts for most of
the surviving `missing-property` noise — those members are duck-typed contracts.

Mechanically the work was `pragma ComponentBehavior: Bound` plus `required
property` on delegates, then qualifying every reference with an explicit id.
Bound is the point: without it a delegate reaches its enclosing scope through
the dynamic context, which happens to work and which nothing verifies.

What the noise was hiding, now that the signal is back:

- The greeter's three defects (see the section below) — 7 unresolved-type and 2
  unqualified warnings, all sitting inside a baseline that read "known debt".
- **Four animations running linear.** `easing.type: Tokens.motion.easing.X`
  without the matching `bezierCurve` — every one of those tokens is
  `Easing.BezierSpline`, so a lone half leaves Qt with no control points. Three
  were in `MaterialComboBox`, one in `NotificationCenter`. They survived the
  2026-08 sweep because `check.sh`'s `easing-unpaired-tokens` anchored the type
  match to end-of-line and therefore only ever saw the two-line form. The check
  now accepts both layouts and is verified against synthetic cases for all three
  failure shapes (single-line unpaired, two-line unpaired, mismatched pair).
- **13 `Quick.layout-positioning` warnings** — `width`/`height` set on items
  inside a Layout, which the QtQuick.Layouts docs call undefined behaviour.
  Now `Layout.preferredWidth`/`preferredHeight`.
- Two hand-rolled count chips replaced with `Badge { inline: true }` — the mode
  added for exactly this and until now unused (raw Rectangle ratchet 83 → 81).

The pass also caught one of its own mistakes, which is the argument for keeping
the signal clean: qualifying `actions` as `menuWindow.actions` in `PowerMenu`
was WRONG — the property lives on the root `Scope`, not the `PanelWindow`, so
the binding would have been `undefined` at runtime. qmllint reported it as
`Member "actions" not found on type "PanelWindow"` immediately.

Still verified only by lint and a clean `Configuration Loaded`: the visual pass
over cheatsheet / launcher / dashboard tabs / popouts / power menu / tooltips
was cut short when the session idle-locked, and should be repeated.

---

## Done — greeter fell out of the kit (2026-08)

The greeter is a SEPARATE Quickshell process on the pre-login screen with its own
module roots. Its `ui/` is generated from `src/ui`, but its `config/` is not — so
main-shell fixes reached its components and never reached its theme. Three live
defects, all found by instantiating the greeter kit under Quickshell in a probe
config that creates no windows (`qs -p probe.qml`); the greeter itself cannot be
smoke-tested over a live session, since it grabs the screen.

- **Unresolvable animation types.** `MotionAnimation`/`MotionColorAnimation` were
  introduced in the main kit and picked up by four generated components, while
  being absent from both the generator's copy list and the greeter's `qmldir` —
  which was hand-maintained. Every greeter button, icon and state layer would
  have failed to resolve its animation type. `qmldir` is now GENERATED from the
  same list that copies the files, so it cannot drift again.
- **`AppConfig` leaked into the greeter.** `Tokens.durationScale` grew a config
  binding, but the generator only substituted `AppConfig.fontScale`. Result:
  `ReferenceError: AppConfig is not defined` on the login screen and every
  duration undefined. Generation now aborts if any `AppConfig` survives.
- **The palette never seeded from the wallpaper.** `McuTheme.source` takes
  QColor or QUrl and rejects a QString outright; `GreeterConfig.wallpaperPath`
  is a bare path string. Measured A/B: before, the greeter fell back to the
  default purple seed (`primary #cfbdff`, `primaryContainer #5300cd`); after,
  it derives from the actual wallpaper (`primary #e9c400`, `#544600`). The
  greeter also still carried the hardcoded `contrast: 0.5` that was removed
  from the main shell — at 0.5 `primaryContainer` came out `#aa8f00` (bright)
  instead of `#544600` (dark), the same container-polarity inversion.

Two things worth keeping: the qmllint ratchet HID all of this (7 unresolved-type
and 2 unqualified-access warnings sat inside a 212-warning baseline that read as
"known debt"), and `greeter-ui-drift` passed throughout, because it diffed the
generator against its own output while the bug was in the generator's inputs. A
check that compares a thing to itself proves nothing.

---

## Done — root-cause refactor F0–F9 (2026-07)

All ten phases executed on branch `dock-overhaul` (one commit per phase, F0–F9).
Highlights: mechanically-checked invariants (`tools/check.sh` ratchet +
`tools/lint.sh` qmllint wrapper); layer graph now matches AGENTS §3 exactly;
`GlobalStates.activePanel` state machine; popouts coordinated as data;
startup readiness gates (state.json can no longer be clobbered); motion
tokens normalized (~45 broken/raw easing sites) + `MotionAnimation`
primitive; notifications lifecycle declarative; EventDialog on Material
inputs (inputMask 'until' bug root-fixed); network/bluetooth event-driven
(no polling, no auto-pair agent); OSD rewritten per-screen on `OsdSurface`;
calendar plugin addresses events by (uid, recurrenceId) with regression
tests (25 passing); Qalculate async; config contract honest (dead keys
removed, honored keys implemented, defaults reconciled); IPC reference
single-sourced (`IpcReferenceData.qml`).

**Reinstall plugins after pulling this branch:**
`cd src/plugins && cmake --build build && sudo cmake --install build`

## Done — layer/module audit (2026-08)

Seven confirmed defects, each verified by execution against Qt 6.11 /
Quickshell source rather than by inspection:

- **All MD3 easing was linear.** `easing.bezierCurve` takes groups of three
  points (6 reals, last = 1,1); the tokens supplied 4, which Qt rejects
  silently. Every one of the 115 curve sites, `MotionAnimation` and the
  generated greeter tokens were affected. New `easing-points-arity` invariant
  makes the shape non-regressable.
- **`x = x` does not notify.** Reference-equality short-circuit on `var`
  properties. Broke the notification ingress queue (drain timer never started
  → burst notifications silently swallowed and left tracked) and the history
  batch-clear timer (never stopped → `save()` restarted the debounce every
  8 ms → history stopped persisting for the session). Also fixed a gate-queue
  deadlock when a queued notification died while waiting.
- **Dock context menu never ran an action** — `close()` nulled `app` before
  the guard read it.
- `WallpaperManager` called a `postScriptTimeout` Timer that did not exist;
  added the (missing) two-stage SIGTERM→SIGKILL watchdog and bounded the queue.
- `ClipboardProvider` wrote to an undeclared global; also restored the stable
  cliphist id that `ClipboardService` documents but never shipped in results.
- **Overlay panels now open on the focused monitor.** Dashboard, launcher,
  power menu, cheatsheet and notification centre had no `screen`, so the
  compositor placed them on its default output. Resolver shared via
  `GlobalStates.focusedScreen()`; the two prior copies now delegate to it.
- **`SystemMonitor` no longer polls when nothing reads it.** The worker started
  in the constructor and never stopped; it is now gated on dashboard
  visibility (thread stays warm, counters re-baseline on resume).

Tooling gaps closed in the same pass: the `sh -c` security scan was line-based
and could only see 3 of 8 call sites (now multiline-aware); greeter UI-kit drift
is now checked via `sync-ui.sh --check`; the two dead config keys
(`services.vpn.enabled`, `lockscreen.blurWallpaper`) are honored.

**Reinstall plugins after pulling:**
`cd src/plugins && cmake --build build && sudo cmake --install build`

### Follow-ups from the 2026-07 deep per-system audit (small, non-blocking)
- WorkspaceWidget: urgent windows never light up. NOTE: the entry used to say
  "surface `HyprlandWorkspace.urgent`" — that property does not exist in this
  Quickshell build (checked: no `urgent` anywhere in
  quickshell-hyprland.qmltypes). Doing it means tracking Hyprland's `urgent`
  socket event and clearing on focus, which is a different job. Also optional
  per-monitor workspace filtering.
- Cheatsheet: submap display (binds inside a submap are listed flat, so
  "Resize mode" and the keys it enables look unrelated).
- KeyboardLayoutService: base.lst parsing is heavier than it needs to be (a
  ~1000-line file scanned in QML), though it now runs at most once per unseen
  layout name rather than per poll.
- RecurrenceEditChoice: cancel discards an already-composed edit (reopen the
  dialog instead?).
- MediaPlayer: migrate the hand-rolled source menu to MaterialMenu + grab.
- Dock: urgent-window reveal for auto-hidden dock; drag-reorder passing over
  icons fires their hover previews.
- LockSurface: dedicated PAM config instead of "login"; single shared
  PamContext across monitors (contention with fingerprint/U2F stacks).

### Follow-ups (small, non-blocking)
- Adopt `ScrollableList` in the THREE places it actually fits — `IpcReferenceTab`,
  `KeybindingsTab`, `CalendarTab`. NOT `LauncherContent` / `NotificationCenter`:
  those use `ListView`, which virtualises, while `ScrollableList` is a
  `default property alias contentData` over a Column and would instantiate every
  row eagerly. Swapping them would be a performance regression, not an adoption.
- Remaining raw `Rectangle`/`Text` in features — 81 by the ratchet, concentrated
  in `ScreenshotOverlay` (12), `CalendarTab` (8), `NotificationPopupItem` (6),
  `LockSurface` (5), `BindRow` (5). Needs case-by-case triage; several are
  legitimate (image backing with `clip`, 1px rules, scrims).
- Native BlueZ / NetworkManager D-Bus endgame (replaces `nmcli monitor`).
- Notification inline reply / action icons (see Notifications — deferred).

Struck from this list after checking the code rather than trusting the entry:
`DeviceSelectionDialog` already uses `MaterialRadioButton`; the hand-rolled
progress bars are already `ProgressIndicator` (`OsdMeter`, `NotificationPopupItem`);
cheatsheet keycaps as `Chip` contradicts the recorded non-adoption below; and the
qmllint burn-down is done (212 → 49).
- `AppFrequencyService` runs `LocalStorage.openDatabaseSync` on the UI thread.
  MEASURED 2026-08-13, and it is far cheaper than this entry used to imply:
  Qt caches the connection, so the open itself is ~0 ms and a full SELECT is
  0.015 ms. Only the launch UPSERT costs anything real — 1.9 ms, once per app
  launch, at the moment the launcher is closing anyway. `getFrequency()` is
  dead code and `getAllFrequencies()` feeds a cache, not per-delegate reads,
  so there is no hot path here. Still a §10 rule violation worth cleaning up
  eventually; not a performance problem.
- `NotificationPopup` animates `screenY`, i.e. a layer-shell margin: one
  surface reconfigure per frame per popup.
- No runtime validation of `config.json` against `config.schema.json` — for a
  config-first project the schema is currently editor-only, so a typo'd key is
  silently ignored.

---

## Wallpaper — deferred extensions

### Stage E — wallpaper picker UI (~3–5 hours)
Bottom-panel browser of source items with thumbnails. Architecturally straightforward — `WallpaperSourceRegistry.getSource(id).items` already supplies everything. UI:
- Bottom panel (cheatsheet-style layer)
- Tabs per source id
- Grid of thumbnail `Image` with lazy loading
- Click thumbnail → `WallpaperManager.setMonitorSource + setItem`
- Per-source actions: refresh, loadMore; for Wallhaven — a search bar with `onAccepted → query`

### Wallhaven — endpoints beyond `/search`
- **`/w/{id}`** — single-wallpaper details (used when the user pinned a specific wallpaper id)
- **`/tag/{id}`** — tag info
- **`/collections/{username}/{id}`** — collection contents (important: "use my Wallhaven collection as a source")
- Setup: either a new `wallhaven-collection` source type, or optional `collectionId + username` on the existing one

### Other remote sources
Following the Wallhaven pattern (~250 LOC each):
- **Unsplash** — `/photos/random` or `/search/photos`, needs an Access Key (env var)
- **Reddit** — `/r/wallpapers/.json`, no auth, easiest
- **Bing wallpaper** — `/HPImageArchive.aspx`, no auth

### Per-monitor query overrides for Wallhaven
In Stage D a source has one `query`, and every monitor shares it. Either spawn multiple Wallhaven sources or add `monitors[].sourceQueryOverride`. Worked around today by using multiple sources.

---

## Done — notifications deep dive (2026-08)

The subsystem's split into five singletons was sound; what was missing is that
**no single place owned a notification's lifecycle**. All three critical bugs sat
on the seams. `NotificationService` is now the sole owner: it is the only code
allowed to close a notification, and the popup manager is purely presentational.

- **maxVisible eviction leaked.** The cap lived in the popup manager, and
  "evicting" only destroyed the window — the notification stayed tracked on the
  server for the session, holding its `NotifData` and any image-data pixmap, once
  per eviction. The cap moved next to the lifecycle. Verified by accounting:
  30 sent → 30 `NotificationClosed` → 0 left active.
- **Replacement never reached history.** The server does not re-emit
  `notification()` for `replaces_id`; it mutates the object. The only
  `History.add()` sat on the first-appearance path, so the centre kept the
  original text forever. There is now `NotificationHistory.update()` on the
  replacement path, keyed off a map maintained for every admitted notification.
- **`tracked = false` told clients "the user dismissed this"** (reason 2) in four
  places where the user never saw the notification. All now `expire()` (reason 1).
- `transient` is honored (skips history); `resident` is honored (invoking an
  action no longer tears down a notification that is meant to survive it).
- **Critical bypasses DND** and fullscreen suppression — the rate limiter already
  treated critical as special, so the subsystem had been disagreeing with itself.
- Identity collapsed onto `Notification.id` for live popups; the internal
  `contentId:ts:n` id remains only as the history row key. Three hand-synced maps
  became one.
- Duplicates merge into a repeat counter on the existing card instead of expiring
  the previous popup and losing the count.
- Unread tracking: badge counts unread rather than history size, cleared when the
  centre opens; dot on unread cards.
- New: IPC (`target: notifications`), `notifications.rateLimit.*`,
  `notifications.maxHistory`, `notifications.dnd.suppressOnFullscreen`,
  `notifications.filters.noPopup/noHistory`. `popup.timeout` was dead (nothing
  read it) — it now backs `timeoutNormal` as its description always claimed.
- Removed: `forceExit`, `NotifData.timestamp`, `NotifData.closeReason`,
  `discardNotification`/`discardAllNotifications`, and an unreachable
  replaces-branch in `_processNotification`.

Two Quickshell traps are now recorded in comments where they bite:
`expireTimeout` is in **milliseconds** despite upstream docs saying seconds, and
`mCloseReason` defaults to `Dismissed` so a fresh notification is *not* tracked
until the handler says so.

## Done — UI system review (2026-08)

The kit itself is sound; every finding was a seam where part of the system was
wired so it could not work.

- **The palette ran in accessibility high-contrast mode.** `Theme.qml` hardcoded
  `contrast: 0.5` with no comment and no config key. In a dark scheme that
  INVERTS container polarity: measured on the same seed, `errorContainer` goes
  `#93000A` → `#FF5449` and `onErrorContainer` `#FFDAD6` → `#000000`. Every
  tonal button, chip, badge, the active workspace pill and critical
  notifications rendered as glaring blocks. Now `appearance.theme.contrast`,
  default `0.0`. Measured after: critical card `#FF5B4F` → `#990911`, luminance
  jump against the panel 14× → 5×.
- **Focus rings were unreachable infrastructure.** `Tokens.focusRing`,
  `StateLayer.focused/showFocusRing/ringColor` all existed; 0 of 8 interactive
  kit components could take focus. All eight are now Tab-reachable with
  Space/Enter activation and a live ring.
- `MaterialText` moved off `Text.NativeRendering` (no subpixel positioning) —
  the shell animates `scale` in 18 places and `MaterialIcon` sized itself to
  `fontSize * 1.2`, fractional at every token; that size is rounded now.

  This shipped as a REGRESSION first and is worth recording. Material Symbols
  is a variable font driven through `font.variableAxes`, and Qt's
  distance-field renderer corrupts its glyphs — a toast `info` icon rendered
  as two mis-registered outlines superimposed. The fix is a split, not a
  revert: text keeps `QtRendering`, `MaterialIcon` overrides its inner text
  back to `NativeRendering`. Measured on a live toast — the icon is now
  pixel-identical to full native rendering (0 differing pixels; it was 1424
  while both were on `QtRendering`). `check.sh: icon-renderer-override`
  fails if that override is ever dropped.

  The lesson generalises past this one bug: the change was made by reasoning
  about subpixel positioning and never looked at, and a screenshot caught in
  one second what inspection had missed for a whole pass. Renderer- and
  font-level changes need a rendered pixel before they count as done.
- `Surface` builds its `MultiEffect` through a `Loader` gated on
  `elevation > 0` — elevation 0 is the default, so every flat card carried a
  blur-capable node for a shadow it never drew.
- Three hand-rolled "primary tint" rectangles painted with
  `Tokens.stateLayer.hoverOpacity` (a STATE token used as a constant elevation
  tint, so surfaces at rest looked hovered) replaced with `SurfaceTint`.
- **The variant enum lied.** Schema offered `fidelity`/`neutral`/`monochrome`,
  none of which `McuTheme.cpp` handled — all three silently fell through to
  tonalSpot — while the implemented `content` was not offered. All seven are now
  wired and verified to produce distinct schemes.
- `Badge` gained an `inline` mode; it could only pin itself to a parent's
  corner, which is why every inline counter in the shell was a raw Rectangle.

Notification centre, same pass: visible keyboard cursor (it navigated an
invisible one and deleted cards the user could not see), unread cleared on
close rather than on open (the dots were gone before the panel finished
animating in), group counts via an O(1) index instead of a linear scan per
group per mutation, delegate on typed properties instead of a 12-field literal
rebuilt on every change, DND toggle on the button's own `tonal` variant, and a
layout fix that only a screenshot revealed — the app name was repeated on every
card inside its own group, leaving the headline row empty.

Also fixed: **an auto-hidden bar slid away when you clicked its own tray icon.**
Opening a tray menu raises the popouts window — a fullscreen layer surface above
the bar, with a focus grab — so the pointer left the bar, `barHover.hovered`
dropped and the bar hid out from under the menu the click had just opened. The
bar's reveal condition tracked hover and nothing else, while the dock had always
had the equivalent (`_previewShowing || contextMenu.open`). It now also stays
revealed while it owns an open popout (matched by walking the requesting item's
parent chain to this bar's `contentItem`, so a second monitor's bar is
unaffected) or an open tooltip menu.

### Still open
- Keyboard traversal across whole panels (dashboard, launcher, centre) — the kit
  is ready, the panels still hand-roll their own `Keys.onPressed`.
- ~93 raw `Rectangle` in `features/` with no mechanical check. A ratchet is
  honest here; a ban is not, since several are legitimate (image backing with
  `clip`, 1px dividers, scrims).
- `ScrollableList` takes static children, not a model, so the "adopt it for the
  lists" item below cannot be done as written.

## Done — kit as the single point (2026-08)

Deep audit found the library was written but never made mandatory: **10 of 40
components were used zero times, and four of them covered exactly what features
were hand-rolling.** Adopting them, and making the kit hard to bypass:

- **`MotionAnimation` had 0 users against 109 hand-written easing pairs.** It
  exists precisely so the two halves of a curve cannot diverge — which is why
  the 4-value-bezier bug reached every site at once. All pairs are migrated
  (`MotionColorAnimation` added, since a NumberAnimation cannot stand in for a
  colour transition and a quarter of the pairs were `ColorAnimation`). Verified
  identical: hand-written pair and `MotionAnimation` both sample 793 at t=200 ms
  of a 1 s run, against 208 for linear. A bad `curve:` name falls back to
  `standard`, not to linear.
- `Scrim` → the 4 hand-rolled dimmers (three used a literal 0.32, the power menu
  0.5 for no recorded reason; the token is now the only source).
- `ProgressIndicator` → the 2 hand-rolled bars. Gained `animateValue`, because a
  caller already driving `value` from a running animation was a real reason to
  refuse the component, and that reason is now a parameter.
- `Badge` gained `inline` and replaced the hand-rolled pill inside `SectionHeader`
  — the kit was duplicating itself two directories away.
- **API made uniform.** `clicked` had three incompatible signatures; single-action
  controls now all use `clicked()`. `IconButton`'s `mouse` argument was never
  meaningful (its MouseArea only accepts the left button, so every
  `mouse.button === Qt.LeftButton` at a call site was always true). `BarElement`
  keeps its argument — all nine bar widgets branch on right-click, which is the
  kind of justification the rule asks for.
- `MaterialIcon` and `IconButton` gained `colorRole`, so the two most-used
  components no longer disagree with `MaterialText` about how a colour is named.
- Component fixes: `Divider`/`CircleAvatar`/`MaterialMarqueeText` no longer bind
  their own `width`/`height` (they fought every layout they were in);
  `MaterialIndicator` no longer animates `height` twice through `height: width`;
  `MaterialTextField` is finally Tab-reachable; hardcoded 0.12/0.08/0.87/0.38/0.6
  replaced with tokens; `MaterialMarqueeText.align` was a dead property whose
  only use was commented out.
- **`appearance.reduceMotion` and `appearance.motionScale`.** `Tokens.durationScale`
  worked all along but had no key — "reduce motion" was reachable only as a side
  effect of gaming mode. Gaming mode now flips `Tokens.motionFrozen` instead of
  assigning `durationScale`, which would have severed the config binding for good.

New invariants: `easing-pairs-by-hand` (0), `unknown-enum-literals` (0 — string
enums fall back silently on a typo, verified by running it), and a
`raw-rectangle-in-features` ratchet at 83 (down from 93; a ratchet rather than a
ban, since an image backing with `clip` or a 1px rule is legitimate).

### Justified non-adoptions
- `Snackbar` — MD3's snackbar is a single `inverseSurface` bar; `ToastOverlay`
  encodes severity by colour and takes its surface from `OsdSurface` (per-screen
  OSD infrastructure). Forcing it would nest two surfaces and lose severity.
- `SegmentedButton` for the dashboard tabs — MD3 distinguishes Tabs from
  Segmented Buttons; the gap is a missing `TabBar`, not a misuse.
- `Chip` for the cheatsheet keycaps — a keycap is a static token, not an
  interactive selection affordance. Also a kit gap.

`FAB`, `ListItem`, `MaterialCheckbox`, `CollapsibleSection` remain with no
adopter. They are complete and spec-correct; nothing in the shell needs them yet.

## Notifications — deferred

### Tests (Qt Test framework)
Mirror the calendar tests. Logic-only singletons are testable:
- `NotificationRateLimiter` — token-bucket math, queue behavior
- `NotificationHistory` — TTL pruning, grouping, persistence roundtrip
The 2026-08 pass verified behaviour end-to-end over D-Bus instead (eviction
accounting, DND/critical, transient, replacement, duplicate merge, filters);
that is reproducible but manual.

### Inline reply support
Quickshell supports `notification.sendInlineReply(text)`. Requires a text input in the popup; useful for clients that declare `inlineReplyPlaceholder`.

### Action icons
`actionIconsSupported` is not advertised and the UI doesn't show per-action icons. Advertising it means clients will send `iconName` per action and expect rendering.

---

## Calendar — deferred UI polish
- Localized weekday names (`Qt.locale().dayName(i, Locale.ShortFormat)`)
- "Today" button in the header
- Multi-day events in the timeline view
- Drag-to-reschedule in the day timeline
- Event search

---

## Out of scope
- **Full subprocess→DBus migration** — F5 gets the event-driven win; native BlueZ/NM D-Bus remains a later, separate project
- **Cross-shell pattern sharing / public packaging**
- **CI / unit tests for everything** — selectively for mission-critical components only
