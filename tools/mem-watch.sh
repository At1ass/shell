#!/usr/bin/env bash
# Log the running shell's RSS over time, so a long session can be inspected
# after the fact. Startup composition is measurable in minutes (see
# ROADMAP "memory profile"); growth over days is not, so this leaves an
# instrument running instead of guessing.
#
#   tools/mem-watch.sh [interval_seconds] [logfile]
#
# Columns: unix_ts rss_kb hwm_kb threads fds anon_kb gpu_kb file_kb \
#          anon_vmas anon_virt_kb jsheap_kb jit_kb
#
# The segment columns exist because a bare RSS number only says a spike
# happened, not where. anon = heap and stacks, gpu = the driver's mappings
# (textures), file = everything file-backed (libraries, fonts).
#
# The last four separate the three ways anon can grow, which need different
# fixes: anon_virt >> anon_rss means allocator fragmentation; jsheap/jit
# growing means QML holds objects; neither moving while anon climbs means a
# C++ allocation (image, texture, service buffer) is never freed.
#
# Aggregates alone still cannot name a culprit, so every SNAP_EVERY samples
# the full mapping table is dumped next to the log. A week-long session that
# ends at 3 GB can then be diffed against its own first hour.
set -u
interval="${1:-60}"
log="${2:-$HOME/.cache/quickshell/mem-watch.log}"
snapdir="$(dirname "$log")/mem-snaps"
SNAP_EVERY="${SNAP_EVERY:-30}"     # samples between full mapping dumps
SNAP_KEEP="${SNAP_KEEP:-96}"       # dumps retained (96 x 30min = 48h)
mkdir -p "$(dirname "$log")" "$snapdir"

pid="$(pgrep -x qs | head -1)"
[ -n "$pid" ] || { echo "no running qs" >&2; exit 1; }
echo "watching pid $pid every ${interval}s -> $log (snapshots -> $snapdir)" >&2
printf '# ts rss_kb hwm_kb threads fds anon_kb gpu_kb file_kb anon_vmas anon_virt_kb jsheap_kb jit_kb (pid %s started %s)\n' \
    "$pid" "$(date -d "@$(stat -c %Y /proc/$pid)" '+%F %T' 2>/dev/null)" >> "$log"

# One pass over smaps yields every segment figure; smaps is expensive enough
# on a 1800-mapping process that a second pass per sample is worth avoiding.
scan() {
    awk '
        /^[0-9a-f]+-[0-9a-f]+ / {
            split($1, a, "-")
            vsz = (strtonum("0x" a[2]) - strtonum("0x" a[1])) / 1024
            path = ""; for (i = 6; i <= NF; i++) path = path $i
            kind = (path == "")                            ? "anon" :
                   (path ~ /nvidia|libGL|\/dri\//)         ? "gpu"  : "file"
            if (kind == "anon") { vmas++; virt += vsz }
            js  = (path ~ /JSGCHeap|JSVMStack/)
            jit = (path ~ /JITCode/)
        }
        /^Rss:/ { s[kind] += $2; if (js) jsk += $2; if (jit) jitk += $2 }
        END { printf "%d %d %d %d %d %d %d",
              s["anon"], s["gpu"], s["file"], vmas, virt, jsk, jitk }
    ' "/proc/$pid/smaps" 2>/dev/null
}

# A dump is only useful against a reference, so keep the first one forever and
# let the rotation reclaim the rest.
snapshot() {
    local f="$snapdir/$(date +%Y%m%d-%H%M%S).txt"
    {
        printf '# pid %s  ts %s  rss %s kB\n' "$pid" "$(date +%s)" \
            "$(awk '/^VmRSS/{print $2}' "/proc/$pid/status")"
        awk '
            /^[0-9a-f]+-[0-9a-f]+ / {
                split($1, a, "-")
                sz = (strtonum("0x" a[2]) - strtonum("0x" a[1])) / 1024
                path = ""; for (i = 6; i <= NF; i++) path = path " " $i
                key = (path == "") ? sprintf("[anon %d KB]", sz) : path
            }
            /^Rss:/ { r[key] += $2; n[key]++ }
            END { for (k in r) if (r[k] > 256) printf "%9d %5d %s\n", r[k], n[k], k }
        ' "/proc/$pid/smaps" 2>/dev/null | sort -rn
    } > "$f" 2>/dev/null
    ls -1t "$snapdir"/*.txt 2>/dev/null | tail -n +$((SNAP_KEEP + 1)) | xargs -r rm -f
}

i=0
while [ -d "/proc/$pid" ]; do
    rss=$(awk '/^VmRSS/{print $2}' "/proc/$pid/status" 2>/dev/null)
    hwm=$(awk '/^VmHWM/{print $2}' "/proc/$pid/status" 2>/dev/null)
    thr=$(awk '/^Threads/{print $2}' "/proc/$pid/status" 2>/dev/null)
    fds=$(ls "/proc/$pid/fd" 2>/dev/null | wc -l)
    printf '%s %s %s %s %s %s\n' "$(date +%s)" "${rss:-0}" "${hwm:-0}" "${thr:-0}" \
        "${fds:-0}" "$(scan)" >> "$log"
    [ $((i % SNAP_EVERY)) -eq 0 ] && snapshot
    i=$((i + 1))
    sleep "$interval"
done
echo "pid $pid gone" >&2
