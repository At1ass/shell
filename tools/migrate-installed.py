#!/usr/bin/env python3
"""Preview or migrate the current development session to installed Arch packages."""
import argparse
import datetime
import hashlib
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--packages', type=Path, required=True)
parser.add_argument('--bin-dir', type=Path, default=Path.home()/'.local/bin', help='user script directory to scan for legacy IPC calls')
parser.add_argument('--apply', action='store_true', help='authenticate, install and switch services')
args = parser.parse_args()
source = Path(__file__).resolve().parents[1]
config = Path(os.environ.get('XDG_CONFIG_HOME', str(Path.home()/'.config')))
pattern = re.compile(r'\b(?:qs|quickshell)\s+(?:-c|--config)\s+shell\b')
changes = {}
bin_dir = args.bin_dir.resolve()
candidates = [path for path in (config/'hypr').rglob('*') if path.suffix in {'.conf','.lua'}]
if bin_dir.is_dir():
    for path in bin_dir.iterdir():
        if not path.is_file() or path.stat().st_size > 1024*1024:
            continue
        with path.open('rb') as stream:
            scripted = stream.read(2) == b'#!'
        if scripted or path.suffix in {'.sh','.bash','.zsh'}:
            candidates.append(path)
for path in candidates:
    if not path.is_file():
        continue
    try:
        before = path.read_text()
    except UnicodeDecodeError:
        continue
    after = pattern.sub('/usr/bin/at1ass-shell', before)
    if after != before:
        if path.is_symlink():
            raise SystemExit(f'Review symlinked integration file manually: {path}')
        changes[path] = (before, after)
names = {'at1ass-shell-git', 'at1ass-shell-plugins-git', 'at1ass-shell-greeter-git'}
packages = {}
for path in sorted(args.packages.resolve().glob('*.pkg.tar.zst')):
    info = subprocess.check_output(['pacman','-Qp',str(path)], text=True).split()
    if info[0] in names:
        if info[0] in packages:
            raise SystemExit(f'Multiple builds of {info[0]}: use a directory containing one build')
        packages[info[0]] = path
if set(packages) != names:
    raise SystemExit('Expected all three shell, plugins and greeter packages')
print('Packages:')
for name, path in packages.items():
    print(f'  {name}: {path}')
print('Integration files to update:')
for path in changes:
    print(f'  {path}')
print('Service: quickshell.service -> at1ass-shell.service')
greeter_conf = Path('/etc/greetd')/'hyprland-greeter.conf'
greeter_update = None
if greeter_conf.is_file():
    current = greeter_conf.read_text()
    updated = re.sub(r"\bhyprctl\s+dispatch\s+exit\b", "hyprctl dispatch 'hl.dsp.exit()'", current)
    if updated != current:
        greeter_update = updated
        print(f'Greeter compatibility command: {greeter_conf}: dispatch exit -> hl.dsp.exit()')
print('User config, state, launcher database, repository and greeter display/session settings are preserved.')
if not args.apply:
    print('Preview only. Add --apply to authenticate and migrate.')
    raise SystemExit(0)
if os.geteuid() == 0:
    raise SystemExit('Run as the desktop user; only pacman/file ownership use sudo')

def run(argv, **kwargs):
    return subprocess.run(argv, check=True, **kwargs)

def active(name):
    return subprocess.run(['systemctl','--user','is-active','--quiet',name]).returncode == 0

def unlocked(command):
    result = subprocess.run(command+['ipc','call','globalstates','locked'], capture_output=True, text=True, timeout=5)
    if result.returncode or result.stdout.strip() != 'false':
        raise SystemExit('Unlock the session before migration; shell files/services were not changed')

old = 'quickshell.service'
new = 'at1ass-shell.service'
if not active(old) or active(new):
    raise SystemExit('Expected the development quickshell.service active and packaged service stopped')
unlocked(['qs','-p',str(source)])
# Authenticate before stopping the running shell. No password is stored by this script.
run(['sudo','-v'])
unlocked(['qs','-p',str(source)])
for path, (before, _) in changes.items():
    if path.read_text() != before:
        raise SystemExit(f'Integration changed during preview: {path}; retry')
stamp = datetime.datetime.now().strftime('%Y%m%d-%H%M%S')
backup = Path(os.environ.get('XDG_STATE_HOME',str(Path.home()/'.local/state')))/'at1ass-shell/migrations'/stamp
backup.mkdir(parents=True, mode=0o700)
for path in changes:
    relative = Path('config')/path.relative_to(config) if path.is_relative_to(config) else Path('bin')/path.relative_to(bin_dir)
    target = backup/'integration'/relative
    target.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(path,target)
for path in [config/'quickshell/config.json',config/'quickshell/state.json',config/'systemd/user/quickshell.service']:
    if path.is_file():
        target = backup/'original'/path.relative_to(config)
        target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(path,target)
config_file = config/'quickshell/config.json'
config_digest = hashlib.sha256(config_file.read_bytes()).digest() if config_file.exists() else None
greetd = {}
for name in ['greeter.json','hyprland-greeter.conf']:
    path = Path('/etc/greetd')/name
    if path.is_file():
        target = backup/'greetd'/name
        target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(path,target)
        greetd[path] = (target, path.stat())
old_enabled = subprocess.run(['systemctl','--user','is-enabled','--quiet',old]).returncode == 0
idle_active = active('hypridle.service')
written_paths = set()
try:
    if idle_active:
        run(['systemctl','--user','stop','hypridle.service'])
    # Recheck after backups/idle shutdown, immediately before stopping the lock owner.
    unlocked(['qs','-p',str(source)])
    # Replacing loaded .so files is unsafe: stop before the pacman transaction.
    run(['systemctl','--user','stop',old])
    run(['sudo','pacman','-U',*[str(packages[name]) for name in sorted(packages)]])
    for path, (saved, original_stat) in greetd.items():
        install_source = saved
        if path == greeter_conf and greeter_update is not None:
            install_source = backup/'greetd-compat.conf'
            install_source.write_text(greeter_update)
        if not path.exists() or path.read_bytes() != install_source.read_bytes():
            run(['sudo','install','-o',str(original_stat.st_uid),'-g',str(original_stat.st_gid),'-m',format(stat.S_IMODE(original_stat.st_mode),'o'),str(install_source),str(path)])
    for path, (before, after) in changes.items():
        if path.read_text() != before:
            raise RuntimeError(f'Integration changed during installation: {path}; preserving the external edit')
        path.write_text(after)
        written_paths.add(path)
    run(['systemctl','--user','daemon-reload'])
    run(['systemctl','--user','disable',old])
    run(['systemctl','--user','enable',new])
    run(['systemctl','--user','start',new])
    for attempt in range(30):
        probe = subprocess.run(['/usr/bin/at1ass-shell','ipc','call','config','validate'],capture_output=True,text=True)
        if probe.returncode == 0 and probe.stdout.startswith('OK:'):
            break
        time.sleep(0.2)
    else:
        raise RuntimeError('Installed configuration did not validate; restoring development startup')
    if config_digest is not None and hashlib.sha256(config_file.read_bytes()).digest() != config_digest:
        raise RuntimeError('User config changed unexpectedly during migration')
    run(['hyprctl','reload'])
except BaseException:
    subprocess.run(['systemctl','--user','stop',new])
    subprocess.run(['systemctl','--user','disable',new])
    for path in written_paths:
        before, after = changes[path]
        if path.read_text() == after:
            path.write_text(before)
    for path, (saved, original_stat) in greetd.items():
        if not path.exists() or path.read_bytes() != saved.read_bytes():
            subprocess.run(['sudo','install','-o',str(original_stat.st_uid),'-g',str(original_stat.st_gid),'-m',format(stat.S_IMODE(original_stat.st_mode),'o'),str(saved),str(path)])
    subprocess.run(['hyprctl','reload'])
    if old_enabled:
        subprocess.run(['systemctl','--user','enable',old])
    subprocess.run(['systemctl','--user','start',old])
    raise
finally:
    if idle_active:
        subprocess.run(['systemctl','--user','start','hypridle.service'])
print(f'Migration complete. Backups: {backup}')
print('Rollback integration with the backed-up files and quickshell.service; packages remain installed.')
