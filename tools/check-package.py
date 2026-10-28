#!/usr/bin/env python3
"""Check Arch package payloads and compile installed QML without creating windows."""
import argparse
import json
import os
from pathlib import Path, PurePosixPath
import subprocess
import tempfile

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('packages', nargs='+', type=Path)
args=parser.parse_args()
with tempfile.TemporaryDirectory(prefix='shell-payload-check-') as directory:
    root=Path(directory)
    for package in args.packages:
        entries=subprocess.check_output(['bsdtar','-tf',str(package.resolve())],text=True).splitlines()
        for entry in entries:
            p=PurePosixPath(entry)
            if p.is_absolute() or '..' in p.parts or (p.parts and p.parts[0] not in {'.PKGINFO','.BUILDINFO','.MTREE','usr','etc'}):
                raise SystemExit(f'Unexpected package path: {entry}')
            if entry.endswith(('.cpp','.h','.hpp','.pyc')) or '/build/' in entry or '/.git/' in entry:
                raise SystemExit(f'Development artifact: {entry}')
        subprocess.run(['bsdtar','-xf',str(package.resolve()),'-C',str(root),'--no-same-owner'],check=True)
    runtime=root/'usr/share/at1ass-shell'
    for relative in ['shell.qml','config/default.json','config/config.schema.json','tools/shell-ctl']:
        assert (runtime/relative).is_file(),relative
    for module in ['Mcu','Calendar','Qalculate','SystemMonitor','FuzzySearch','GreeterData','Connectivity']:
        assert (root/'usr/lib/qt6/qml'/module/'qmldir').is_file(),module
    for path in ['usr/bin/at1ass-shell','usr/bin/shell-ctl','usr/lib/systemd/user/at1ass-shell.service']:
        assert (root/path).exists(),path
    environment=dict(os.environ,QT_QPA_PLATFORM='wayland',QML_IMPORT_PATH=str(root/'usr/lib/qt6/qml'))
    runtime_dir=Path(environment.get('XDG_RUNTIME_DIR',f'/run/user/{os.getuid()}'))
    environment.setdefault('XDG_RUNTIME_DIR',str(runtime_dir))
    displays=[p.name for p in runtime_dir.glob('wayland-*') if p.is_socket()]
    if not environment.get('WAYLAND_DISPLAY') and len(displays)==1:
        environment['WAYLAND_DISPLAY']=displays[0]
    if not environment.get('WAYLAND_DISPLAY'):
        raise SystemExit('A Wayland connection is required for compile-only PanelWindow backends; no windows are created')
    for tree in [runtime,runtime/'greeter']:
        if not tree.exists():
            continue
        targets=[p for p in tree.rglob('*.qml') if not (tree==runtime and p.is_relative_to(runtime/'greeter'))]
        probe=tree/'_package_probe.qml'
        probe.write_text('''import QtQuick
import Quickshell
QtObject {
 property var targets: %s
 Component.onCompleted: Qt.callLater(() => {
  let failures=0
  for (const path of targets) {
   const component=Qt.createComponent(path,Component.PreferSynchronous)
   if(component.status!==Component.Ready){console.warn(component.errorString());failures++}
   component.destroy()
  }
  console.warn("PACKAGE COMPILED", targets.length, "FAILURES",failures)
  Qt.exit(failures?1:0)
 })
}
''' % json.dumps([p.as_uri() for p in targets]))
        result=subprocess.run(['qs','-p',str(probe)],env=environment,capture_output=True,text=True,timeout=45)
        output=result.stdout+result.stderr
        print(output)
        if result.returncode or f'PACKAGE COMPILED {len(targets)} FAILURES 0' not in output:
            raise SystemExit('Installed payload compilation failed')
    print('PASS: package payload paths, native modules and installed main/greeter QML')
