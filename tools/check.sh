#!/usr/bin/env bash
# Repo invariants from AGENTS.md §10, checked mechanically.
#
# Each check counts occurrences of a banned pattern. A check FAILS when its
# count exceeds the committed baseline (tools/check-baseline.txt) — the
# baseline is a ratchet holding known debt while refactor phases burn it down.
# When a phase eliminates a pattern, run `tools/check.sh --update-baseline`
# and commit the lowered numbers so they can never grow back.
#
# Exit code: 0 = no regressions, 1 = at least one check above baseline.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
baseline_file="$root/tools/check-baseline.txt"
update=0
[ "${1:-}" = "--update-baseline" ] && update=1

declare -A results
declare -A baseline

if [ -f "$baseline_file" ]; then
    while read -r key val; do
        [ -n "$key" ] && baseline["$key"]="$val"
    done < "$baseline_file"
fi

qml() { find "$root/src" -name '*.qml' ! -path '*/plugins/*'; echo "$root/shell.qml"; }

count() { # count <check-id> <count-value>
    results["$1"]="$2"
}

# --- Layer graph (AGENTS §3, §10.8) ------------------------------------------
count layer-ui-imports-services \
    "$(grep -rE 'import qs\.src\.core\.services' "$root/src/ui" --include='*.qml' | wc -l)"
count layer-config-imports-services \
    "$(grep -rE 'import qs\.src\.core\.services' "$root/src/core/config" --include='*.qml' | wc -l)"
count layer-services-imports-features \
    "$(grep -rE 'import qs\.src\.features' "$root/src/core/services" --include='*.qml' | wc -l)"
count layer-services-imports-ui \
    "$(grep -rE 'import qs\.src\.ui' "$root/src/core/services" --include='*.qml' | wc -l)"

# --- Motion / MD3 (§10.2) -----------------------------------------------------
# Direct Easing.* enums in features bypass Tokens.motion (Phase 3 target).
count easing-literals-in-features \
    "$(grep -rE 'easing\.(type|bezierCurve):[^/]*Easing\.' "$root/src/features" --include='*.qml' | wc -l)"
count font-pointsize \
    "$(grep -rE 'font\.pointSize' "$root/src" --include='*.qml' | wc -l)"

# --- Performance (§10.14, §10.15) ----------------------------------------------
count stacklayout-in-features \
    "$(grep -rE '^\s*StackLayout\s*\{' "$root/src/features" --include='*.qml' | wc -l)"
count lazyloader-loading \
    "$(grep -rE '^\s*loading:\s*true' "$root/src" --include='*.qml' "$root/shell.qml" | wc -l)"

# --- Security (§10.25, §10.26) --------------------------------------------------
# sh/bash -c with string concatenation or template interpolation.
count sh-c-concatenation \
    "$(grep -rE '"(sh|bash)"\s*,\s*"-l?c"\s*,\s*[^]]*(\+|\$\{)' "$root/src" --include='*.qml' | wc -l)"
count hardcoded-home-paths \
    "$(grep -rE '(/home/[a-z0-9_]+|file:///home/)' "$root/src" --include='*.qml' | grep -v 'Quickshell.env' | wc -l)"

# --- Hygiene (§10.17) -----------------------------------------------------------
count console-log \
    "$(grep -rE 'console\.log\(' "$root/src" --include='*.qml' "$root/shell.qml" | wc -l)"

# --- qmllint (AGENTS §4: changed QML must lint clean) ---------------------------
lint_out="$("$root/tools/lint.sh" 2>&1)"
count qmllint-warnings "$(printf '%s\n' "$lint_out" | grep -cE '^Warning: ')"

# --- Report ----------------------------------------------------------------------
fail=0
printf '%-36s %8s %9s  %s\n' "check" "current" "baseline" "status"
for key in $(printf '%s\n' "${!results[@]}" | sort); do
    cur="${results[$key]}"
    base="${baseline[$key]:-0}"
    if [ "$cur" -gt "$base" ]; then
        status="FAIL (+$((cur - base)))"
        fail=1
    elif [ "$cur" -lt "$base" ]; then
        status="ok (can ratchet to $cur)"
    elif [ "$cur" -eq 0 ]; then
        status="clean"
    else
        status="ok (known debt)"
    fi
    printf '%-36s %8s %9s  %s\n' "$key" "$cur" "$base" "$status"
done

if [ "$update" -eq 1 ]; then
    : > "$baseline_file"
    for key in $(printf '%s\n' "${!results[@]}" | sort); do
        printf '%s %s\n' "$key" "${results[$key]}" >> "$baseline_file"
    done
    echo "baseline updated: $baseline_file"
fi

exit "$fail"
