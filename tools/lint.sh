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
main_metadata=()
greeter_metadata=()
declare -A main_seen=() greeter_seen=()
collect() {
    local path descriptor
    path="$(realpath -m "$1")"
    descriptor="$(dirname "$path")/qmldir"
    case "$path" in
        "$root"/src/features/greeter/*)
            greeter+=("$path")
            if [[ -f "$descriptor" && -z "${greeter_seen[$descriptor]+x}" ]]; then
                greeter_metadata+=("$descriptor")
                greeter_seen[$descriptor]=1
            fi ;;
        *)
            main+=("$path")
            if [[ -f "$descriptor" && -z "${main_seen[$descriptor]+x}" ]]; then
                main_metadata+=("$descriptor")
                main_seen[$descriptor]=1
            fi ;;
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

# Respect the same build-tree override as the engine. qmllint otherwise
# searches its default installed modules before -I and sees stale plugin types.
extra_imports=()
if [[ -n "${QML_IMPORT_PATH:-}" ]]; then
    extra_imports+=(--bare)
    IFS=: read -ra native_paths <<< "$QML_IMPORT_PATH"
    for native_path in "${native_paths[@]}"; do
        [[ -n "$native_path" ]] && extra_imports+=(-I "$native_path")
    done
    extra_imports+=(-I "$(/usr/lib/qt6/bin/qtpaths --query QT_INSTALL_QML)")
fi
status=0
lint_groups() {
    local imports="$1"; shift
    local count="$1"; shift
    local descriptors=("${@:1:count}")
    shift "$count"
    local files=("$@") group=() remaining=() descriptor file
    # qmllint's -i selects one module descriptor. Passing several -i options
    # silently uses only the last, misclassifying singleton exports in others.
    for descriptor in "${descriptors[@]}"; do
        group=()
        for file in "${files[@]}"; do
            [[ "${file%/*}/qmldir" == "$descriptor" ]] && group+=("$file")
        done
        /usr/lib/qt6/bin/qmllint "${extra_imports[@]}" -I "$imports" -i "$descriptor" "${group[@]}" || status=$?
    done
    for file in "${files[@]}"; do
        [[ ! -f "${file%/*}/qmldir" ]] && remaining+=("$file")
    done
    if [ "${#remaining[@]}" -gt 0 ]; then
        /usr/lib/qt6/bin/qmllint "${extra_imports[@]}" -I "$imports" "${remaining[@]}" || status=$?
    fi
}
if [ "${#main[@]}" -gt 0 ]; then
    lint_groups "$root/.qmllint-imports" "${#main_metadata[@]}" "${main_metadata[@]}" "${main[@]}"
fi
if [ "${#greeter[@]}" -gt 0 ]; then
    lint_groups "$root/.qmllint-imports/greeter" "${#greeter_metadata[@]}" "${greeter_metadata[@]}" "${greeter[@]}"
fi
exit "$status"
