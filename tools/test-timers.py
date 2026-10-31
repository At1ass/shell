#!/usr/bin/env python3
"""Persistent timer/Pomodoro tests and Notify serialization on a private bus."""
from pathlib import Path
import json
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]

if len(sys.argv) > 1 and sys.argv[1] == '--notification-probe':
    from gi.repository import Gio, GLib
    command = json.loads(Path(sys.argv[2]).read_text())
    interface = Gio.DBusNodeInfo.new_for_xml('''<node><interface name="org.freedesktop.Notifications">
    <method name="Notify"><arg type="s" direction="in"/><arg type="u" direction="in"/>
    <arg type="s" direction="in"/><arg type="s" direction="in"/><arg type="s" direction="in"/>
    <arg type="as" direction="in"/><arg type="a{sv}" direction="in"/><arg type="i" direction="in"/>
    <arg type="u" direction="out"/></method></interface></node>''').interfaces[0]
    loop = GLib.MainLoop()
    received = []
    processes = []
    def call(connection, sender, path, iface, method, parameters, invocation):
        received.append(parameters.unpack())
        invocation.return_value(GLib.Variant('(u)', (1,)))
    def acquired(connection, name):
        connection.register_object('/org/freedesktop/Notifications',interface,call,None,None)
    def named(connection, name):
        processes.append(subprocess.Popen(command,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True))
    def check():
        if processes and processes[0].poll() is not None:
            loop.quit()
            return False
        return True
    Gio.bus_own_name(Gio.BusType.SESSION,'org.freedesktop.Notifications',Gio.BusNameOwnerFlags.NONE,acquired,named,None)
    GLib.timeout_add(10,check)
    GLib.timeout_add_seconds(7,lambda:(loop.quit(),False)[1])
    loop.run()
    assert processes, 'notification client not started'
    stdout,stderr = processes[0].communicate(timeout=2)
    assert processes[0].returncode == 0, stderr
    assert len(received) == 1 and received[0][0] == 'Timer', received
    assert received[0][3:5] == ('Timer finished','The countdown is complete.'), received
    assert received[0][5:] == ([],{},-1), received
    print('PASS: real gdbus Notify argument serialization on a private bus')
    raise SystemExit(0)

with tempfile.TemporaryDirectory(prefix='shell-timers-') as directory:
    directory = Path(directory)
    imports = directory/'imports'
    def write(name,text):
        path=imports/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_text(text)
    write('Quickshell/qmldir','module Quickshell\nSingleton 1.0 Singleton.qml\n')
    write('Quickshell/Singleton.qml','import QtQml\nQtObject {default property list<QtObject> children}\n')
    write('Quickshell/Io/qmldir','module Quickshell.Io\nProcess 1.0 Process.qml\nIpcHandler 1.0 IpcHandler.qml\n')
    write('Quickshell/Io/IpcHandler.qml','import QtQml\nQtObject {property string target:""}\n')
    write('Quickshell/Io/Process.qml','import QtQml\nQtObject {property bool running:false;property var command:[];property int starts:0;onRunningChanged:if(running)starts++;signal exited(int exitCode)}\n')
    write('qs/src/core/config/qmldir','module qs.src.core.config\nsingleton AppConfig 1.0 AppConfig.qml\n')
    write('qs/src/core/config/AppConfig.qml','''pragma Singleton
import QtQml
QtObject {
 property bool ready:true
 property bool stateReady:true
 property bool timersEnabled:true
 property bool timerNotify:true
 property int pomodoroWorkMinutes:25
 property int pomodoroShortBreakMinutes:5
 property int pomodoroLongBreakMinutes:15
 property int pomodoroLongEvery:4
 property var stateData:({})
 function updateState(section,fields) {
  const next=Object.assign({},stateData)
  next[section]=Object.assign({},next[section],fields);stateData=next
 }
}
''')
    write('qs/src/core/services/qmldir','module qs.src.core.services\n'+''.join(f'singleton {name} 1.0 {name}.qml\n' for name in ['SessionMonitor','DateTime','ToastService']))
    write('qs/src/core/services/SessionMonitor.qml','pragma Singleton\nimport QtQml\nQtObject {signal resumed()}\n')
    write('qs/src/core/services/DateTime.qml','pragma Singleton\nimport QtQml\nQtObject {property QtObject clock:QtObject {property date date:new Date()}}\n')
    write('qs/src/core/services/ToastService.qml','pragma Singleton\nimport QtQml\nQtObject {function warning(message){}}\n')
    shutil.copy2(ROOT/'src/core/services/TimerTimeline.js',directory/'TimerTimeline.js')
    source=(ROOT/'src/core/services/TimerService.qml').read_text().replace('pragma Singleton\n','',1).replace('import qs.src.core.config','import qs.src.core.config\nimport qs.src.core.services')
    (directory/'TestTimer.qml').write_text(source)
    (directory/'tst_timer.qml').write_text('''import QtQuick
import QtTest
import qs.src.core.config
import qs.src.core.services
import "TimerTimeline.js" as Timeline
TestCase {
 id:tests;name:"Timers";when:windowShown
 Component {id:fixture;TestTimer {}}
 function make() {
  AppConfig.ready=true;AppConfig.stateReady=true;AppConfig.timersEnabled=true;AppConfig.timerNotify=true
  AppConfig.pomodoroWorkMinutes=25;AppConfig.pomodoroShortBreakMinutes=5;AppConfig.pomodoroLongBreakMinutes=15;AppConfig.pomodoroLongEvery=4
  AppConfig.stateData={timer:{status:"idle"},unrelated:{marker:42}}
  return createTemporaryObject(fixture,tests)
 }
 function test_countdown_validation_pause_and_finish() {
  const service=make();verify(!service.start(0));verify(!service.start(1.5));verify(!service.start(1441))
  verify(service.start(5));verify(!service.start(10));verify(service.pause());verify(!service.running)
  const remaining=service.view.remainingMs;verify(remaining<=300000 && remaining>299900)
  service.refresh();compare(service.view.remainingMs,remaining)
  verify(service.resume());AppConfig.updateState("timer",{startedAt:Date.now()-301000});service.refresh()
  compare(service.status,"finished");compare(service.timeText,"0:00")
  const process=findChild(service,"timerNotification");compare(process.starts,1)
  service.refresh();compare(process.starts,1,"completion is emitted once per persisted run")
  console.info("NOTIFY_ARGV "+JSON.stringify(process.command))
  compare(AppConfig.stateData.unrelated.marker,42)
  verify(service.stop());compare(service.status,"idle")
 }
 function test_hidden_countdown_uses_boundary_timer() {
  const service=make();verify(service.start(1));compare(service.displayWatchers,0)
  AppConfig.updateState("timer",{elapsedMs:59980});service.refresh()
  tryCompare(service,"status","finished",1000)
  compare(findChild(service,"timerNotification").starts,1)
 }
 function test_expired_countdown_restored_without_replay() {
  const service=make();verify(service.start(1));service.destroy();wait(1)
  AppConfig.updateState("timer",{startedAt:Date.now()-61000})
  const restored=createTemporaryObject(fixture,tests);restored.init()
  compare(restored.status,"finished");compare(findChild(restored,"timerNotification").starts,1)
  restored.refresh();compare(findChild(restored,"timerNotification").starts,1)
 }
 function test_pomodoro_boundaries_and_large_jump() {
  const service=make();verify(service.pomodoro());const state=AppConfig.stateData.timer
  const at=minutes=>Timeline.snapshot(state,state.startedAt+minutes*60000)
  compare(at(25).phase,"shortBreak");compare(at(25).stage,1);compare(at(25).remainingMs,300000)
  compare(at(30).phase,"work");compare(at(30).round,2)
  compare(at(115).phase,"longBreak");compare(at(115).round,4)
  compare(at(130).phase,"work");compare(at(130).round,1);compare(at(130).stage,8)
  compare(at(130*1000000+25).stage,8000001,"large catch-up uses arithmetic, not replay")
  const one=Object.assign({},state,{longEvery:1})
  compare(Timeline.snapshot(one,one.startedAt+25*60000).phase,"longBreak")
 }
 function test_resume_catches_current_phase_once() {
  const service=make();verify(service.pomodoro())
  AppConfig.updateState("timer",{startedAt:Date.now()-116*60000})
  SessionMonitor.resumed();compare(service.view.phase,"longBreak")
  const process=findChild(service,"timerNotification");compare(process.starts,1)
  const stored=AppConfig.stateData
  service.destroy();wait(1)
  const restored=createTemporaryObject(fixture,tests);restored.init()
  compare(restored.view.phase,"longBreak");compare(findChild(restored,"timerNotification").starts,0)
  compare(AppConfig.stateData.timer.notifiedStage,7)
  compare(AppConfig.stateData.timer.workMs,stored.timer.workMs)
 }
 function test_disable_pauses_and_never_loops_on_expired_state() {
  const service=make();verify(service.pomodoro());AppConfig.timersEnabled=false
  compare(service.status,"paused");verify(!service.resume())
  AppConfig.timersEnabled=true;compare(service.status,"paused");verify(service.resume())
  service.stop();verify(service.start(1))
  AppConfig.updateState("timer",{startedAt:Date.now()-61000});AppConfig.timersEnabled=false
  compare(service.status,"finished");compare(findChild(service,"timerNotification").starts,0)
 }
 function test_loading_and_invalid_state() {
  const service=make();AppConfig.stateReady=false;verify(!service.start(10))
  AppConfig.stateReady=true
  AppConfig.updateState("timer",{status:"running",mode:"pomodoro",elapsedMs:0,startedAt:Date.now(),workMs:-1})
  service.refresh();compare(service.status,"idle")
  verify(service.start(10));const state=AppConfig.stateData.timer
  AppConfig.pomodoroWorkMinutes=30
  compare(AppConfig.stateData.timer.durationMs,state.durationMs,"config does not rewrite a run")
 }
}
''')
    result=subprocess.run(['/usr/lib/qt6/bin/qmltestrunner','-input',str(directory/'tst_timer.qml'),'-import',str(imports)],
        env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software'),capture_output=True,text=True,timeout=30)
    output=result.stdout+result.stderr
    print(output)
    if result.returncode or any(marker in output for marker in ['QWARN','ReferenceError','TypeError','Unable to assign']):
        raise SystemExit(result.returncode or 1)
    command=json.loads(next(line.split('NOTIFY_ARGV ',1)[1] for line in output.splitlines() if 'NOTIFY_ARGV ' in line))
    path=directory/'notify.json';path.write_text(json.dumps(command))
    subprocess.run(['dbus-run-session','--',sys.executable,str(Path(__file__).resolve()),'--notification-probe',str(path)],check=True,timeout=12)

    # Real FileView/AppConfig transactions in disposable XDG paths and two
    # separate Quickshell engines. Notifications remain disabled throughout.
    tree=directory/'persistent';(tree/'src/core').mkdir(parents=True)
    shutil.copytree(ROOT/'src/core/config',tree/'src/core/config')
    shutil.copytree(ROOT/'config',tree/'config')
    services=tree/'src/core/services';services.mkdir()
    for name in ['TimerService.qml','TimerTimeline.js']:
        shutil.copy2(ROOT/'src/core/services'/name,services/name)
    for name in ['SessionMonitor','DateTime','ToastService']:
        shutil.copy2(imports/f'qs/src/core/services/{name}.qml',services/f'{name}.qml')
    (services/'qmldir').write_text('module qs.src.core.services\n'+''.join(
        f'singleton {name} 1.0 {name}.qml\n' for name in ['TimerService','SessionMonitor','DateTime','ToastService']))
    home=directory/'xdg/quickshell';home.mkdir(parents=True)
    config=json.loads((ROOT/'config/default.json').read_text());config['timers']['notify']=False
    (home/'config.json').write_text(json.dumps(config))
    (home/'state.json').write_text(json.dumps({'unrelated':{'marker':42}}))
    env=dict(os.environ,QT_QPA_PLATFORM='offscreen',XDG_CONFIG_HOME=str(home.parent),XDG_CACHE_HOME=str(directory/'cache'))
    env.pop('WAYLAND_DISPLAY',None)
    for stage in ['save','restore']:
        (tree/'shell.qml').write_text('''import QtQuick
import Quickshell
import qs.src.core.config
import qs.src.core.services
Scope {
 id:root
 property bool checked:false
 Timer {interval:10;repeat:true;running:!root.checked;onTriggered: {
  if(!AppConfig.ready || !AppConfig.stateReady)return
  root.checked=true
  if("STAGE"==="save") {
   if(!TimerService.start(10) || !TimerService.pause()) {console.warn("PERSIST FAIL");Qt.exit(1)}
  } else {
   if(!TimerService.paused || TimerService.stored.durationMs!==600000 || TimerService.view.remainingMs<590000
      || AppConfig.stateData.unrelated.marker!==42 || !TimerService.resume() || !TimerService.stop()) {
    console.warn("PERSIST FAIL");Qt.exit(1)
   }
  }
  finish.start()
 }}
 Timer {id:finish;interval:1000;onTriggered:{console.info("PERSIST PASS");Qt.quit()}}
 Timer {interval:8000;running:true;onTriggered:Qt.exit(1)}
}
'''.replace('STAGE',stage))
        result=subprocess.run(['qs','-p',str(tree)],env=env,capture_output=True,text=True,timeout=12)
        output=result.stdout+result.stderr
        assert result.returncode==0 and 'PERSIST PASS' in output and 'PERSIST FAIL' not in output,output
        stored=json.loads((home/'state.json').read_text())
        assert stored['timer']['status']==('paused' if stage=='save' else 'idle'),stored
        assert stored['unrelated']=={'marker':42},stored
    print('PASS: timer state saved/restored across separate Quickshell processes')
