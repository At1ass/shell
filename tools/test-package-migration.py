#!/usr/bin/env python3
"""Exercise migration guards/rollback with private XDG files and fake commands."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]
NAMES=['at1ass-shell-git','at1ass-shell-plugins-git','at1ass-shell-greeter-git']

class MigrationTests(unittest.TestCase):
    def run_case(self, scenario, apply=True):
        with tempfile.TemporaryDirectory(prefix='shell-migration-test-') as directory:
            root=Path(directory);config=root/'config';binary=root/'bin';binary.mkdir()
            integration=config/'hypr/keybinds.lua';integration.parent.mkdir(parents=True)
            original='command="qs -c shell ipc call globalstates lockScreen"\n'
            integration.write_text(original)
            scripts=root/'scripts';scripts.mkdir()
            wallpaper=scripts/'wallpapers.sh';wallpaper.write_text('#!/bin/sh\nqs -c shell ipc call wallpaper next\n');wallpaper.chmod(0o755)
            packages=root/'packages';packages.mkdir()
            for name in NAMES:(packages/(name+'.pkg.tar.zst')).touch()
            greeter=root/'greetd';greeter.mkdir()
            (greeter/'hyprland-greeter.conf').write_text("monitor = TEST,preferred,auto,1\nexec-once = hyprctl dispatch exit\n")
            trace=root/'trace' 
            dispatcher=binary/'dispatch'
            dispatcher.write_text('''#!/usr/bin/python3
import json,os,pathlib,sys,shutil
name=pathlib.Path(sys.argv[0]).name;args=sys.argv[1:]
with open(os.environ['TEST_TRACE'],'a') as out:out.write(json.dumps([name,*args])+"\\n")
scenario=os.environ['TEST_SCENARIO']
if name=='pacman':print(pathlib.Path(args[-1]).name.removesuffix('.pkg.tar.zst')+' r1.fixture-1')
elif name=='qs':
 count=sum(json.loads(line)[0]=='qs' for line in open(os.environ['TEST_TRACE']))
 print('true' if scenario=='locked' or (scenario=='late-lock' and count>=3) else 'false')
elif name=='systemctl':
 if args[1] in ['is-active','is-enabled']:sys.exit(0 if args[-1]=='quickshell.service' else 1)
elif name=='sudo':
 if scenario=='auth-fails':sys.exit(1)
 if args[0]=='install':shutil.copyfile(args[-2],args[-1])
 if args[:2]==['pacman','-U'] and scenario=='integration-changes':pathlib.Path(os.environ['TEST_INTEGRATION']).write_text('-- concurrent user edit\\n')
elif name=='at1ass-shell':
 print('OK: fixture')
 sys.exit(1 if scenario=='validation-fails' else 0)
''')
            dispatcher.chmod(0o755)
            for name in ['pacman','qs','systemctl','sudo','at1ass-shell','hyprctl']:(binary/name).symlink_to(dispatcher)
            source=(ROOT/'tools/migrate-installed.py').read_text()
            source=source.replace('/usr/bin/at1ass-shell',str(binary/'at1ass-shell'))
            source=source.replace("Path('/etc/greetd')",'Path('+repr(str(root/'greetd'))+')')
            script=root/'repo/tools/migrate-installed.py';script.parent.mkdir(parents=True);script.write_text(source)
            env=dict(os.environ,PATH=str(binary)+os.pathsep+os.environ['PATH'],XDG_CONFIG_HOME=str(config),XDG_STATE_HOME=str(root/'state'),TEST_TRACE=str(trace),TEST_SCENARIO=scenario,TEST_INTEGRATION=str(integration))
            argv=['python3',str(script),'--packages',str(packages),'--bin-dir',str(scripts)]
            if apply:argv.append('--apply')
            result=subprocess.run(argv,env=env,capture_output=True,text=True,timeout=20)
            calls=[json.loads(line) for line in trace.read_text().splitlines()]
            updated=integration.read_text()
            self.assertEqual(wallpaper.stat().st_mode & 0o777, 0o755)
            if scenario=='success' and apply and result.returncode==0:
                self.assertIn('at1ass-shell ipc call wallpaper next',wallpaper.read_text())
            else:
                self.assertIn('qs -c shell ipc call wallpaper next',wallpaper.read_text())
            if scenario=='success' and apply and result.returncode==0:
                self.assertEqual((greeter/'hyprland-greeter.conf').read_text(),"monitor = TEST,preferred,auto,1\nexec-once = hyprctl dispatch 'hl.dsp.exit()'\n")
            if scenario=='validation-fails':
                self.assertIn('hyprctl dispatch exit', (greeter/'hyprland-greeter.conf').read_text())
            backups=list((root/'state').rglob('keybinds.lua')) if (root/'state').exists() else []
            return result,calls,updated,original,len(backups)

    def test_preview_does_not_write_or_stop(self):
        result,calls,updated,original,backups=self.run_case('success',False)
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual(updated,original);self.assertEqual(backups,0)
        self.assertFalse(any(call[0] in {'sudo','systemctl','hyprctl'} for call in calls))

    def test_locked_session_never_authenticates_or_stops(self):
        result,calls,updated,original,backups=self.run_case('locked')
        self.assertNotEqual(result.returncode,0)
        self.assertIn('Unlock the session',result.stderr)
        self.assertEqual(updated,original);self.assertEqual(backups,0)
        self.assertFalse(any(call[0]=='sudo' or 'stop' in call for call in calls))

    def test_late_lock_never_stops_the_lock_owner(self):
        result,calls,updated,original,backups=self.run_case('late-lock')
        self.assertNotEqual(result.returncode,0);self.assertEqual(updated,original)
        self.assertNotIn(['systemctl','--user','stop','quickshell.service'],calls)
        self.assertFalse(any(c[:3]==['sudo','pacman','-U'] for c in calls))

    def test_auth_failure_preserves_running_setup(self):
        result,calls,updated,original,backups=self.run_case('auth-fails')
        self.assertNotEqual(result.returncode,0);self.assertEqual(updated,original);self.assertEqual(backups,0)
        self.assertFalse(any('stop' in call for call in calls))

    def test_success_orders_stop_before_plugin_install(self):
        result,calls,updated,original,backups=self.run_case('success')
        self.assertEqual(result.returncode,0,result.stderr)
        stop=next(i for i,c in enumerate(calls) if c==['systemctl','--user','stop','quickshell.service'])
        install=next(i for i,c in enumerate(calls) if c[:3]==['sudo','pacman','-U'])
        start=next(i for i,c in enumerate(calls) if c==['systemctl','--user','start','at1ass-shell.service'])
        self.assertLess(stop,install);self.assertLess(install,start)
        self.assertIn('at1ass-shell ipc call',updated);self.assertEqual(backups,1)

    def test_concurrent_integration_edit_is_not_overwritten(self):
        result,calls,updated,original,backups=self.run_case('integration-changes')
        self.assertNotEqual(result.returncode,0)
        self.assertIn('concurrent user edit',updated)
        self.assertIn(['systemctl','--user','start','quickshell.service'],calls)

    def test_failed_switch_restores_files_and_development_service(self):
        result,calls,updated,original,backups=self.run_case('validation-fails')
        self.assertNotEqual(result.returncode,0);self.assertEqual(updated,original);self.assertEqual(backups,1)
        self.assertIn(['systemctl','--user','start','quickshell.service'],calls)
        self.assertIn(['systemctl','--user','disable','at1ass-shell.service'],calls)

if __name__=='__main__':unittest.main()
