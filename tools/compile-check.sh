#!/usr/bin/env bash
# Compile components without creating objects or mapping surfaces. Always use
# an isolated tree; a failed probe or missing completion marker is a failure.
set -uo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
count_only=0
[ "${1:-}" = "--count" ] && count_only=1
tmp="$(mktemp -d)" || exit 1
trap 'rm -rf "$tmp"' EXIT
say() { [ "$count_only" -eq 1 ] || printf '%s\n' "$@"; }
FAILED=0
copy_tree() {
    mkdir -p "$2" || return 1
    if command -v rsync >/dev/null 2>&1; then
        rsync -a --exclude '.git' --exclude 'build' --exclude 'build-test' --exclude '.qmllint-imports' --exclude '/packaging/' "$1"/ "$2"/
    else
        python3 - "$1" "$2" <<'PY'
import pathlib, shutil, sys
source = pathlib.Path(sys.argv[1]).resolve()
def ignored(directory, names):
    excluded = {'.git', 'build', 'build-test', '.qmllint-imports'}
    if pathlib.Path(directory).resolve() == source:
        excluded.add('packaging')
    return excluded.intersection(names)
shutil.copytree(source, sys.argv[2], symlinks=True, dirs_exist_ok=True, ignore=ignored)
PY
    fi
}
probe() {
    local tree="$1"; shift
    if ! python3 - "$tree" "$@" <<'PY'
import json, pathlib, sys
root = pathlib.Path(sys.argv[1])
files = sorted(str(p.relative_to(root)) for p in root.rglob('*.qml')
               if not any(x in p.relative_to(root).parts for x in ('plugins', '.git', 'build', 'build-test', '.qmllint-imports'))
               and not any(str(p.relative_to(root)).startswith(x + '/') for x in sys.argv[2:]))
if not files:
    raise SystemExit('No QML targets found')
probe = '''import QtQuick
import Quickshell
QtObject {
    property var targets: %s
    Component.onCompleted: Qt.callLater(() => {
        let bad = 0
        for (const t of targets) {
            const c = Qt.createComponent(%s + t, Component.PreferSynchronous)
            if (c.status !== Component.Ready) {
                bad++
                console.warn("FAIL " + t + " " + c.errorString().trim())
            }
            c.destroy()
        }
        console.warn("COMPILED " + (targets.length - bad) + "/" + targets.length)
        Qt.exit(bad === 0 ? 0 : 1)
    })
}
''' % (json.dumps(files), json.dumps(root.as_uri() + '/'))
(root / '_compile_probe.qml').write_text(probe)
(root / '_compile_expected').write_text(str(len(files)))
PY
    then
        FAILED=$((FAILED + 1)); say 'FAIL: could not prepare compilation probe'; return
    fi
    local status=0 out expected marker
    (cd "$tree" && QT_ASSUME_STDERR_HAS_CONSOLE=1 timeout 45 qs -p "$tree/_compile_probe.qml") > "$tree/probe.log" 2>&1 || status=$?
    out="$(sed 's/\x1b\[[0-9;]*m//g' "$tree/probe.log")"
    expected="$(cat "$tree/_compile_expected")"
    marker="$(printf '%s\n' "$out" | sed -nE 's/^.*qml: COMPILED ([0-9]+)\/([0-9]+).*$/\1 \2/p')"
    if [ "$status" -ne 0 ] || [ "$marker" != "$expected $expected" ]; then
        local n
        n="$(printf '%s\n' "$out" | grep -c 'qml: FAIL ' || true)"
        [ "$n" -gt 0 ] || n=1
        FAILED=$((FAILED + n))
        say "$out"
        say "FAIL: probe exit=$status; expected COMPILED $expected/$expected"
    else
        say "COMPILED $expected/$expected"
    fi
}
if copy_tree "$root" "$tmp/main"; then
    say '== main shell =='; probe "$tmp/main" 'src/features/greeter'
else FAILED=$((FAILED + 1)); fi
if copy_tree "$root/src/features/greeter" "$tmp/greeter"; then
    say '== greeter =='; probe "$tmp/greeter"
else FAILED=$((FAILED + 1)); fi
if [ "$count_only" -eq 1 ]; then echo "$FAILED"
elif [ "$FAILED" -eq 0 ]; then say 'OK — every component compiles.'
else say "FAILED — $FAILED compilation/probe failure(s)."; fi
[ "$FAILED" -eq 0 ]
