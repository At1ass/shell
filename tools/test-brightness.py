#!/usr/bin/env python3
"""Exercise DDC transport with a non-spawning Process; never change real brightness."""
from pathlib import Path
import os
import sys
import json
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='shell-brightness-test-') as directory:
    directory = Path(directory)
    imports = directory/'imports'
    def write(name, source):
        path = imports/name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(source)
    write('Quickshell/qmldir', 'module Quickshell\nSingleton 1.0 Singleton.qml\n')
    write('Quickshell/Singleton.qml', 'import QtQml\nQtObject {default property list<QtObject> children}\n')
    write('Quickshell/Io/qmldir', 'module Quickshell.Io\nProcess 1.0 Process.qml\nStdioCollector 1.0 StdioCollector.qml\n')
    write('Quickshell/Io/Process.qml', '''import QtQml
QtObject {
 property bool running:false
 property var command:[]
 property QtObject stdout:null
 property int kills:0
 property int starts:0
 onRunningChanged: if(running)starts++
 signal exited(int code)
 function signal(number) {if(number===9)kills++}
 function reply(text,code) {stdout.text=text;stdout.streamFinished();running=false;exited(code)}
}
''')
    write('Quickshell/Io/StdioCollector.qml', 'import QtQml\nQtObject {property string text:"";signal streamFinished()}\n')
    write('qs/src/core/config/qmldir', 'module qs.src.core.config\n')
    write('qs/src/core/services/qmldir', 'module qs.src.core.services\nsingleton ToastService 1.0 ToastService.qml\n')
    write('qs/src/core/services/ToastService.qml', 'pragma Singleton\nimport QtQml\nQtObject {property int warnings:0;function warning(message){warnings++}}\n')
    source=(ROOT/'src/core/services/BrightnessService.qml').read_text().replace('pragma Singleton\n','',1).replace('import Quickshell.Io','import Quickshell.Io\nimport qs.src.core.services')
    (directory/'TestBrightness.qml').write_text(source)
    test=directory/'tst_brightness.qml'
    test.write_text('''import QtQuick
import QtTest
TestCase {
 id:tests;name:"Brightness";when:windowShown
 Component {id:fixture;TestBrightness {}}
 function make() {const service=createTemporaryObject(fixture,tests);verify(service!==null);return service}
 function process(service) {return findChild(service,"brightnessCommand")}
 function reply(service,text,code=0) {process(service).reply(text,code);wait(1)}
 function bootstrap(service) {
  reply(service,"Display 1\\nDisplay 2\\nDisplay 1")
  reply(service,"VCP 10 C 20 200")
  reply(service,"10 C 80 100")
  verify(service.available);compare(service.monitors.length,2)
 }
 function test_reads_wait_for_exit_and_decode_protocol() {
  const service=make(),proc=process(service)
  proc.stdout.text="Display 1\\nDisplay 2";proc.stdout.streamFinished()
  compare(proc.starts,1);compare(service.monitors.length,0)
  proc.running=false;proc.exited(0);wait(1)
  compare(proc.command.join(" "),"ddcutil getvcp 10 --display 1 --terse")
  reply(service,"VCP 10 C 20 200");verify(!service.available)
  reply(service,"10 C 80 100")
  compare(service.brightness,0.45);verify(service.available)
 }
 function test_native_maximum_and_latest_target() {
  const service=make();bootstrap(service)
  verify(service.setBrightness(0.5))
  compare(process(service).command[3],"100")
  service.setBrightness(0.2);service.setBrightness(0.8)
  reply(service,"")
  compare(process(service).command[3],"160");compare(process(service).command[5],"1")
  reply(service,"")
  compare(process(service).command[3],"80");compare(process(service).command[5],"2")
  reply(service,"")
  compare(service._active.kind,"read")
  reply(service,"VCP 10 C 160 200")
  compare(service.brightness,0.8,"partial readback does not restore another monitor's stale value")
  reply(service,"VCP 10 C 80 100");compare(service.brightness,0.8)
 }
 function test_stale_read_and_failed_write_readback() {
  const service=make();bootstrap(service)
  service.setBrightness(0.5);reply(service,"");reply(service,"")
  compare(service._active.kind,"read")
  service.setBrightness(0.9)
  reply(service,"VCP 10 C 10 200")
  compare(service.brightness,0.9,"old read cannot overwrite new intent")
  reply(service,"",1);reply(service,"")
  verify(service.errorMessage!=="")
  reply(service,"VCP 10 C 20 200");reply(service,"",1)
  compare(service.monitors[0].current,20)
  compare(service.monitors[1].current,80,"failed readback restores confirmed state")
 }
 function test_invalid_values_and_no_fake_availability() {
  const service=make()
  verify(!service.setBrightness(0.5))
  reply(service,"Display 1\\nDisplay 2")
  reply(service,"VCP 10 C 500 100");reply(service,"VCP 10 NC 2")
  verify(!service.available);compare(service.monitors.length,0)
  const good=make();bootstrap(good)
  const starts=process(good).starts
  verify(!good.setBrightness(NaN));verify(!good.setBrightness(Infinity))
  compare(process(good).starts,starts)
 }
 function test_timeout_kills_then_waits_for_terminal_event() {
  const service=make(),proc=process(service)
  const timer=findChild(service,"brightnessDeadline")
  timer.triggered();compare(proc.kills,1);compare(proc.starts,1)
  verify(service._active!==null)
  reply(service,"Display 1",9)
  verify(service._active===null);verify(!service.available)
 }
 function test_failed_start_deadline_advances_read_queue() {
  const service=make();reply(service,"Display 1\\nDisplay 2")
  const proc=process(service)
  proc.running=false
  findChild(service,"brightnessDeadline").triggered()
  compare(proc.command[4],"2");verify(proc.running)
  reply(service,"VCP 10 C 30 100");verify(service.available);compare(service.monitors.length,1)
 }
}
''')
    result=subprocess.run(['/usr/lib/qt6/bin/qmltestrunner','-input',str(test),'-import',str(imports)],env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software'),capture_output=True,text=True,timeout=15)
    output=result.stdout+result.stderr
    print(output)
    if result.returncode or 'QWARN' in output:
        raise SystemExit(result.returncode or 1)
    if '--native' in sys.argv:
        # The executable is an absolute fixture path, never the system ddcutil.
        fake=directory/'fake-ddcutil'
        state=directory/'levels.json'
        state.write_text(json.dumps({'1':20,'2':80}))
        fake.write_text('#!'+sys.executable+'\n'+"""import json,sys
from pathlib import Path
path=Path(__file__).with_name('levels.json')
levels=json.loads(path.read_text())
args=sys.argv[1:]
if args[0]=='detect':print('Display 1\\nDisplay 2')
else:
 display=args[args.index('--display')+1]
 if args[0]=='getvcp':print('VCP 10 C',levels[display],200 if display=='1' else 100)
 else:levels[display]=int(args[2]);path.write_text(json.dumps(levels))
""")
        fake.chmod(0o755)
        shutil.rmtree(imports/'Quickshell')
        service_path=imports/'qs/src/core/services'
        source=(ROOT/'src/core/services/BrightnessService.qml').read_text().replace('["ddcutil",','['+json.dumps(str(fake))+',')
        (service_path/'BrightnessService.qml').write_text(source)
        with (service_path/'qmldir').open('a') as descriptor:descriptor.write('singleton BrightnessService 1.0 BrightnessService.qml\n')
        probe=imports/'qs/shell.qml'
        probe.write_text("""import QtQuick
import Quickshell
import qs.src.core.services
QtObject {
 id:root
 property int step:0
 property int ticks:0
 property Timer check:Timer {
  interval:20;repeat:true;running:true
  onTriggered: {
   if(++root.ticks>200){console.warn("BRIGHTNESS FAIL timeout");Qt.exit(1);return}
   if(!BrightnessService.available)return
   if(root.step===0){
    if(BrightnessService.monitors.length!==2 || BrightnessService.monitors[0].max!==200){Qt.exit(2);return}
    BrightnessService.setBrightness(0.65);root.step=1
   } else if(!BrightnessService._active && BrightnessService._desired<0){
    if(Math.abs(BrightnessService.brightness-0.65)>0.001){Qt.exit(3);return}
    console.warn("BRIGHTNESS NATIVE PASS");Qt.quit()
   }
  }
 }
}
""")
        native=subprocess.run(['qs','-p',str(probe)],env=dict(os.environ,QT_QPA_PLATFORM='offscreen'),capture_output=True,text=True,timeout=8)
        output=native.stdout+native.stderr
        print(output)
        assert native.returncode==0 and 'BRIGHTNESS NATIVE PASS' in output, output
        assert json.loads(state.read_text())=={'1':130,'2':65}
