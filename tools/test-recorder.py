#!/usr/bin/env python3
"""Recording control recovery against inert processes and in-memory FileViews."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='shell-recorder-') as directory:
    directory=Path(directory);imports=directory/'imports'
    def write(name,text):
        path=imports/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_text(text)
    write('Quickshell/qmldir','module Quickshell\nSingleton 1.0 Singleton.qml\nsingleton Quickshell 1.0 Quickshell.qml\n')
    write('Quickshell/Singleton.qml','import QtQml\nQtObject {default property list<QtObject> children}\n')
    write('Quickshell/Quickshell.qml','pragma Singleton\nimport QtQml\nQtObject {function env(name) {return "/tmp/test-only"}}\n')
    write('Quickshell/Io/qmldir','module Quickshell.Io\n'+''.join(f'{name} 1.0 {name}.qml\n' for name in ['Process','FileView','FileViewError','StdioCollector','IpcHandler']))
    write('Quickshell/Io/Process.qml','import QtQml\nQtObject {property bool running:false;property var command:[];property QtObject stdout:null;signal exited(int exitCode);function finish(code) {running=false;exited(code)}}\n')
    write('Quickshell/Io/FileView.qml','import QtQml\nQtObject {property string path:"";property bool printErrors:false;signal loaded();signal loadFailed(int error);function reload() {} function text() {return ""}}\n')
    write('Quickshell/Io/FileViewError.qml','import QtQml\nQtObject {enum Kind {NotAFile}}\n')
    write('Quickshell/Io/StdioCollector.qml','import QtQml\nQtObject {property string text:"";signal streamFinished()}\n')
    write('Quickshell/Io/IpcHandler.qml','import QtQml\nQtObject {property string target:""}\n')
    write('Quickshell/Hyprland/qmldir','module Quickshell.Hyprland\nsingleton Hyprland 1.0 Hyprland.qml\nGlobalShortcut 1.0 GlobalShortcut.qml\n')
    write('Quickshell/Hyprland/Hyprland.qml','pragma Singleton\nimport QtQml\nQtObject {signal rawEvent(var event)}\n')
    write('Quickshell/Hyprland/GlobalShortcut.qml','import QtQml\nQtObject {property string name:"";property string description:"";signal pressed()}\n')
    write('qs/src/core/config/qmldir','module qs.src.core.config\nsingleton AppConfig 1.0 AppConfig.qml\n')
    write('qs/src/core/config/AppConfig.qml','''pragma Singleton
import QtQml
QtObject {
 property string recorderSocket:"";property string recorderTarget:"portal";property string recorderDirectory:""
 property string recorderContainer:"mp4";property int recorderFps:60;property string recorderFramerateMode:"vfr"
 property string recorderCodec:"auto";property string recorderQuality:"high";property bool recorderCursor:true
 property bool recorderRestorePortal:true;property var recorderAudioSources:[]
}
''')
    write('qs/src/core/services/qmldir','module qs.src.core.services\nsingleton ToastService 1.0 ToastService.qml\n')
    write('qs/src/core/services/ToastService.qml','pragma Singleton\nimport QtQml\nQtObject {function error(value) {} function warning(value) {} function success(value) {}}\n')
    source=(ROOT/'src/core/services/RecorderService.qml').read_text().replace('pragma Singleton\n','',1).replace('import qs.src.core.config','import qs.src.core.config\nimport qs.src.core.services')
    (directory/'TestRecorder.qml').write_text(source)
    (directory/'tst_recorder.qml').write_text('''import QtQuick
import QtTest
import qs.src.core.config
TestCase {
 id:tests;name:"RecorderRecovery";when:windowShown
 Component {id:fixture;TestRecorder {}}
 function make() {
  AppConfig.recorderTarget="portal"
  const service=createTemporaryObject(fixture,tests)
  findChild(service,"recorderDetect").finish(0)
  return service
 }
 function test_pause_waits_for_confirmation_and_retries() {
  const service=make();service._pid=42
  const process=findChild(service,"recorderControl")
  verify(service.setPaused(true));verify(!service.paused)
  verify(!service.setPaused(true),"in-flight control cannot be duplicated")
  process.finish(1);verify(!service.paused);verify(service.canRetry)
  const error=service.errorMessage;verify(service.retry());compare(service.errorMessage,error)
  process.finish(0);verify(service.paused);compare(service.errorMessage,"")
 }
 function test_late_reply_cannot_change_another_recording() {
  const service=make();service._pid=42
  verify(service.setPaused(true));service._pid=0;service._pid=42
  findChild(service,"recorderControl").finish(0);verify(!service.paused)
  verify(service.stop());findChild(service,"recorderControl").finish(1)
  verify(service.canRetry);service._pid=0;verify(!service.canRetry);compare(service.errorMessage,"")
 }
 function test_start_failure_keeps_picker_intent() {
  const service=make();service.start(true)
  const process=findChild(service,"recorderStart")
  verify(process.running);process.finish(1)
  verify(service.errorMessage!=="");verify(service.retry())
  compare(process.command[process.command.indexOf("-restore-portal-session")+1],"no")
  service._socketPresent=true;service._pid=42;service._awaitingOutput=false
  compare(service.errorMessage,"")
 }
 function test_invalid_config_is_never_executed() {
  const service=make();AppConfig.recorderTarget="bad; target"
  service.start(false);verify(!findChild(service,"recorderStart").running)
  verify(service.errorMessage.includes("config.json"))
  AppConfig.recorderTarget="portal";verify(service.retry());verify(findChild(service,"recorderStart").running)
 }
}
''')
    result=subprocess.run(['/usr/lib/qt6/bin/qmltestrunner','-input',str(directory/'tst_recorder.qml'),'-import',str(imports)],
        env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software'),capture_output=True,text=True,timeout=20)
    output=result.stdout+result.stderr;print(output)
    raise SystemExit(result.returncode or int(any(marker in output for marker in ['QWARN','ReferenceError','TypeError','Unable to assign'])))
