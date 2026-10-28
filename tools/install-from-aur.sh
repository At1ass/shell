#!/usr/bin/env bash
# Build the published AUR recipe first, then safely migrate the running shell.
set -euo pipefail
root="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
build_cache="${XDG_CACHE_HOME:-$HOME/.cache}/at1ass-shell/aur-builds"
mkdir -p "$build_cache"
build_dir="$(mktemp -d "$build_cache/build.XXXXXXXX")"
printf 'Fetching the public AUR recipe into %s\n' "$build_dir"
git clone -- https://aur.archlinux.org/at1ass-shell-git.git "$build_dir"
git -C "$build_dir" log -1 --oneline
(
    cd "$build_dir"
    export CMAKE_BUILD_PARALLEL_LEVEL="${CMAKE_BUILD_PARALLEL_LEVEL:-2}"
    # No -i/-s: the running shell's plugins must not be replaced during building.
    makepkg --cleanbuild --force --noconfirm
)
printf 'AUR build complete; checking the migration plan.\n'
python3 "$root/tools/check-package.py" "$build_dir"/at1ass-shell-git-*.pkg.tar.zst \
    "$build_dir"/at1ass-shell-plugins-git-r*.pkg.tar.zst \
    "$build_dir"/at1ass-shell-greeter-git-r*.pkg.tar.zst
python3 "$root/tools/migrate-installed.py" --packages "$build_dir"
python3 "$root/tools/migrate-installed.py" --packages "$build_dir" --apply
