#!/usr/bin/env python3
"""Night-light restart/backoff with fake processes and in-memory state only."""
from pathlib import Path
import os
import sys
import json
import shutil
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='shell-nightlight-test-') as directory:
    directory=Path(directory)
    imports=directory/'imports'
    def write(name,text):
        path=imports/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_text(text)
    write('Quickshell/qmldir','module Quickshell\nSingleton 1.0 Singleton.qml\n')
    write('Quickshell/Singleton.qml','import QtQml\nQtObject {default property list<QtObject> children}\n')
    write('Quickshell/Io/qmldir','module Quickshell.Io\nProcess 1.0 Process.qml\nIpcHandler 1.0 IpcHandler.qml\n')
    write('Quickshell/Io/IpcHandler.qml','import QtQml\nQtObject {property string target:""}\n')
    write('Quickshell/Io/Process.qml','import QtQml\nQtObject {property bool running:false;property var command:[];property int starts:0;property int kills:0;function signal(number){if(number===9)kills++} onRunningChanged:if(running)starts++;signal exited(int code);function finish(code){running=false;exited(code)}}\n')
    write('qs/src/core/config/qmldir','module qs.src.core.config\nsingleton AppConfig 1.0 AppConfig.qml\n')
    write('qs/src/core/config/AppConfig.qml','''pragma Singleton
import QtQml
QtObject {
 property bool ready:true
 property int nightLightTemperature:4000
 property var stateData:({nightLight:{enabled:false}})
 function updateState(section,data) {const next=Object.assign({},stateData);next[section]=Object.assign({},next[section],data);stateData=next}
}
''')
    write('qs/src/core/services/qmldir','module qs.src.core.services\nsingleton ToastService 1.0 ToastService.qml\n')
    write('qs/src/core/services/ToastService.qml','pragma Singleton\nimport QtQml\nQtObject {function warning(message){}}\n')
    source=(ROOT/'src/core/services/NightLightService.qml').read_text().replace('pragma Singleton\n','',1).replace('import qs.src.core.config','import qs.src.core.config\nimport qs.src.core.services')
    (directory/'TestNightLight.qml').write_text(source)
    test=directory/'tst_nightlight.qml'
    test.write_text('''import QtQuick
import QtTest
import qs.src.core.config
TestCase {
 id:tests;name:"NightLight";when:windowShown
 Component {id:fixture;TestNightLight {}}
 function make() {AppConfig.stateData={nightLight:{enabled:false}};AppConfig.ready=true;return createTemporaryObject(fixture,tests)}
 function proc(service){return findChild(service,"nightLightProcess")}
 function retry(service){return findChild(service,"nightLightRetry")}
 function enable(service){findChild(service,"nightLightDetect").finish(0);service.setEnabled(true);verify(proc(service).running)}
 function test_failure_is_retained_until_healthy() {
  const service=make();enable(service);proc(service).finish(1)
  verify(service.errorMessage!=="");verify(service.canRetry);verify(service.retry())
  verify(service.errorMessage!=="","a restart alone is not confirmed healthy")
  findChild(service,"nightLightHealthy").triggered()
  compare(service.errorMessage,"");verify(service.active)
  service.setEnabled(false);proc(service).finish(0)
 }
 function test_missing_tool_and_manual_disable() {
  const service=make();service.setEnabled(true)
  findChild(service,"nightLightDetect").finish(1)
  verify(service.errorMessage.includes("Install"));verify(service.canRetry)
  service.toggle();verify(!service.enabled,"missing tool must not trap persisted enabled state")
 }
 function test_restored_state_waits_for_detection() {
  const service=make()
  service.setEnabled(true);verify(!proc(service).running)
  findChild(service,"nightLightDetect").finish(0);verify(proc(service).running)
  verify(AppConfig.stateData.nightLight.enabled)
 }
 function test_temperature_waits_for_exit_and_uses_latest_value() {
  const service=make();enable(service)
  const process=proc(service)
  service.setTemperature(4500);service.setTemperature(5000)
  verify(service._awaitingExit);compare(process.starts,1)
  retry(service).triggered();compare(process.starts,1,"cannot reuse a terminating process")
  process.finish(0);compare(service._consecutiveFailures,0)
  retry(service).triggered();verify(process.running);compare(process.starts,2)
  compare(process.command[2],"5000")
 }
 function test_crash_backoff_is_capped_and_healthy_run_resets() {
  const service=make();enable(service)
  let previous=0
  for(let i=0;i<12;i++) {
   proc(service).finish(0) // Even an unexpected clean exit must not spin.
   verify(retry(service).interval>=previous);verify(retry(service).interval<=30000)
   previous=retry(service).interval
   retry(service).triggered();verify(proc(service).running)
  }
  compare(retry(service).interval,30000)
  findChild(service,"nightLightHealthy").triggered();compare(service._consecutiveFailures,0)
  proc(service).finish(0);compare(retry(service).interval,300)
 }
 function test_disable_cancels_pending_retry_and_late_exit() {
  const service=make();enable(service)
  proc(service).finish(0);verify(retry(service).running)
  service.setEnabled(false);verify(!retry(service).running)
  retry(service).triggered();verify(!proc(service).running)
  service.setEnabled(true);verify(proc(service).running)
  service.setEnabled(false)
  findChild(service,"nightLightStopDeadline").triggered();compare(proc(service).kills,1)
  proc(service).finish(0)
  verify(!retry(service).running);verify(!service._awaitingExit)
  verify(!findChild(service,"nightLightStopDeadline").running)
 }
 function test_temperature_validation() {
  const service=make();enable(service)
  service.setTemperature(NaN);service.setTemperature(Infinity)
  compare(service.temperature,4000);verify(proc(service).running)
  service.setTemperature(1);compare(service.temperature,1000)
  service.setTemperature(9999);compare(service.temperature,6500)
 }
}
''')
    result=subprocess.run(['/usr/lib/qt6/bin/qmltestrunner','-input',str(test),'-import',str(imports)],env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software'),capture_output=True,text=True,timeout=15)
    output=result.stdout+result.stderr;print(output)
    if result.returncode or 'QWARN' in output:
        raise SystemExit(result.returncode or 1)
    if '--native' in sys.argv:
        fake=directory/'fake-sunset'
        fake.write_text('#!'+sys.executable+'\n'+"""import json,os,signal,sys,time
from pathlib import Path
path=Path(__file__).with_name('runs.log')
def log(event):
 with path.open('a') as stream:stream.write(json.dumps({'event':event,'pid':os.getpid(),'args':sys.argv[1:]})+'\\n')
def stop(*args):
 time.sleep(0.15);log('stop');sys.exit(0)
signal.signal(signal.SIGTERM,stop)
log('start');print('ready',flush=True)
while True:time.sleep(0.1)
""")
        fake.chmod(0o755)
        shutil.rmtree(imports/'Quickshell')
        tree=imports/'qs'
        source=(ROOT/'src/core/services/NightLightService.qml').read_text().replace('pragma Singleton\n','',1).replace('import qs.src.core.config','import qs.src.core.config\nimport qs.src.core.services')
        source=source.replace('["which", "hyprsunset"]','['+json.dumps(sys.executable)+', "-c", "pass"]').replace('["hyprsunset",','['+json.dumps(str(fake))+',')
        source=source.replace('Singleton {','Item {',1)
        source=source.replace('    id: root','    id: root\n    property alias testProcess: sunsetProc\n    property bool testReady: false',1)
        source=source.replace('        id: sunsetProc','        id: sunsetProc\n        stdout: SplitParser {onRead: line => {if(line === "ready")root.testReady=true}}',1)
        (tree/'TestNative.qml').write_text(source)
        probe=tree/'shell.qml'
        probe.write_text("""import QtQuick
import Quickshell
QtObject {
 id:root
 property QtObject controller:TestNative {id:service}
 property int step:0
 property int ticks:0
 property int oldPid:0
 property Timer check:Timer {
  interval:20;repeat:true;running:true
  onTriggered:{
   if(++root.ticks>200){console.warn("NIGHTLIGHT FAIL timeout");Qt.exit(1);return}
   if(root.step===0){if(!service.available)return;service.setEnabled(true);root.step=1}
   else if(root.step===1){
    if(!service.testReady)return
    root.oldPid=service.testProcess.processId
    service.testReady=false
    service.setTemperature(4500)
    service._startSunset()
    if(!service._awaitingExit){Qt.exit(2);return}
    root.step=2
   } else if(root.step===2){
    if(service._awaitingExit || !service.testReady || !service.testProcess.running || service.testProcess.processId===root.oldPid)return
    service.setEnabled(false);root.step=3
   } else if(!service.testProcess.running && !service._awaitingExit){
    console.warn("NIGHTLIGHT NATIVE PASS");Qt.quit()
   }
  }
 }
}
""")
        native=subprocess.run(['qs','-p',str(probe)],env=dict(os.environ,QT_QPA_PLATFORM='offscreen'),capture_output=True,text=True,timeout=8)
        output=native.stdout+native.stderr;print(output)
        assert native.returncode==0 and 'NIGHTLIGHT NATIVE PASS' in output, output
        events=[json.loads(line) for line in (directory/'runs.log').read_text().splitlines()]
        assert [entry['event'] for entry in events]==['start','stop','start','stop'], events
        assert events[0]['args']==['-t','4000'] and events[2]['args']==['-t','4500'], events
