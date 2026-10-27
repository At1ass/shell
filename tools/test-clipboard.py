#!/usr/bin/env python3
"""Clipboard passive-work lifecycle with fake processes; no real clipboard access."""
from pathlib import Path
import os
import sys
import json
import shutil
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='shell-clipboard-test-') as directory:
    directory=Path(directory);imports=directory/'imports'
    def write(name,text):
        path=imports/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_text(text)
    write('Quickshell/qmldir','module Quickshell\nSingleton 1.0 Singleton.qml\nsingleton Quickshell 1.0 Quickshell.qml\n')
    write('Quickshell/Singleton.qml','import QtQml\nQtObject {default property list<QtObject> children}\n')
    write('Quickshell/Quickshell.qml','pragma Singleton\nimport QtQml\nQtObject {signal clipboardTextChanged();function env(name){return "/tmp/clipboard-fixture-never-created"}}\n')
    write('Quickshell/Io/qmldir','module Quickshell.Io\nProcess 1.0 Process.qml\nSplitParser 1.0 SplitParser.qml\n')
    write('Quickshell/Io/Process.qml','''import QtQml
QtObject {
 property bool running:false
 property var command:[]
 property QtObject stdout:null
 property bool stdinEnabled:true
 property int starts:0
 property int kills:0
 signal started()
 signal exited(int code,int status)
 onRunningChanged:if(running){starts++;started()}
 function write(data){}
 function signal(number){if(number===9)kills++}
 function finish(code){running=false;exited(code,0)}
}
''')
    write('Quickshell/Io/SplitParser.qml','import QtQml\nQtObject {signal read(string line)}\n')
    write('FuzzySearch/qmldir','module FuzzySearch\nsingleton FuzzySearch 1.0 FuzzySearch.qml\n')
    write('FuzzySearch/FuzzySearch.qml','pragma Singleton\nimport QtQml\nQtObject {function match(query,values,limit,threshold){return []}}\n')
    write('qs/src/core/services/qmldir','module qs.src.core.services\nsingleton GlobalStates 1.0 GlobalStates.qml\nsingleton ToastService 1.0 ToastService.qml\n')
    write('qs/src/core/services/GlobalStates.qml','pragma Singleton\nimport QtQml\nQtObject {property bool launcherOpen:false}\n')
    write('qs/src/core/services/ToastService.qml','pragma Singleton\nimport QtQml\nQtObject {function error(message){}}\n')
    source=(ROOT/'src/core/services/ClipboardService.qml').read_text().replace('pragma Singleton\n','',1).replace('import FuzzySearch','import FuzzySearch\nimport qs.src.core.services')
    (directory/'TestClipboard.qml').write_text(source)
    test=directory/'tst_clipboard.qml'
    test.write_text('''import QtQuick
import QtTest
import qs.src.core.services
TestCase {
 id:tests;name:"ClipboardLifecycle";when:windowShown
 Component{id:fixture;TestClipboard{}}
 function make(){GlobalStates.launcherOpen=false;const service=createTemporaryObject(fixture,tests);return service}
 function proc(service){return findChild(service,"clipboardHistoryRead")}
 function test_closed_refresh_and_thumbnail_setup_stay_idle(){
  const service=make()
  service.refresh();service.requestThumbnail("1\\t[[binary data 10x10]]")
  compare(proc(service).starts,0)
  compare(findChild(service,"clipboardThumbnailInit").starts,0)
 }
 function test_close_cancels_and_discards_late_history(){
  const service=make();service.entries=["old"]
  GlobalStates.launcherOpen=true
  proc(service).stdout.read("1\\tfirst")
  GlobalStates.launcherOpen=false
  compare(proc(service).kills,1)
  proc(service).stdout.read("2\\tlate")
  proc(service).finish(0);wait(1)
  compare(service.entries.join("|"),"old");verify(!service._readBusy)
 }
 function test_reopen_waits_for_terminal_and_restarts_once(){
  const service=make();GlobalStates.launcherOpen=true
  GlobalStates.launcherOpen=false;GlobalStates.launcherOpen=true
  compare(proc(service).starts,1)
  proc(service).finish(9);wait(1)
  compare(proc(service).starts,2)
  proc(service).stdout.read("3\\tnew")
  proc(service).finish(0);wait(1)
  compare(service.entries[0],"3\\tnew")
 }
 function test_refreshes_coalesce_and_publish_after_exit(){
  const service=make();GlobalStates.launcherOpen=true
  service.refresh();service.refresh();compare(proc(service).starts,1)
  proc(service).stdout.read("1\\tfirst");compare(service.entries.length,0)
  proc(service).finish(0);wait(1);compare(proc(service).starts,2)
  compare(service.entries.length,0,"superseded snapshot is not published")
  proc(service).stdout.read("2\\tnewest");proc(service).finish(0);wait(1)
  compare(service.entries[0],"2\\tnewest");compare(proc(service).starts,2)
 }
 function test_timeout_invalidates_snapshot_and_releases_after_exit(){
  const service=make();service.entries=["old"];GlobalStates.launcherOpen=true
  ignoreWarning("Clipboard history read timed out")
  findChild(service,"clipboardHistoryDeadline").triggered();compare(proc(service).kills,1)
  verify(service._readBusy);proc(service).finish(0);wait(1)
  verify(!service._readBusy);compare(service.entries[0],"old")
  service.refresh();compare(proc(service).starts,2)
 }
 function test_copy_survives_launcher_close(){
  const service=make();GlobalStates.launcherOpen=true
  service.copy("1\\tselected")
  const copy=findChild(service,"clipboardCopy")
  verify(copy.running)
  GlobalStates.launcherOpen=false
  verify(copy.running);compare(copy.kills,0)
 }
 function test_thumbnail_init_is_lazy_and_failure_does_not_spin(){
  const service=make();GlobalStates.launcherOpen=true
  const init=findChild(service,"clipboardThumbnailInit")
  compare(init.starts,0)
  service.requestThumbnail("1\\t[[binary data 10x10]]");compare(init.starts,1)
  init.finish(1);wait(1)
  verify(service._thumbnailDirFailed);compare(service._thumbQueue.length,0)
  service.requestThumbnail("2\\t[[binary data 10x10]]");compare(init.starts,1)
 }
}
''')
    result=subprocess.run(['/usr/lib/qt6/bin/qmltestrunner','-input',str(test),'-import',str(imports)],env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software'),capture_output=True,text=True,timeout=15)
    print(result.stdout+result.stderr)
    if result.returncode:
        raise SystemExit(result.returncode)
    if '--native' in sys.argv:
        fake=directory/'fake-cliphist'
        fake.write_text('#!'+sys.executable+'\n'+"""import sys,time
assert sys.argv[1:]==['list']
print('1\\tfirst',flush=True)
time.sleep(0.2)
print('2\\tsecond',flush=True)
""")
        fake.chmod(0o755)
        shutil.rmtree(imports/'Quickshell')
        tree=imports/'qs'
        source=(ROOT/'src/core/services/ClipboardService.qml').read_text().replace('pragma Singleton\n','',1).replace('import FuzzySearch','import FuzzySearch\nimport qs.src.core.services')
        source=source.replace('Singleton {','Item {',1).replace('    id: root','    id: root\n    property alias testRead: readProc\n    property alias testThumbnailInit: thumbDirInitProc',1)
        source=source.replace('property string cliphistBinary: "cliphist"','property string cliphistBinary: '+json.dumps(str(fake)))
        (tree/'TestNative.qml').write_text(source)
        probe=tree/'shell.qml'
        probe.write_text("""import QtQuick
import Quickshell
import qs.src.core.services
QtObject {
 id:root
 property QtObject controller:TestNative {id:service}
 property int step:0
 property int starts:0
 property int ticks:0
 property Connections observed:Connections {
  target:service.testRead
  function onStarted(){root.starts++}
 }
 property Connections snapshots:Connections {
  target:service
  function onEntriesChanged(){
   if(root.step===1 && service.entries.length!==2){console.warn("CLIPBOARD FAIL stale snapshot");Qt.exit(2)}
  }
 }
 Component.onCompleted:Qt.callLater(function(){service.entries=["old"];GlobalStates.launcherOpen=true})
 property Timer check:Timer {
  interval:10;repeat:true;running:true
  onTriggered:{
   if(++root.ticks>300){console.warn("CLIPBOARD FAIL timeout");Qt.exit(1);return}
   if(root.step===0){
    if(service.testRead.buffer.length!==1)return
    GlobalStates.launcherOpen=false;GlobalStates.launcherOpen=true
    if(root.starts!==1){Qt.exit(3);return}
    root.step=1
   } else if(!service._readBusy && root.starts===2){
    if(service.entries.length!==2 || service.entries[1]!=="2\\tsecond"){Qt.exit(4);return}
    if(service.testThumbnailInit.running){Qt.exit(5);return}
    console.warn("CLIPBOARD NATIVE PASS");Qt.quit()
   }
  }
 }
}
""")
        native=subprocess.run(['qs','-p',str(probe)],env=dict(os.environ,QT_QPA_PLATFORM='offscreen'),capture_output=True,text=True,timeout=8)
        output=native.stdout+native.stderr;print("Native exit:", native.returncode);print(output)
        assert native.returncode==0 and 'CLIPBOARD NATIVE PASS' in output, output
