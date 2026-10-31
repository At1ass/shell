#!/usr/bin/env python3
"""Battery threshold hysteresis with inert UPower and notification transport."""
from pathlib import Path
import json
import os
import shutil
import subprocess
import sys
import tempfile

ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='shell-power-') as directory:
    directory=Path(directory);imports=directory/'imports'
    def write(name,text):
        path=imports/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_text(text)
    write('Quickshell/qmldir','module Quickshell\nSingleton 1.0 Singleton.qml\n')
    write('Quickshell/Singleton.qml','import QtQml\nQtObject {default property list<QtObject> children}\n')
    write('Quickshell/Io/qmldir','module Quickshell.Io\nProcess 1.0 Process.qml\nIpcHandler 1.0 IpcHandler.qml\n')
    write('Quickshell/Io/Process.qml','import QtQml\nQtObject {property bool running:false;property var command:[];signal exited(int exitCode)}\n')
    write('Quickshell/Io/IpcHandler.qml','import QtQml\nQtObject {property string target:""}\n')
    write('Quickshell/Services/UPower/qmldir','module Quickshell.Services.UPower\nsingleton UPower 1.0 UPower.qml\nUPowerDeviceState 1.0 UPowerDeviceState.qml\n')
    write('Quickshell/Services/UPower/UPowerDeviceState.qml','import QtQml\nQtObject {enum Kind {Discharging,Charging,PendingCharge,Empty,PendingDischarge,FullyCharged,Unknown}}\n')
    write('Quickshell/Services/UPower/UPower.qml','''pragma Singleton
import QtQml
QtObject {property QtObject displayDevice:QtObject {
 property bool ready:true;property bool isLaptopBattery:true;property real percentage:0.8
 property int state:0;property string nativePath:"BAT0";property int timeToEmpty:7200;property int timeToFull:3600
}}
''')
    write('qs/src/core/config/qmldir','module qs.src.core.config\nsingleton AppConfig 1.0 AppConfig.qml\n')
    write('qs/src/core/config/AppConfig.qml','''pragma Singleton
import QtQml
QtObject {
 property bool ready:true;property bool stateReady:true;property bool batteryWarningsEnabled:true
 property int batteryLowThreshold:15;property int batteryCriticalThreshold:5;property int batteryWarningHysteresis:3
 property var data:({});property var stateData:({})
 function updateState(section,fields) {const next=Object.assign({},stateData);next[section]=Object.assign({},next[section],fields);stateData=next}
}
''')
    write('qs/src/core/services/qmldir','module qs.src.core.services\nDesktopNotification 1.0 DesktopNotification.qml\nsingleton SessionMonitor 1.0 SessionMonitor.qml\n')
    write('qs/src/core/services/SessionMonitor.qml','pragma Singleton\nimport QtQml\nQtObject {signal resumed()}\n')
    shutil.copy2(ROOT/'src/core/services/DesktopNotification.qml',imports/'qs/src/core/services/DesktopNotification.qml')
    (directory/'TestPower.qml').write_text((ROOT/'src/core/services/PowerService.qml').read_text().replace('pragma Singleton\n','',1).replace('import qs.src.core.config','import qs.src.core.config\nimport qs.src.core.services'))
    (directory/'tst_power.qml').write_text('''import QtQuick
import QtTest
import Quickshell.Services.UPower
import qs.src.core.config
TestCase {
 id:tests;name:"PowerWarnings";when:windowShown
 Component {id:fixture;TestPower {}}
 function make() {
  AppConfig.ready=false;AppConfig.stateReady=true;AppConfig.batteryWarningsEnabled=true
  AppConfig.stateData={unrelated:{marker:42}}
  UPower.displayDevice.ready=true;UPower.displayDevice.isLaptopBattery=true;UPower.displayDevice.percentage=0.8
  UPower.displayDevice.state=UPowerDeviceState.Discharging
  UPower.displayDevice.timeToEmpty=7200;UPower.displayDevice.timeToFull=3600
  const service=createTemporaryObject(fixture,tests);AppConfig.ready=true;service.init();return service
 }
 function finish(notice) {notice.transport.running=false;notice.transport.exited(0)}
 function level(service,value) {UPower.displayDevice.percentage=value/100;service.reconcile()}
 function test_hysteresis_and_critical_priority() {
  const service=make();const notice=findChild(service,"batteryNotification")
  level(service,15);compare(notice.starts,1);finish(notice)
  level(service,16);level(service,14);compare(notice.starts,1)
  level(service,18);level(service,15);compare(notice.starts,2);finish(notice)
  level(service,5);compare(notice.starts,3)
  verify(notice.command.includes("{'urgency': <byte 2>}"))
  console.info("NOTIFY_ARGV "+JSON.stringify(notice.command));finish(notice)
  level(service,6);level(service,5);compare(notice.starts,3)
  level(service,8);level(service,5);compare(notice.starts,4)
  compare(AppConfig.stateData.unrelated.marker,42)
 }
 function test_queued_warning_is_cancelled_after_recovery() {
  const service=make();const notice=findChild(service,"batteryNotification")
  level(service,15);level(service,4);compare(notice.starts,1)
  level(service,20);finish(notice);wait(1)
  compare(notice.starts,1,"obsolete critical warning must not appear after recovery")
 }
 function test_restart_readiness_and_charger() {
  const service=make();level(service,10);service.destroy();wait(1)
  const restored=createTemporaryObject(fixture,tests);restored.init()
  const notice=findChild(restored,"batteryNotification");compare(notice.starts,0,"saved latch prevents duplicate warning")
  UPower.displayDevice.ready=false;level(restored,0);compare(notice.starts,0)
  UPower.displayDevice.percentage=0.1;UPower.displayDevice.ready=true;restored.reconcile();compare(notice.starts,0)
  UPower.displayDevice.state=UPowerDeviceState.Unknown;restored.reconcile()
  UPower.displayDevice.state=UPowerDeviceState.Discharging;restored.reconcile();compare(notice.starts,0,"unknown state must not rearm")
  UPower.displayDevice.state=UPowerDeviceState.Charging;restored.reconcile()
  UPower.displayDevice.state=UPowerDeviceState.Discharging;restored.reconcile();compare(notice.starts,1)
 }
 function test_disabled_and_remaining_time() {
  const service=make();const notice=findChild(service,"batteryNotification")
  AppConfig.batteryWarningsEnabled=false;level(service,1);compare(notice.starts,0)
  verify(service.remainingText.includes("2h"))
  UPower.displayDevice.timeToEmpty=0;compare(service.remainingText,"")
  UPower.displayDevice.isLaptopBattery=false;service.reconcile();verify(!service.available);compare(notice.starts,0)
 }
}
''')
    result=subprocess.run(['/usr/lib/qt6/bin/qmltestrunner','-input',str(directory/'tst_power.qml'),'-import',str(imports)],
        env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software'),capture_output=True,text=True,timeout=20)
    output=result.stdout+result.stderr;print(output)
    if result.returncode or any(marker in output for marker in ['QWARN','ReferenceError','TypeError','Unable to assign']):raise SystemExit(result.returncode or 1)
    command=json.loads(next(line.split('NOTIFY_ARGV ',1)[1] for line in output.splitlines() if 'NOTIFY_ARGV ' in line))
    path=directory/'notify.json';path.write_text(json.dumps(command))
    subprocess.run(['dbus-run-session','--',sys.executable,str(ROOT/'tools/test-timers.py'),'--notification-probe',str(path)],check=True,timeout=12)
