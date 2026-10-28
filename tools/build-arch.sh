#!/usr/bin/env bash
# Build the committed local revision without changing the public AUR recipe.
set -euo pipefail
root="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
out="${1:-$(mktemp -d -t at1ass-shell-build-XXXXXXXX)}"
mkdir -p "$out"
out="$(realpath "$out")"
case "$out/" in "$root/"*) echo 'Use a build directory outside the checkout.' >&2; exit 1;; esac
python3 - "$root" "$out" <<'PYBUILD'
from pathlib import Path
import subprocess, sys
root, output = map(Path, sys.argv[1:])
revision = subprocess.check_output(['git','-C',str(root),'rev-parse','HEAD'],text=True).strip()
recipe = subprocess.check_output(['git','-C',str(root),'show','HEAD:packaging/arch/PKGBUILD'],text=True)
recipe = recipe.replace('git+https://github.com/At1ass/shell.git', 'git+'+root.as_uri()+'#commit='+revision)
(output/'PKGBUILD').write_text(recipe)
PYBUILD
cd "$out"
export CMAKE_BUILD_PARALLEL_LEVEL="${CMAKE_BUILD_PARALLEL_LEVEL:-2}"
makepkg --cleanbuild --force --noconfirm
makepkg --printsrcinfo > .SRCINFO
printf '\nPackages built in %s\n' "$out"
