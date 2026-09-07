pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.src.core.config

// Screen recording state, observed rather than owned.
//
// The shell does not start these recordings -- gpu-screen-recorder is launched
// by whatever the user bound it to -- but it can see them, time them and drive
// their pause/stop, so a recording can never be left running unnoticed.
//
// Everything here keys on ONE thing: the gsr `-ipc` socket path. gsr refuses to
// start when that socket is already bound ("another program is already
// listening"), which makes the path a natural mutex -- one recording at a time,
// enforced by gsr itself -- and makes any recording started with it fully
// controllable from here.
Singleton {
    id: root

    // Where the recorder's control socket lives. Anything started with a
    // DIFFERENT -ipc path is invisible here; that is deliberate, since a
    // recording this service cannot control is one it should not offer buttons
    // for.
    readonly property string socketPath: AppConfig.recorderSocket !== ""
        ? AppConfig.recorderSocket
        : (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/gsr-record.sock"

    // A recording is live only when the socket exists AND a process is holding
    // it. The socket file alone is not proof: a recorder killed with SIGKILL
    // leaves it behind, and gsr-cli then correctly reports "not running".
    //
    // Nor is a live process quite enough for a recording WE started: gsr binds
    // the socket before the portal has been answered, so between the keypress
    // and the source being chosen there is a running recorder capturing
    // nothing. Showing "00:00" over an open portal picker -- with pause and stop
    // buttons for a recording that has not begun -- is a lie, so a recording the
    // shell starts waits until the recorder actually writes something.
    // Recordings found already running are unaffected: nothing is pending for
    // them.
    readonly property bool active: _socketPresent && _pid > 0 && !_awaitingOutput
    readonly property bool available: _toolPresent

    property bool paused: false
    readonly property int elapsedSeconds: _elapsedSeconds
    readonly property string elapsedText: {
        const s = root._elapsedSeconds
        const hh = Math.floor(s / 3600)
        const mm = Math.floor((s % 3600) / 60)
        const ss = s % 60
        const pad = (n) => n < 10 ? "0" + n : "" + n
        return hh > 0 ? `${hh}:${pad(mm)}:${pad(ss)}` : `${pad(mm)}:${pad(ss)}`
    }

    // Which monitor the capture covers, when it can be known at all. Used to
    // keep the indicator off the monitor being recorded -- an overlay layer IS
    // composited into the captured frame.
    //
    // Two sources, because neither covers everything. The compositor's
    // screencast event names the monitor for a portal capture, but ONLY around
    // the moment capture starts: it fires a handful of paired start/stop events
    // while the portal session settles (measured: four 1/0 pairs in 20 s) and
    // then goes completely silent for the rest of the recording (measured: zero
    // events in 22 s mid-recording). So the value is latched on a start event
    // and cleared only when the recording ends -- clearing it on each `0` would
    // discard it seconds after learning it.
    //
    // That leaves a shell started mid-recording knowing nothing, and a KMS
    // capture raising no events at all. Hence the second source: the recorder's
    // own arguments, which name the monitor directly for `-w <output>`.
    property string capturedMonitor: ""

    property bool _toolPresent: false
    property bool _socketPresent: false
    property int _pid: 0
    property int _elapsedSeconds: 0
    property double _startEpochMs: 0

    // Rolling samples of (cpu ticks, bytes written) used for pause detection.
    property var _samples: []
    property int _probeAttempts: 0
    readonly property int _maxProbeAttempts: 3

    // Set while a recording this shell started has yet to produce a byte.
    property bool _awaitingOutput: false
    // Set once such a recording has been timed from its first byte rather than
    // from when its process was launched.
    property bool _timedFromOutput: false
    property double _baselineWritten: -1

    // Kernel tick rate. Universally 100 on Linux; only used to convert the
    // process start time into an age, so a wrong value would show a wrong
    // duration, not break detection.
    readonly property int _clockTicks: 100

    // --- Control -------------------------------------------------------------

    // Start / stop is the pair that belongs on a key. The rest exists because a
    // recording that cannot be paused from the same place is half a control.
    function toggle() {
        if (root._pid > 0)
            root.stop()
        else
            root.start()
    }

    // `forcePicker` starts a recording with the portal's own selector open,
    // whatever restorePortalSession says. That selector offers screen, window
    // AND region -- it draws the region rectangle itself -- so recording part of
    // the screen needs no picker of the shell's own, and the token it hands back
    // means the next plain start reuses that same region.
    function start(forcePicker) {
        // Guarded on the PROCESS, not on `active`. A recording still waiting for
        // its portal answer is not active yet, and starting a second recorder
        // then was harmless only by luck -- gsr refuses the bound socket -- but
        // it truncated the running recorder's log on the way out.
        if (root._pid > 0) {
            ToastService.warning(root.active ? "Already recording"
                                             : "A recording is already starting")
            return
        }
        if (!root._toolPresent) {
            ToastService.error("gpu-screen-recorder is not installed")
            return
        }
        if (startProc.running)
            return

        const target = AppConfig.recorderTarget
        // Config is not hostile input, but this value reaches a command line and
        // the check costs nothing.
        if (!/^[A-Za-z0-9_.:-]+$/.test(target)) {
            ToastService.error("recorder.capture.target is not a valid capture source")
            return
        }

        const dir = AppConfig.recorderDirectory !== ""
            ? AppConfig.recorderDirectory
            : (Quickshell.env("HOME") || "") + "/Videos/Recordings"
        const stamp = Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss")
        const output = dir + "/" + stamp + "." + AppConfig.recorderContainer

        let args = ["-w", target,
                    "-f", String(AppConfig.recorderFps),
                    "-fm", AppConfig.recorderFramerateMode,
                    "-k", AppConfig.recorderCodec,
                    "-q", AppConfig.recorderQuality,
                    "-c", AppConfig.recorderContainer,
                    "-cursor", AppConfig.recorderCursor ? "yes" : "no",
                    "-ipc", root.socketPath,
                    "-o", output]
        if (target === "portal") {
            const restore = AppConfig.recorderRestorePortal && !forcePicker
            args = args.concat(["-restore-portal-session", restore ? "yes" : "no"])
        } else if (forcePicker) {
            // Only the portal has a selector; a direct KMS or window capture is
            // already told exactly what to record.
            ToastService.warning("Source picking needs recorder.capture.target = portal")
        }
        for (const source of AppConfig.recorderAudioSources)
            args = args.concat(["-a", source])

        // The wrapper script is a LITERAL -- every variable part arrives as a
        // positional argument, so nothing here can break out of quoting. It
        // exists for two things the recorder needs and argv cannot express:
        // creating the output directory, and sending the recorder's own chatter
        // (it prints an fps line every second) to a log instead of the shell's.
        // Truncating rather than appending keeps that log from growing forever.
        // `exec` replaces the shell, so the recorder keeps the pid that
        // detection finds through the socket.
        startProc.command = ["sh", "-c",
            'log="$1"; dir="$2"; shift 2; mkdir -p "$dir" || exit 1; exec gpu-screen-recorder "$@" >"$log" 2>&1',
            "sh", root.logPath, dir].concat(args)
        // Only the portal path can leave a recorder running while nothing is
        // being captured -- it is the only one that stops to ask. A direct KMS
        // or window capture begins at once, so making it wait would only delay
        // the indicator behind a variable-framerate recorder's first write,
        // which on a still screen is seconds away.
        root._awaitingOutput = target === "portal"
        root._baselineWritten = -1
        root._timedFromOutput = false
        startProc.running = true
    }

    function togglePause() {
        root.setPaused(!root.paused)
    }

    readonly property string logPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/gsr-record.log"

    function setPaused(on) {
        // On the process, not on `active`: a recording still waiting for its
        // portal answer is one the shell started and must still be able to
        // control -- otherwise it can neither be paused nor stopped.
        if (root._pid <= 0 || on === root.paused)
            return
        // Answer immediately rather than waiting for the sampler below to
        // notice: a command we issued ourselves needs no evidence. Dropping the
        // samples with it matters -- without that the sampler still holds a
        // window full of pre-command evidence and overwrites this on its very
        // next tick, which is exactly what it did.
        root.paused = on
        root._samples = []
        _runCommand(["set-paused", on ? "true" : "false"])
    }

    function stop() {
        if (root._pid <= 0)
            return
        _runCommand(["stop"])
    }

    function _runCommand(args) {
        if (!root._toolPresent || controlProc.running)
            return
        controlProc.command = ["gsr-cli", "-ipc", root.socketPath].concat(args)
        controlProc.running = true
    }

    // The recorder outlives this object: a Quickshell child survives the shell
    // exiting, verified for both a clean quit and a SIGKILL. So the handle is
    // for diagnosis, not ownership -- after a hot reload the recording is still
    // running and is picked up again through the socket, exactly like one the
    // shell never started.
    Process {
        id: startProc
        onExited: (exitCode) => {
            // A normal stop exits 0 here, and so does one triggered from
            // somewhere else entirely. Only a real failure is worth a toast --
            // most often a portal picker that was dismissed.
            if (exitCode !== 0)
                ToastService.error("Recording failed to start (exit " + exitCode + ") - see " + root.logPath)
        }
    }

    Process {
        id: controlProc
        stdout: StdioCollector {
            onStreamFinished: {
                const out = text.trim()
                if (out !== "")
                    ToastService.success("Recording saved: " + out.split("/").pop())
            }
        }
        onExited: (exitCode) => {
            if (exitCode !== 0)
                ToastService.error("gsr-cli failed (exit " + exitCode + ")")
        }
    }

    // --- Detection -----------------------------------------------------------

    // Does the control socket exist? A unix socket cannot be READ, so a
    // successful load never happens here -- the two failure codes are the
    // answer: NotAFile means something non-regular is at that path (the
    // socket), FileNotFound means nothing is.
    FileView {
        id: socketProbe
        path: root.socketPath
        // The socket being absent is the ANSWER here, not a fault -- it is what
        // "no recording" looks like, and it is re-checked every few seconds for
        // the whole session. Left on, it wrote a warning per tick forever.
        printErrors: false
        onLoadFailed: (error) => {
            const present = error === FileViewError.NotAFile
            if (present === root._socketPresent)
                return
            root._socketPresent = present
            root._probeAttempts = 0
            if (present)
                pidProc.start()
            else
                root._reset()
        }
        // A regular file at the socket path is not a recorder.
        onLoaded: root._socketPresent = false
    }

    // The socket path appears and disappears without any notification of its
    // own -- a watcher on a path that does not exist yet never fires -- so it
    // has to be re-checked. This is one stat syscall, no process involved.
    // While a recording runs the same tick also advances the clock, which is
    // why the interval tightens.
    Timer {
        running: root._toolPresent
        // Keyed on there being something to watch, not on `active`: a recording
        // waiting for its portal answer is not active yet, and a start this
        // shell has just issued has no process to find yet -- both are exactly
        // when the fast tick is needed.
        interval: (root._pid > 0 || root._awaitingOutput) ? 1000 : 5000
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            socketProbe.reload()
            if (root._pid > 0) {
                statFile.reload()
            } else if (root._socketPresent && !pidProc.running
                       && root._probeAttempts < root._maxProbeAttempts) {
                // A few retries rather than only the moment the socket appears:
                // keying the search on that transition alone meant a single lost
                // pid could never be recovered, since no further transition would
                // come while the socket stayed put.
                //
                // Bounded, though. A recorder killed with SIGKILL leaves its
                // socket behind for good, and retrying forever would fork pgrep
                // every five seconds for the rest of the session over a file
                // nobody owns. The owner exists from the moment the socket does,
                // so if three tries do not find it, there is none.
                pidProc.start()
            }
        }
    }

    // A capture starting is a reason to look NOW rather than wait out the poll
    // above. Cheap enough to do on every such event: it re-stats one path.
    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name !== "screencastv2")
                return
            const parts = String(event.data).split(",")
            if (parts[0] !== "1")
                return
            if (parts[1] === "monitor" && parts.length > 2)
                root.capturedMonitor = parts[2]
            // Also a confirmation that capture has really begun -- but a late
            // one, measured arriving nearly nine seconds after the recorder was
            // launched, well after its first bytes. Kept as a backstop for a
            // capture that writes nothing at all early on; the bytes normally
            // get there first.
            if (root._awaitingOutput)
                root._markProducing()
            socketProbe.reload()
        }
    }

    // Which process holds the socket. Matching on the socket PATH rather than
    // on the program name picks out exactly the recorder this service tracks,
    // and sidesteps pgrep's 15-character limit on process names.
    Process {
        id: pidProc
        command: ["pgrep", "-f", root.socketPath]

        function start() {
            if (!running) {
                root._probeAttempts++
                running = true
            }
        }

        stdout: StdioCollector {
            onStreamFinished: {
                const pid = parseInt(text.trim().split("\n")[0], 10)
                if (!isNaN(pid) && pid > 0) {
                    root._pid = pid
                    root._samples = []
                    root.paused = false
                    statFile.reload()
                    cmdlineFile.reload()
                } else {
                    // Socket with no owner: a recorder that died without
                    // cleaning up. Not a recording.
                    root._reset()
                }
            }
        }
    }

    // The recorder's argv, read once when a recording is found. `-w` takes
    // either a capture method (portal, region, focused, a window) or the name of
    // an output; only the latter tells us which monitor is being recorded, and
    // it is the case the compositor never reports.
    FileView {
        id: cmdlineFile
        path: root._pid > 0 ? "/proc/" + root._pid + "/cmdline" : ""
        onLoaded: {
            // argv arrives NUL-separated.
            const argv = text().split("\u0000")
            const at = argv.indexOf("-w")
            if (at === -1 || at + 1 >= argv.length)
                return
            const target = argv[at + 1]
            if (Quickshell.screens.some(s => s.name === target))
                root.capturedMonitor = target
        }
    }

    // --- Sampling ------------------------------------------------------------

    FileView {
        id: statFile
        path: root._pid > 0 ? "/proc/" + root._pid + "/stat" : ""
        // The recording ending is seen here first: the process is gone.
        //
        // Only when there was a process to lose. With no pid the path is empty
        // and the failure means nothing -- and it arrives asynchronously, so it
        // could land AFTER the pid had just been found and wipe it, leaving a
        // running recording undetectable.
        onLoadFailed: if (root._pid > 0) root._reset()
        onLoaded: {
            const stat = text()
            // The comm field is parenthesised and may itself contain spaces or
            // parentheses, so fields are counted from the LAST ')'.
            const tail = stat.slice(stat.lastIndexOf(")") + 2).split(" ")
            const cpuTicks = parseInt(tail[11], 10) + parseInt(tail[12], 10)
            const startTicks = parseInt(tail[19], 10)

            if (root._startEpochMs === 0 && !isNaN(startTicks))
                uptimeFile.reload()
            if (root._startEpochMs > 0)
                root._elapsedSeconds = Math.max(0, Math.floor((Date.now() - root._startEpochMs) / 1000))
            root._startTicks = startTicks
            // Set BEFORE the read that consumes it: reload() is asynchronous but
            // its handler must not be able to pick up the previous tick's value.
            root._pendingCpu = cpuTicks
            ioFile.reload()
        }
    }

    property int _startTicks: 0
    property int _pendingCpu: 0

    // Process age, read once per recording. Taken from the process itself
    // rather than from when this service noticed it, so a shell restarted
    // mid-recording still shows the true duration.
    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        onLoaded: {
            const up = parseFloat(text().split(" ")[0])
            // Never overwrite a clock already started from real output.
            if (!isNaN(up) && root._startTicks > 0 && !root._timedFromOutput)
                root._startEpochMs = Date.now() - (up - root._startTicks / root._clockTicks) * 1000
        }
    }

    FileView {
        id: ioFile
        path: root._pid > 0 ? "/proc/" + root._pid + "/io" : ""
        onLoaded: {
            const line = text().split("\n").find(l => l.startsWith("write_bytes:"))
            const written = line ? parseInt(line.split(":")[1].trim(), 10) : 0
            root._addSample(root._pendingCpu, written)
        }
    }

    // Pause detection, and why it is inferred rather than asked for.
    //
    // gsr exposes no paused state at all: `gsr-cli status` answers "running"
    // either way, and the PipeWire stream stays alive. What changes is that the
    // process stops working -- but neither available signal is readable at
    // one-second granularity. Writes reach the block layer in bursts (measured:
    // four of six one-second samples read ZERO during a perfectly normal
    // recording), so a short window produces false pauses.
    //
    // Over a six-second window the two separate. Bytes written is the sharp
    // signal -- exactly zero when paused, never zero across a window that long
    // when running. CPU time is the guard against a genuinely idle screen, where
    // a variable-framerate capture may legitimately write nothing: measured at
    // 3-4 ticks per six seconds paused, against 12 for a small capture and 25
    // for a full-size one. The threshold sits between them.
    //
    // The cost is that an externally triggered pause takes about six seconds to
    // appear. A pause issued from this shell shows at once -- see setPaused.
    readonly property int _sampleWindow: 7
    readonly property int _pausedCpuTicks: 6

    function _addSample(cpuTicks, written) {
        if (root._awaitingOutput) {
            if (root._baselineWritten < 0) {
                root._baselineWritten = written
            } else if (written > root._baselineWritten) {
                root._markProducing()
            }
        }

        const next = root._samples.slice()
        next.push({ cpu: cpuTicks, written: written })
        if (next.length > root._sampleWindow)
            next.shift()
        root._samples = next

        // A partial window says nothing, and says it loudly enough to overwrite
        // a state the user just asked for. Wait for the evidence.
        if (next.length < root._sampleWindow)
            return
        const oldest = next[0]
        const newest = next[next.length - 1]
        root.paused = (newest.written - oldest.written) === 0
            && (newest.cpu - oldest.cpu) <= root._pausedCpuTicks
    }

    // Capture has actually begun. Time it from HERE, not from when the process
    // was launched: gsr starts before the portal has been answered, so the
    // process age includes however long the source was being chosen, and the
    // clock would open at the length of that deliberation instead of at zero.
    function _markProducing() {
        if (!root._awaitingOutput)
            return
        root._awaitingOutput = false
        root._startEpochMs = Date.now()
        root._timedFromOutput = true
        // This tick may already have computed a duration from the old baseline
        // further up the chain; without this the clock shows the length of the
        // wait once, on the very frame it becomes visible.
        root._elapsedSeconds = 0
    }

    function _reset() {
        root._pid = 0
        root._awaitingOutput = false
        root._baselineWritten = -1
        root._timedFromOutput = false
        root._elapsedSeconds = 0
        root._startEpochMs = 0
        root._startTicks = 0
        root._samples = []
        root.paused = false
        root.capturedMonitor = ""
    }

    // --- Availability --------------------------------------------------------

    // With no gsr-cli on the system there is nothing to detect and nothing to
    // control, so the poll timer above never starts.
    Process {
        id: detectProc
        command: ["which", "gsr-cli"]
        onExited: (exitCode) => root._toolPresent = exitCode === 0
    }

    Component.onCompleted: detectProc.running = true

    // --- External control ----------------------------------------------------

    // Quickshell does not export GlobalShortcut declaratively, so qmllint cannot
    // resolve a type that ten other shortcuts in this shell already use at
    // runtime. Suppressed here rather than left to grow the warning baseline.
    // qmllint disable unresolved-type
    GlobalShortcut {
        name: "recorderToggle"
        description: "Start a screen recording, or stop the running one"
        onPressed: root.toggle()
    }

    GlobalShortcut {
        name: "recorderPick"
        description: "Start a screen recording, choosing screen, window or region in the portal picker"
        onPressed: root.start(true)
    }

    GlobalShortcut {
        name: "recorderTogglePause"
        description: "Pause or resume the running screen recording"
        onPressed: root.togglePause()
    }

    GlobalShortcut {
        name: "recorderStop"
        description: "Stop and save the running screen recording"
        onPressed: root.stop()
    }

    // qmllint enable unresolved-type

    IpcHandler {
        target: "recorder"

        function status(): string {
            if (!root.available)
                return "unavailable (gsr-cli not found)"
            if (!root.active)
                return "idle"
            return (root.paused ? "paused " : "recording ") + root.elapsedText
        }

        function start(): void {
            root.start()
        }

        function toggle(): void {
            root.toggle()
        }

        function pick(): void {
            root.start(true)
        }

        function elapsed(): int {
            return root.elapsedSeconds
        }

        function pause(): void {
            root.setPaused(true)
        }

        function resume(): void {
            root.setPaused(false)
        }

        function togglePause(): void {
            root.togglePause()
        }

        function stop(): void {
            root.stop()
        }
    }
}
