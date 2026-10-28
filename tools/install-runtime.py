#!/usr/bin/env python3
"""Install runtime files into a package root; never copy user state or build trees."""
import argparse
from pathlib import Path
import shutil

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--source', type=Path, required=True)
parser.add_argument('--destdir', type=Path, required=True)
args = parser.parse_args()
source = args.source.resolve()
dest = args.destdir.resolve() / 'usr/share/at1ass-shell'
allowed = {'.qml', '.js', '.json', '.svg', '.png', '.jpg', '.jpeg', '.webp', '.frag', '.vert'}
files = [source / 'shell.qml']
for section in ['src/core', 'src/ui', 'src/features', 'config']:
    for path in (source / section).rglob('*'):
        relative = path.relative_to(source)
        if relative.parts[:3] == ('src', 'features', 'greeter'):
            continue
        if path.is_file() and (path.suffix in allowed or path.name == 'qmldir'):
            files.append(path)
files.append(source / 'tools/shell-ctl')
for path in files:
    target = dest / path.relative_to(source)
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(path, target)
    target.chmod(0o755 if path.name == 'shell-ctl' else 0o644)
