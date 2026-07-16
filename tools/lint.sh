#!/usr/bin/env bash
# qmllint wrapper. Resolves QML module namespaces that Quickshell provides at
# runtime but qmllint cannot discover on its own:
#   .qmllint-imports/qs            -> repo root      (main shell, `qs.src.*`)
#   .qmllint-imports/greeter/qs    -> greeter root   (greeter shell, `qs.ui` etc.)
# Relative AdditionalQmlImportPaths in .qmllint.ini is not resolved reliably by
# qmllint, hence the explicit -I here. Disabled categories (see .qmllint.ini):
#   BadSignalHandlerParameters — Quickshell qmltypes lack QProcess::ExitStatus,
#     so every Process.onExited would warn regardless of handler correctness.
#   UncreatableType — Quickshell qmltypes mark PanelWindow uncreatable although
#     the runtime creates it fine.
# Usage: tools/lint.sh [files...]   (no args = lint every QML file)
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"

main=()
greeter=()
collect() {
    case "$(realpath -m "$1")" in
        "$root"/src/features/greeter/*) greeter+=("$1") ;;
        *) main+=("$1") ;;
    esac
}

if [ "$#" -eq 0 ]; then
    while IFS= read -r f; do collect "$f"; done < <(
        find "$root/src" -name '*.qml' ! -path '*/plugins/*'
        echo "$root/shell.qml"
    )
else
    for f in "$@"; do collect "$f"; done
fi

status=0
if [ "${#main[@]}" -gt 0 ]; then
    /usr/lib/qt6/bin/qmllint -I "$root/.qmllint-imports" "${main[@]}" || status=$?
fi
if [ "${#greeter[@]}" -gt 0 ]; then
    /usr/lib/qt6/bin/qmllint -I "$root/.qmllint-imports/greeter" "${greeter[@]}" || status=$?
fi
exit "$status"
