#!/usr/bin/env bash
# Performance probes that measure a RUNNING shell from the outside, so a
# baseline costs no instrumentation and (except for `render`) no restart.
#
#   tools/perf-probe.sh events [secs] [log]   tap Hyprland's event socket
#   tools/perf-probe.sh analyze <log> [win_ms]  replay it through the shell's
#                                               own dispatch table
#   tools/perf-probe.sh scenario <name> [log]   scripted gesture + analyze
#   tools/perf-probe.sh cpu <secs>            per-thread CPU over a window
#   tools/perf-probe.sh panels [reps]         cost of opening each panel
#   tools/perf-probe.sh gestures [reps]       GUI cost of one compositor gesture
#   tools/perf-probe.sh ipc-cost [samples]    price one Hyprland IPC round trip
#   tools/perf-probe.sh render                RESTARTS the shell to capture
#                                             QSG_RENDER_TIMING, then restores
#   tools/perf-probe.sh rss                   one memory sample
#
# Read the numbers against the frame budget of the actual monitor: 144 Hz is
# 6.94 ms, 60 Hz is 16.7 ms. GUI-thread figures are the ones that turn into
# visible stutter, because a blocked GUI thread cannot feed the render thread.
set -u

root="$(cd "$(dirname "$0")/.." && pwd)"
runtime="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
sock="$runtime/hypr/${HYPRLAND_INSTANCE_SIGNATURE:-}/.socket2.sock"

py() { python3 -c "$1" "${@:2}"; }

# The shell binary answers to both names: /usr/bin/qs is a symlink to
# /usr/bin/quickshell, so `pgrep -x qs` finds nothing when it was started under
# the other one -- and it happily returns a ZOMBIE left by an earlier probe,
# whose /proc entries are unreadable. Every probe resolves the pid through here.
shell_pid() {
    local pid
    for pid in $(pgrep -x qs; pgrep -x quickshell); do
        case "$(awk '{print $3}' "/proc/$pid/stat" 2>/dev/null)" in
            Z|"") continue ;;
        esac
        printf '%s\n' "$pid"
        return 0
    done
    return 1
}

cmd_events() {
    local secs="${1:-15}" out="${2:-/dev/stdout}"
    [ -S "$sock" ] || { echo "no Hyprland event socket at $sock" >&2; exit 1; }
    echo "capturing ${secs}s of Hyprland events -> $out" >&2
    # python3, not `nc | awk`: the timestamp must come from the reader. A shell
    # pipeline either buffers the lines away or pays a `date` fork per event,
    # and an event burst is exactly what this measures.
    SECS="$secs" OUT="$out" SOCK="$sock" py '
import os, socket, time
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.connect(os.environ["SOCK"]); s.settimeout(0.25)
deadline = time.monotonic() + float(os.environ["SECS"])
buf = b""
with open(os.environ["OUT"], "w") as f:
    while time.monotonic() < deadline:
        try: chunk = s.recv(65536)
        except socket.timeout: continue
        if not chunk: break
        now = int(time.monotonic() * 1000)
        buf += chunk
        *lines, buf = buf.split(b"\n")
        for line in lines:
            f.write("%d %s\n" % (now, line.decode(errors="replace")))
        f.flush()
'
    echo "captured $(wc -l < "$out") events" >&2
}

# The dispatch table below MUST mirror src/core/services/HyprlandWindowService.qml.
# A stale copy reports a baseline for code that no longer exists.
#
# The COALESCED column is a model, kept for the event-shape it exposes -- do not
# read it as work waiting to be done. Coalescing was implemented and measured in
# 2026-08 and changed nothing, because a refresh call costs microseconds and a
# gesture's burst dirties distinct targets rather than duplicates. Removing every
# refresh call outright saves 6% of a workspace switch. See the ROADMAP entry.
cmd_analyze() {
    local log="${1:?usage: analyze <logfile> [window_ms]}" win="${2:-40}"
    awk -v WIN="$win" '
        function refreshes(n) {
            if (n ~ /v2$/) return ""                         # explicitly ignored
            if (n == "workspace" || n == "moveworkspace" ||
                n == "activespecial" || n == "focusedmon")    return "W M"
            if (n == "openwindow" || n == "closewindow" ||
                n == "movewindow" || n == "exec")             return "T W"
            if (index(n, "mon"))                              return "M"
            if (index(n, "workspace"))                        return "W"
            if (index(n, "window") || index(n, "group") ||
                n == "pin" || n == "fullscreen" ||
                n == "changefloatingmode" || n == "minimize") return "T"
            return ""
        }
        {
            ts = $1; split($2, p, ">>"); name = p[1]
            seen[name]++; total++
            r = refreshes(name)
            if (r == "") { ignored++; next }
            split(r, f, " ")
            for (i in f) { cur++; curKind[f[i]]++; byName[name]++ }
            # A burst is a run of events no more than WIN apart. Coalescing
            # replaces it with one refresh per DISTINCT target, which is why a
            # burst of four events can still cost three calls.
            if (burstEnd == 0 || ts > burstEnd) {
                for (k in pend) { coal++; coalKind[k]++ }
                delete pend; bursts++
                if (inBurst > maxBurst) maxBurst = inBurst
                inBurst = 0
            }
            burstEnd = ts + WIN; inBurst++
            for (i in f) pend[f[i]] = 1
        }
        END {
            for (k in pend) { coal++; coalKind[k]++ }
            if (inBurst > maxBurst) maxBurst = inBurst
            printf "events                  : %d total, %d ignored\n", total, ignored
            printf "bursts (<= %d ms apart)  : %d, largest %d events\n", WIN, bursts, maxBurst
            printf "refresh calls NOW       : %-4d (toplevels %d, workspaces %d, monitors %d)\n", \
                   cur, curKind["T"], curKind["W"], curKind["M"]
            printf "refresh calls COALESCED : %-4d (toplevels %d, workspaces %d, monitors %d)\n", \
                   coal, coalKind["T"], coalKind["W"], coalKind["M"]
            if (cur > 0)
                printf "coalescing saves        : %.0f%% (%d of %d)\n", \
                       (cur - coal) * 100.0 / cur, cur - coal, cur
            printf "\nrefresh calls charged to each event:\n"
            for (n in byName)
                printf "  %-22s %4d calls / %4d events -> %s\n", n, byName[n], seen[n], refreshes(n)
        }
    ' "$log"
}

# Dispatch goes through the Lua form Hyprland 0.56 requires; see
# HyprlandDispatch.qml for why the string form silently does nothing.
cmd_scenario() {
    local name="${1:?usage: scenario <ws-switch|focus|window> [logfile]}"
    local out="${2:-/tmp/perf-probe-$name.log}"
    cmd_events 14 "$out" &
    local cap=$!
    SCENARIO="$name" py '
import json, os, subprocess, time
def dsp(e, s=0.35):
    subprocess.run(["hyprctl", "dispatch", e], stdout=subprocess.DEVNULL); time.sleep(s)
name = os.environ["SCENARIO"]
time.sleep(1.0)
if name == "ws-switch":
    for _ in range(3):
        dsp("hl.dsp.focus({workspace=3})"); dsp("hl.dsp.focus({workspace=2})")
elif name == "focus":
    cl = json.loads(subprocess.check_output(["hyprctl", "-j", "clients"]))
    ws = json.loads(subprocess.check_output(["hyprctl", "-j", "activeworkspace"]))["id"]
    a = [c["address"] for c in cl if c["workspace"]["id"] == ws]
    if len(a) < 2: raise SystemExit("focus scenario needs 2 windows on the active workspace")
    for i in range(12): dsp("hl.dsp.focus({window=\"address:%s\"})" % a[i % 2])
elif name == "window":
    for _ in range(2):
        subprocess.run(["hyprctl", "dispatch",
                        "hl.dsp.exec({\"kitty --title perfprobe -e sleep 2\"})"],
                       stdout=subprocess.DEVNULL)
        time.sleep(3.2)
time.sleep(1.0)
'
    wait "$cap"
    echo
    cmd_analyze "$out"
}

# schedstat, not /proc/pid/stat: clock ticks are 10 ms, far too coarse for a
# gesture. And it must be summed over task/*, because /proc/PID/schedstat is
# the main thread ONLY -- the render threads and the MCU pool are where a
# large share of the work actually lands.
_cpu_snippet='
import os, time
def snap(pid):
    o = {}
    for t in os.listdir("/proc/%d/task" % pid):
        try:
            o[t] = (open("/proc/%d/task/%s/comm" % (pid, t)).read().strip(),
                    int(open("/proc/%d/task/%s/schedstat" % (pid, t)).read().split()[0]))
        except OSError: pass
    return o
def diff(a, b):
    return sorted(((ns - a.get(t, (nm, ns))[1]) / 1e6, nm, t) for t, (nm, ns) in b.items())[::-1]
def gui(a, b, pid):
    t = str(pid)
    return (b[t][1] - a.get(t, (0, b[t][1]))[1]) / 1e6
'

cmd_cpu() {
    local secs="${1:-10}"
    SECS="$secs" SHELL_PID="$(shell_pid)" py "$_cpu_snippet"'
import subprocess
pid = int(os.environ["SHELL_PID"])
a = snap(pid); time.sleep(float(os.environ["SECS"])); b = snap(pid)
rows = [r for r in diff(a, b) if r[0] > 0.2]
print("cpu over %s s (threads: %d)" % (os.environ["SECS"], len(b)))
print("  total %.2f ms, gui thread %.2f ms" % (sum(r[0] for r in rows), gui(a, b, pid)))
for ms, nm, t in rows[:8]:
    print("   %8.2f ms  %s (tid %s)" % (ms, nm, t))
'
}

# Every panel is a LazyLoader keyed on its open flag, so it is torn down on
# close and rebuilt on open. That makes the SECOND open as expensive as the
# first minus QML compilation -- which is what this separates.
cmd_panels() {
    local reps="${1:-5}"
    REPS="$reps" ROOT="$root" SHELL_PID="$(shell_pid)" py "$_cpu_snippet"'
import subprocess
pid = int(os.environ["SHELL_PID"])
def ipc(*a):
    subprocess.run(["qs", "-p", os.environ["ROOT"], "ipc", "call", *a],
                   capture_output=True, text=True)
panels = [("launcher",   ("globalstates","openLauncher"),   ("globalstates","closeLauncher")),
          ("dashboard",  ("globalstates","toggleDashboard"),("globalstates","toggleDashboard")),
          ("cheatsheet", ("globalstates","openCheatsheet"), ("globalstates","closeCheatsheet"))]
n = int(os.environ["REPS"])
for name, op, cl in panels:
    opens = []
    for i in range(n):
        time.sleep(0.9)
        a = snap(pid); ipc(*op); time.sleep(0.85); b = snap(pid)
        opens.append(gui(a, b, pid))
        ipc(*cl); time.sleep(0.6)
    print("%-11s open: first %6.2f ms   warm %6.2f ms (median of %d)  gui thread" %
          (name, opens[0], sorted(opens[1:])[len(opens[1:])//2], n - 1))
ipc("globalstates", "closeAll")
'
}

# GUI-thread cost of one compositor gesture. This is what event coalescing
# moves: the refresh calls themselves are microseconds (see ipc-cost), the
# expense is the model rebuild and the binding invalidation it fans out to.
cmd_gestures() {
    local reps="${1:-10}"
    REPS="$reps" SHELL_PID="$(shell_pid)" py "$_cpu_snippet"'
import json, subprocess
pid = int(os.environ["SHELL_PID"])
N = int(os.environ["REPS"])

def gui_over(fn):
    f = "/proc/%d/task/%d/schedstat" % (pid, pid)
    time.sleep(0.6)
    a = int(open(f).read().split()[0]); fn(); b = int(open(f).read().split()[0])
    return (b - a) / 1e6

def dsp(e, s=0.30):
    subprocess.run(["hyprctl", "dispatch", e], stdout=subprocess.DEVNULL); time.sleep(s)

idle = gui_over(lambda: time.sleep(N * 0.30))
print("idle control (%d x 0.30s)   %7.2f ms total" % (N, idle))

ws = gui_over(lambda: [dsp("hl.dsp.focus({workspace=%d})" % (3 if i % 2 == 0 else 2))
                       for i in range(N)])
print("workspace switch           %7.2f ms total   %6.2f ms per gesture" % (ws, (ws - idle) / N))

cl = json.loads(subprocess.check_output(["hyprctl", "-j", "clients"]))
wsid = json.loads(subprocess.check_output(["hyprctl", "-j", "activeworkspace"]))["id"]
addrs = [c["address"] for c in cl if c["workspace"]["id"] == wsid]
if len(addrs) >= 2:
    dsp("hl.dsp.focus({window=\"address:%s\"})" % addrs[0])
    fc = gui_over(lambda: [dsp("hl.dsp.focus({window=\"address:%s\"})" % addrs[i % 2])
                           for i in range(N)])
    print("focus change (%d windows)   %7.2f ms total   %6.2f ms per gesture"
          % (len(addrs), fc, (fc - idle) / N))
else:
    print("focus change               skipped: needs 2 windows on the active workspace")
'
}

cmd_ipc_cost() {
    local n="${1:-200}"
    N="$n" py '
import json, os, socket, time
runtime = os.environ.get("XDG_RUNTIME_DIR") or "/run/user/%d" % os.getuid()
path = "%s/hypr/%s/.socket.sock" % (runtime, os.environ["HYPRLAND_INSTANCE_SIGNATURE"])
def call(cmd):
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM); s.connect(path)
    s.sendall(cmd.encode()); buf = b""
    while True:
        c = s.recv(65536)
        if not c: break
        buf += c
    s.close(); return buf
N = int(os.environ["N"])
# hyprctl would add a ~1.5 ms fork to every sample; the shell speaks the socket
# in-process, so only the raw round trip and the parse are the real price.
for what in ("clients", "workspaces", "monitors"):
    buf = call("j/" + what)
    t0 = time.perf_counter()
    for _ in range(N): call("j/" + what)
    t1 = time.perf_counter()
    for _ in range(N): json.loads(buf)
    t2 = time.perf_counter()
    print("%-11s ipc %6.3f ms  parse %6.3f ms  total %6.3f ms  payload %d B" %
          (what, (t1-t0)/N*1000, (t2-t1)/N*1000, (t2-t0)/N*1000, len(buf)))
'
}

# The only probe that restarts the shell: QSG_RENDER_TIMING is read at startup.
# The restore runs from a finally block, so an aborted scenario still leaves a
# working shell behind.
cmd_render() {
    local out="${1:-/tmp/perf-probe-render.log}"
    OUT="$out" ROOT="$root" py '
import os, signal, subprocess, time
# Inherit the environment the live shell actually runs with -- guessing
# QT_QPA_PLATFORM here is how a probe ends up measuring a different shell
# than the one the user has.
ENV = dict(os.environ)
def pid():
    r = subprocess.run(["bash", "-c", "pgrep -x qs; pgrep -x quickshell"],
                       capture_output=True, text=True)
    for line in r.stdout.split():
        try:
            if open("/proc/%s/stat" % line).read().split()[2] != "Z":
                return int(line)
        except OSError:
            continue
    return None
_live = pid()
if _live:
    for kv in open("/proc/%d/environ" % _live, "rb").read().split(b"\0"):
        if b"=" in kv:
            k, v = kv.decode(errors="replace").split("=", 1)
            if k.startswith(("QT_", "QSG_", "QML", "WAYLAND_", "XDG_", "HYPRLAND_")):
                ENV[k] = v
# Relaunch exactly the way the shell was already running: it answers to both
# `qs` and `quickshell`, and restoring it under a different argv would leave the
# user with a shell their session did not start.
ARGV = ["qs", "--config", "shell"]
if _live:
    try:
        raw = open("/proc/%d/cmdline" % _live, "rb").read().split(b"\0")
        argv = [a.decode() for a in raw if a]
        if argv:
            ARGV = argv
    except OSError:
        pass

def launch(extra, log):
    e = dict(ENV); e.update(extra)
    subprocess.Popen(ARGV, env=e, stdout=open(log, "w"),
                     stderr=subprocess.STDOUT, start_new_session=True)
    for _ in range(60):
        time.sleep(0.5)
        if pid(): return
    raise RuntimeError("shell did not come up")
def stop():
    p = pid()
    if not p: return
    os.kill(p, signal.SIGTERM)
    for _ in range(40):
        time.sleep(0.25)
        if not pid(): return
    os.kill(p, signal.SIGKILL); time.sleep(1)
out = os.environ["OUT"]
try:
    stop(); launch({"QSG_RENDER_TIMING": "1"}, out); time.sleep(6)
    for i in range(6):
        subprocess.run(["hyprctl", "dispatch",
                        "hl.dsp.focus({workspace=%d})" % (3 if i % 2 == 0 else 2)],
                       stdout=subprocess.DEVNULL)
        time.sleep(0.4)
    for _ in range(4):
        for fn in ("openLauncher", "closeLauncher"):
            subprocess.run(["qs", "-p", os.environ["ROOT"], "ipc", "call", "globalstates", fn],
                           capture_output=True)
            time.sleep(0.9)
finally:
    stop(); launch({}, "/tmp/perf-probe-restore.log")
    print("shell restored, pid", pid())
'
    LOG="$out" py '
import collections, os, re
lines = open(os.environ["LOG"], errors="replace").read()
lines = re.sub(r"\x1b\[[0-9;]*m", "", lines).splitlines()
fr = re.compile(r"syncAndRender: frame rendered in (\d+)ms, sync=(\d+), render=(\d+), swap=(\d+)")
pr = re.compile(r"Frame prepared, polish=(\d+) ms, lock=(\d+) ms, blockedForSync=(\d+) ms")
f = [tuple(map(int, m.groups())) for m in map(fr.search, lines) if m]
p = [tuple(map(int, m.groups())) for m in map(pr.search, lines) if m]
if not f: raise SystemExit("no frame timings in log")
tot = [x[0] for x in f]
print("frames %d   mean %.2f ms   max %d ms   over 6.94 ms: %d (%.1f%%)" %
      (len(f), sum(tot)/len(tot), max(tot), sum(1 for t in tot if t > 6.94),
       sum(1 for t in tot if t > 6.94)*100.0/len(tot)))
print("render-thread split: sync %d ms, render %d ms, swap %d ms  (swap is vsync wait, not work)" %
      (sum(x[1] for x in f), sum(x[2] for x in f), sum(x[3] for x in f)))
if p:
    bl = [x[2] for x in p]
    print("gui blockedForSync : total %d ms, max %d ms, >5 ms in %d of %d" %
          (sum(bl), max(bl), sum(1 for b in bl if b > 5), len(bl)))
'
}

cmd_rss() {
    local pid; pid="$(shell_pid)" || { echo "no running shell (qs/quickshell)" >&2; exit 1; }
    awk '/^VmRSS|^VmHWM|^Threads/{printf "%-9s %s %s\n", $1, $2, $3}' "/proc/$pid/status"
    printf '%-9s %s\n' "fds" "$(ls "/proc/$pid/fd" | wc -l)"
}

case "${1:-}" in
    events)   shift; cmd_events   "$@" ;;
    analyze)  shift; cmd_analyze  "$@" ;;
    scenario) shift; cmd_scenario "$@" ;;
    cpu)      shift; cmd_cpu      "$@" ;;
    panels)   shift; cmd_panels   "$@" ;;
    gestures) shift; cmd_gestures "$@" ;;
    ipc-cost) shift; cmd_ipc_cost "$@" ;;
    render)   shift; cmd_render   "$@" ;;
    rss)      shift; cmd_rss      "$@" ;;
    *) sed -n '2,18p' "$0" >&2; exit 2 ;;
esac
