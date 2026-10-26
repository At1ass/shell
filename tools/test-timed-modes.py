#!/usr/bin/env python3
"""Exercise persisted mode deadlines without creating a real idle inhibitor."""
from pathlib import Path
import json, os, shutil, subprocess, tempfile, time

ROOT = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='shell-timed-test-') as directory:
    tree = Path(directory)
    for name in ['src/core/config','config']:
        shutil.copytree(ROOT/name,tree/name)
    services = tree/'src/core/services'
    services.mkdir()
    for name in ['TimedMode','NotificationDND','IdleInhibitorService']:
        source=(ROOT/f'src/core/services/{name}.qml').read_text()
        if name=='NotificationDND': source=source.replace('import Quickshell.Hyprland','import TestHyprland')
        if name=='IdleInhibitorService':
            source=source[:source.index('    IdleInhibitor {')]+'}\n'
            source=source.replace('import Quickshell.Wayland\n','')
        (services/f'{name}.qml').write_text(source)
    (services/'SessionMonitor.qml').write_text('pragma Singleton\nimport QtQml\nQtObject {signal resumed()}\n')
    (services/'DateTime.qml').write_text('pragma Singleton\nimport QtQml\nQtObject {property QtObject clock:QtObject {property date date:new Date()}}\n')
    (services/'qmldir').write_text('module qs.src.core.services\nTimedMode 1.0 TimedMode.qml\n'+''.join(f'singleton {name} 1.0 {name}.qml\n' for name in ['NotificationDND','IdleInhibitorService','SessionMonitor','DateTime']))
    hypr=tree/'imports/TestHyprland';hypr.mkdir(parents=True)
    (hypr/'qmldir').write_text('module TestHyprland\nsingleton Hyprland 1.0 Hyprland.qml\n')
    (hypr/'Hyprland.qml').write_text('pragma Singleton\nimport QtQml\nQtObject {property QtObject focusedWorkspace:QtObject {property bool hasFullscreen:false}}\n')
    home=tree/'xdg/quickshell';home.mkdir(parents=True)
    shutil.copy2(ROOT/'config/default.json',home/'config.json')
    (home/'state.json').write_text(json.dumps({'notifications':{'doNotDisturb':True,'expiresAt':int(time.time()*1000)-1000,'marker':'keep'},'idleInhibitor':{'enabled':True},'unrelated':{'value':7}}))
    env=dict(os.environ,QT_QPA_PLATFORM='offscreen',XDG_CONFIG_HOME=str(tree/'xdg'),XDG_CACHE_HOME=str(tree/'cache'),QML_IMPORT_PATH=str(tree/'imports'))
    env.pop('WAYLAND_DISPLAY',None)
    binary=tree/'bin';binary.mkdir()
    fake=binary/'qs'
    fake.write_text('#!/usr/bin/env python3\nimport json,sys\nprint(json.dumps(sys.argv[1:]))\n');fake.chmod(0o755)
    cli_env={**env,'PATH':str(binary)+os.pathsep+os.environ['PATH']}
    for mode,method,handler in [('dnd','setDndFor','notifications'),('caffeine','setIdleInhibitorFor','globalstates')]:
        result=subprocess.run([str(ROOT/'tools/shell-ctl'),mode,'for','30'],env=cli_env,capture_output=True,text=True,check=True)
        assert json.loads(result.stdout)[-3:]==[handler,method,'30']
        for value in ['0','1441','-1','1.5','1; echo wrong','']:
            result=subprocess.run([str(ROOT/'tools/shell-ctl'),mode,'for',value],env=cli_env,capture_output=True,text=True)
            assert result.returncode!=0 and not result.stdout
    print('PASS: CLI duration routing and validation with a fake transport')
    probe=tree/'probe.qml'
    probe.write_text('''import QtQuick
import Quickshell
import TestHyprland
import qs.src.core.config
import qs.src.core.services
Scope {
 id:root
 property int step:0
 property int ticks:0
 property int settle:0
 function check(ok,message) {if(!ok){console.warn("FAIL "+message);Qt.exit(1);throw new Error(message)}}
 Component.onCompleted: {NotificationDND.init();IdleInhibitorService.setInhibit(false)}
 Timer {interval:150;repeat:true;running:true;onTriggered:{
  root.check(++root.ticks<50,"mode test deadline")
  if(!AppConfig.stateReady)return
  if(root.step===0) {
   root.check(!NotificationDND.enabled && AppConfig.stateData.notifications.expiresAt===0,"expired startup flag is normalized")
   root.check(!IdleInhibitorService.inhibit,"explicit off before state load overrides persisted on")
   root.check(AppConfig.stateData.notifications.marker==="keep" && AppConfig.stateData.unrelated.value===7,"other state preserved")
   const before=JSON.stringify(AppConfig.stateData)
   for(const invalid of [0,-1,1441,1.5,NaN])root.check(!NotificationDND.setForMinutes(invalid),"invalid duration rejected")
   root.check(before===JSON.stringify(AppConfig.stateData),"invalid duration cannot mutate state")
   root.check(NotificationDND.setForMinutes(30) && NotificationDND.temporary,"temporary mode starts")
   root.check(NotificationDND.expiresAt>Date.now()+1799000 && NotificationDND.expiresAt<=Date.now()+1800000,"absolute deadline")
   NotificationDND.setEnabled(true)
   root.check(NotificationDND.enabled && !NotificationDND.temporary && AppConfig.stateData.notifications.expiresAt===0,"manual on becomes permanent")
   NotificationDND.setEnabled(false)
   Hyprland.focusedWorkspace.hasFullscreen=true
   AppConfig.updateState("notifications",{doNotDisturb:true,expiresAt:Date.now()+60})
   root.step=1;return
  }
  if(root.step===1) {
   root.check(!NotificationDND.enabled && NotificationDND.active,"expiry preserves fullscreen policy")
   Hyprland.focusedWorkspace.hasFullscreen=false
   AppConfig.updateState("notifications",{doNotDisturb:true,expiresAt:Date.now()-100})
   NotificationDND.setEnabled(true);root.step=2;return
  }
  if(root.step===2) {
   root.check(NotificationDND.enabled && !NotificationDND.temporary,"manual action supersedes queued expiry")
   AppConfig.updateState("notifications",{doNotDisturb:true,expiresAt:Date.now()+60})
   NotificationDND._mode.refresh();Qt.callLater(()=>NotificationDND._mode.expiryTimer.stop())
   root.step=3;return
  }
  if(root.step===3) {
   root.check(NotificationDND.enabled,"simulate a timer paused during sleep")
   SessionMonitor.resumed()
   root.check(!NotificationDND.enabled,"resume immediately rechecks wall clock")
   AppConfig.updateState("idleInhibitor",{enabled:true,expiresAt:Date.now()+60})
   IdleInhibitorService._mode.refresh();Qt.callLater(()=>IdleInhibitorService._mode.expiryTimer.stop())
   root.step=4;return
  }
  if(root.step===4) {
   root.check(IdleInhibitorService.inhibit,"simulate a missed deadline tick")
   DateTime.clock.date=new Date()
   root.check(!IdleInhibitorService.inhibit,"shared clock rechecks deadlines")
   AppConfig.updateState("idleInhibitor",{enabled:true,expiresAt:0})
   root.step=5;return
  }
  if(root.step===5) {
   root.check(IdleInhibitorService.inhibit && !IdleInhibitorService.temporary,"legacy permanent flag survives")
   IdleInhibitorService.setForMinutes(10);IdleInhibitorService.toggleInhibit()
   root.check(!IdleInhibitorService.inhibit && AppConfig.stateData.idleInhibitor.expiresAt===0,"manual toggle cancels timer")
   AppConfig.updateState("notifications",{doNotDisturb:true,expiresAt:Date.now()+7000})
   IdleInhibitorService.setInhibit(true)
   root.step=6;return
  }
  if(++root.settle>=5){console.warn("MODE PASS");Qt.quit()}
 }}
}
''')
    def run(path,marker):
        result=subprocess.run(['qs','-p',str(path)],env=env,capture_output=True,text=True,timeout=15)
        output=result.stdout+result.stderr
        print(output)
        assert result.returncode==0 and marker in output and not any(word in output for word in ['FAIL','ERROR','TypeError','ReferenceError','Binding loop','Unable to assign']),output
    run(probe,'MODE PASS')
    saved=json.loads((home/'state.json').read_text());deadline=saved['notifications']['expiresAt']
    assert saved['notifications']['doNotDisturb'] and deadline>time.time()*1000
    restart=tree/'restart.qml'
    restart.write_text('''import QtQuick
import Quickshell
import qs.src.core.config
import qs.src.core.services
Scope {
 id:root
 property int ticks:0
 property bool loaded:false
 property int settled:0
 function check(ok,message) {if(!ok){console.warn("FAIL "+message);Qt.exit(1);throw new Error(message)}}
 Timer {interval:100;repeat:true;running:true;onTriggered:{
  root.check(++root.ticks<120,"restart deadline")
  if(!AppConfig.stateReady)return
  if(!root.loaded) {
   root.check(NotificationDND.enabled && NotificationDND.expiresAt===DEADLINE,"restart keeps original deadline")
   root.check(IdleInhibitorService.inhibit && !IdleInhibitorService.temporary,"restart keeps permanent mode")
   root.loaded=true
  }
  if(NotificationDND.enabled){root.check(Date.now()<DEADLINE+500,"deadline was not extended");return}
  if(AppConfig.stateData.notifications.doNotDisturb)return
  root.check(AppConfig.stateData.notifications.expiresAt===0,"expired metadata cleared")
  root.check(IdleInhibitorService.inhibit && AppConfig.stateData.unrelated.value===7,"expiry affects only its mode")
  if(++root.settled>=6){console.warn("MODE RESTART PASS");Qt.quit()}
 }}
}
'''.replace('DEADLINE',str(deadline)))
    run(restart,'MODE RESTART PASS')
    stored=json.loads((home/'state.json').read_text())
    assert not stored['notifications']['doNotDisturb'] and stored['notifications']['expiresAt']==0
    print('PASS: persisted expiry, restart, resume, manual overrides and isolated state')
