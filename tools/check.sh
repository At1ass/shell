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
# Every `easing.type: Tokens.motion.easing.X` must be paired with the matching
# XPoints bezierCurve — every one of those tokens is Easing.BezierSpline, so a
# lone half leaves Qt with no control points and the animation runs linear.
#
# The pair may sit on the SAME line (`NumberAnimation { ...; easing.type: ... }`)
# or on the next one. The original check anchored the type match to end-of-line,
# so it only ever saw the two-line form and silently passed four single-line
# animations that were running linear — including one in the kit itself.
count easing-unpaired-tokens \
    "$(qml | grep -v '/greeter/ui/Tokens.qml' | xargs awk '
        function check(line, curve) {
            return (line ~ ("bezierCurve: *Tokens\\.motion\\.easing\\." curve "Points"))
        }
        pending != "" {
            if (!check($0, pending)) bad++
            pending = ""
        }
        match($0, /easing\.type: *Tokens\.motion\.easing\.(standard|emphasizedDecelerate|emphasizedAccelerate|emphasized)([^A-Za-z]|$)/, m) {
            if (!check($0, m[1])) pending = m[1]
        }
        END { if (pending != "") bad++; print bad + 0 }' 2>/dev/null | awk '{s+=$1} END {print s+0}')"
count font-pointsize \
    "$(grep -rE 'font\.pointSize' "$root/src" --include='*.qml' | wc -l)"
# Hand-written easing pairs. MotionAnimation / MotionColorAnimation fuse the two
# halves into one `curve:`, which is the only way they cannot diverge — and the
# reason the 4-value-bezier bug reached 100+ sites at once was that the fused
# component existed and nobody used it. Tokens.qml defines the curves and the
# two Motion* components consume them; everyone else goes through those.
count easing-pairs-by-hand \
    "$(qml | grep -vE '/(Tokens|Motion(Color)?Animation)\.qml$' \
        | xargs grep -l 'easing\.bezierCurve' 2>/dev/null | wc -l)"
# Qt's easing.bezierCurve takes GROUPS OF THREE points (6 reals per segment)
# and the last point must be (1,1). A CSS-style 4-value cubic-bezier is
# rejected WITHOUT a warning and the animation silently runs linear — which is
# exactly how every MD3 curve in this repo was dead for months. Count any
# *Points token array whose element count is not a positive multiple of 6.
count easing-points-arity \
    "$(qml | xargs grep -hoE '^\s*readonly property var [A-Za-z]+Points: \[[^]]*\]' 2>/dev/null \
        | awk -F'[][]' '{n=split($2, a, ","); if (n == 0 || n % 6 != 0) bad++} END {print bad + 0}')"

# --- Performance (§10.14, §10.15) ----------------------------------------------
count stacklayout-in-features \
    "$(grep -rE '^\s*StackLayout\s*\{' "$root/src/features" --include='*.qml' | wc -l)"
count lazyloader-loading \
    "$(grep -rE '^\s*loading:\s*true' "$root/src" --include='*.qml' "$root/shell.qml" | wc -l)"

# --- Security (§10.25, §10.26) --------------------------------------------------
# sh/bash -c with string concatenation or template interpolation.
#
# Scanned across LINE BREAKS on purpose. The original single-line grep could only
# see 3 of the 8 `sh -c` sites in the tree — the rest wrap the script onto the
# next line — so it reported "clean" while observing well under half the actual
# call sites. Joins each file into one record, then inspects the argv list from
# `"sh", "-c"` up to the closing bracket.
count sh-c-concatenation \
    "$(qml | xargs awk 'BEGIN { RS = "\0" }
        {
            s = $0
            while (match(s, /"(sh|bash)"[[:space:]]*,[[:space:]]*"-l?c"[[:space:]]*,/)) {
                s = substr(s, RSTART + RLENGTH)
                end = index(s, "]")
                argv = (end > 0) ? substr(s, 1, end - 1) : s
                if (argv ~ /\+/ || argv ~ /\$\{/) bad++
            }
        }
        END { print bad + 0 }' 2>/dev/null | awk '{s+=$1} END {print s+0}')"
count hardcoded-home-paths \
    "$(grep -rE '(/home/[a-z0-9_]+|file:///home/)' "$root/src" --include='*.qml' | grep -v 'Quickshell.env' | wc -l)"

# --- Kit adoption (§10.4) --------------------------------------------------------
# Raw Rectangle in features. A RATCHET, not a ban: some are legitimate (an image
# backing that needs `clip`, a 1px rule, a scrim behind a grab). The number must
# not grow — every new one should be a kit component instead.
count raw-rectangle-in-features \
    "$(grep -rcE '^\s*Rectangle\s*\{' "$root/src/features" --include='*.qml' \
        | awk -F: '{s+=$2} END {print s+0}')"
# String enums that silently fall back on a typo. Validates the literals passed
# to the kit's enum-shaped properties against the values each one accepts.
count unknown-enum-literals \
    "$(qml | xargs grep -hoE '(textStyle|colorRole|variant|curve|shape):[ ]*"[a-zA-Z]+"' 2>/dev/null \
        | sed -E 's/.*"(.*)"/\1/' \
        | grep -vxE 'displayLarge|displayMedium|displaySmall|headlineLarge|headlineMedium|headlineSmall|titleLarge|titleMedium|titleSmall|labelLarge|labelMedium|labelSmall|bodyLarge|bodyMedium|bodySmall|primary|onPrimary|primaryContainer|onPrimaryContainer|secondary|onSecondary|secondaryContainer|onSecondaryContainer|tertiary|onTertiary|tertiaryContainer|onTertiaryContainer|error|onError|errorContainer|onErrorContainer|surface|onSurface|surfaceVariant|onSurfaceVariant|outline|outlineVariant|background|onBackground|inverseSurface|inverseOnSurface|inversePrimary|surfaceDim|surfaceBright|surfaceContainerLowest|surfaceContainerLow|surfaceContainer|surfaceContainerHigh|surfaceContainerHighest|shadow|scrim|scrimForeground|surfaceTint|standard|filled|tonal|elevated|outlined|text|small|medium|large|extraSmall|extraLarge|regular|circle|rounded|square|linear|circular|emphasized|emphasizedDecelerate|emphasizedAccelerate' \
        | wc -l)"

# Material Symbols is a VARIABLE font (driven via font.variableAxes) and Qt's
# distance-field renderer corrupts its glyphs — icons came out as two
# superimposed outlines. MaterialText uses QtRendering for subpixel positioning
# under animated scale; MaterialIcon must override back to NativeRendering.
# Counts MaterialIcon files MISSING the override, so dropping it fails here.
count icon-renderer-override \
    "$(find "$root/src" -name 'MaterialIcon.qml' \
        -exec grep -L 'renderType: *Text\.NativeRendering' {} + 2>/dev/null | wc -l)"

# A repeated pragma is a FATAL load error ("Multiple component behavior pragmas
# found") that kills the WHOLE configuration, not just the offending file — and
# qmllint does not report it at all (exit 0, no diagnostic). That combination
# once took the shell down while it was holding the session lock, which left no
# way back into the session. Cheap to check, so it is checked here.
count duplicate-pragmas \
    "$(qml | xargs awk '
        FNR == 1 { delete seen }
        /^pragma / { if (seen[$0]++) { bad[FILENAME] = 1 } }
        END { n = 0; for (f in bad) n++; print n }' 2>/dev/null | awk '{s+=$1} END {print s+0}')"

# Layout-dependent key matching. `event.key` and `event.text` carry the SYMBOL
# the active layout produces, so `event.key === Qt.Key_J` is dead the moment the
# user switches to a non-Latin layout — the physical J key arrives as Qt.Key_O
# on a Cyrillic one. Every vi binding in the shell was broken this way. Match on
# the physical key via Keycodes.key()/letter() instead (src/core/config).
#
# Only SINGLE-character keys are flagged: Qt.Key_Escape, Qt.Key_Down, Qt.Key_Home
# and friends are layout-independent and pass through `event.key` untouched. The
# \b after the character class is what separates Qt.Key_H from Qt.Key_Home.
# Comment-only lines are dropped: the fix itself has to NAME the bad pattern in
# the comment explaining why it is gone, and a check that trips over its own
# documentation just teaches people to word around it.
count layout-dependent-keys \
    "$(qml | grep -v '/core/config/Keycodes.qml' \
        | xargs grep -HnE 'event\.text|(event\.key.*Qt\.Key_[A-Z0-9]\b)|(Qt\.Key_[A-Z0-9]\b.*event\.key)' 2>/dev/null \
        | grep -vE ':[0-9]+:[[:space:]]*(//|\*)' \
        | wc -l)"

# --- Hygiene (§10.17) -----------------------------------------------------------
count console-log \
    "$(grep -rE 'console\.log\(' "$root/src" --include='*.qml' "$root/shell.qml" | wc -l)"
# The greeter's UI kit is GENERATED from src/ui by sync-ui.sh. Nothing stopped it
# from silently drifting once someone edited src/ui without re-running the script
# (or hand-edited greeter/ui). --check regenerates into a temp dir and diffs, so
# the generator itself stays the single source of truth for this invariant.
count greeter-ui-drift \
    "$("$root/src/features/greeter/sync-ui.sh" --check 2>/dev/null | tail -1)"

# --- Load safety ------------------------------------------------------------------
# Builds every component with the real Quickshell engine. qmllint cannot see the
# errors that matter most here (a duplicate pragma lints clean and then kills the
# whole configuration at load), and a dead configuration means a dead session
# lock. See tools/compile-check.sh for the incident this came from.
count qml-compile-failures "$("$root/tools/compile-check.sh" --count 2>/dev/null | tail -1)"

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
