#!/usr/bin/env bash
# Compile every QML component with the real Quickshell engine.
#
# WHY THIS EXISTS, and why qmllint is not enough:
#
# qmllint accepts a file with TWO `pragma ComponentBehavior` lines — exit 0, no
# diagnostic. The Quickshell loader rejects it ("Multiple component behavior
# pragmas found") and, because a failed load is all-or-nothing, the ENTIRE
# configuration goes down with it. On 2026-08-13 that happened while the shell
# was holding the session lock: the lock client died, Hyprland was left locked
# with no client, and the session needed
#   hyprctl --instance 0 eval 'hl.clear_crashed_lockscreen()'
# from another tty to recover. A whole class of errors — duplicate pragmas,
# "Type X unavailable" cascades, unresolvable imports — is invisible to the
# linter and fatal at load.
#
# This script builds each component with Qt.createComponent and reports the ones
# that fail. It creates NO objects and NO surfaces, so it is safe to run against
# a live session: no panels, no windows, no session lock.
#
# The tree is copied to a temp dir first and `shell.qml` is removed from the
# copy, so the running shell is never touched and nothing spawns.
#
# Usage:  tools/compile-check.sh          # human output
#         tools/compile-check.sh --count  # just the failure count (for check.sh)
set -u

root="$(cd "$(dirname "$0")/.." && pwd)"
count_only=0
[ "${1:-}" = "--count" ] && count_only=1

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

say() { [ "$count_only" -eq 1 ] || printf '%s\n' "$@"; }

copy_tree() { # copy_tree <src> <dst>
    mkdir -p "$2"
    if command -v rsync >/dev/null 2>&1; then
        rsync -a --exclude '.git' --exclude 'build' "$1"/ "$2"/
    else
        cp -r "$1"/. "$2"/
    fi
    rm -f "$2/shell.qml"   # never spawn the real panels
}

# probe <tree-dir> <find-args...> -> prints failures, sets FAILED
FAILED=0
probe() {
    local tree="$1"; shift
    python3 - "$tree" "$@" <<'PY'
import json, os, sys
tree = sys.argv[1]
excludes = sys.argv[2:]
files = []
for cur, dirs, names in os.walk(os.path.join(tree, 'src') if os.path.isdir(os.path.join(tree, 'src')) else tree):
    dirs[:] = [d for d in dirs if d not in ('build', 'plugins', '.git')]
    rel_dir = os.path.relpath(cur, tree)
    if any(rel_dir == e or rel_dir.startswith(e + os.sep) for e in excludes):
        dirs[:] = []
        continue
    for n in sorted(names):
        if n.endswith('.qml'):
            files.append(os.path.relpath(os.path.join(cur, n), tree))
files.sort()
probe = '''import QtQuick
import Quickshell

QtObject {
    property var targets: %s
    Component.onCompleted: {
        const base = "file://%s/"
        let bad = 0
        for (const t of targets) {
            const c = Qt.createComponent(base + t, Component.PreferSynchronous)
            if (c.status === Component.Error) {
                bad++
                console.warn("FAIL " + t)
                console.warn("     " + c.errorString().trim().split("\\n")[0])
            }
            c.destroy()
        }
        console.warn("COMPILED " + (targets.length - bad) + "/" + targets.length)
        Qt.exit(bad === 0 ? 0 : 1)
    }
}
''' % (json.dumps(files), tree)
open(os.path.join(tree, '_compile_probe.qml'), 'w').write(probe)
PY

    local out
    out="$(cd "$tree" && QT_ASSUME_STDERR_HAS_CONSOLE=1 timeout 180 qs -p "$tree/_compile_probe.qml" 2>&1 \
        | sed 's/\x1b\[[0-9;]*m//g' \
        | grep -E '^\s*WARN qml: (FAIL|     |COMPILED)|FAIL |COMPILED ' \
        | sed -E 's/^\s*WARN qml: //')"

    local n
    n="$(printf '%s\n' "$out" | grep -c '^FAIL ')"
    FAILED=$((FAILED + n))
    say "$out"
}

# 1. Main shell. The greeter is a SEPARATE config with its own module roots
#    (qs / qs.ui / qs.config anchored at greeter/), so it cannot resolve here.
copy_tree "$root" "$tmp/main"
say "== main shell =="
probe "$tmp/main" "src/features/greeter"

# 2. Greeter, rooted at its own directory.
copy_tree "$root/src/features/greeter" "$tmp/greeter"
say "== greeter =="
probe "$tmp/greeter"

if [ "$count_only" -eq 1 ]; then
    echo "$FAILED"
else
    say ""
    if [ "$FAILED" -eq 0 ]; then
        say "OK — every component compiles."
    else
        say "FAILED — $FAILED component(s) do not compile."
    fi
fi

[ "$FAILED" -eq 0 ]
