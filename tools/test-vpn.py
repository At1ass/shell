#!/usr/bin/env python3
"""Exercise UUID action routing with fake NM metadata and a non-spawning Process."""
from pathlib import Path
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='shell-vpn-') as directory:
    directory = Path(directory)
    imports = directory / 'imports'
    def write(name, text):
        path = imports / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
    write('Quickshell/qmldir', 'module Quickshell\nSingleton 1.0 Singleton.qml\n')
    write('Quickshell/Singleton.qml', 'import QtQml\nQtObject {default property list<QtObject> children}\n')
    write('Quickshell/Io/qmldir', 'module Quickshell.Io\nProcess 1.0 Process.qml\nIpcHandler 1.0 IpcHandler.qml\n')
    write('Quickshell/Io/IpcHandler.qml', 'import QtQml\nQtObject {property string target:""}\n')
    write('Quickshell/Io/Process.qml', 'import QtQml\nQtObject {property bool running:false;property var command:[];signal exited(int code)}\n')
    write('qs/src/core/config/qmldir', 'module qs.src.core.config\nsingleton AppConfig 1.0 AppConfig.qml\n')
    write('qs/src/core/config/AppConfig.qml', 'pragma Singleton\nimport QtQml\nQtObject {property bool ready:true;property bool vpnEnabled:true;property int networkAuthenticationTimeout:120}\n')
    services = 'qs/src/core/services/'
    write(services+'qmldir', 'module qs.src.core.services\n' + ''.join(
        f'singleton {name} 1.0 {name}.qml\n' for name in ['VPNService','GlobalStates','ToastService','AppLaunchService']))
    shutil.copy2(ROOT/'src/core/services/VPNService.qml', imports/services/'VPNService.qml')
    write(services+'GlobalStates.qml', 'pragma Singleton\nimport QtQml\nQtObject {property bool connectionsOpen:true;property string opened:"";function openConnections(section,source) {opened=section;connectionsOpen=true}}\n')
    write(services+'ToastService.qml', 'pragma Singleton\nimport QtQml\nQtObject {property int failures:0;property int successes:0;function info(message){} function error(message){failures++} function success(message){successes++}}\n')
    write(services+'AppLaunchService.qml', 'pragma Singleton\nimport QtQml\nQtObject {function launchCommand(args){}}\n')
    write(services+'connectivity/NativeVpnProfiles.qml', '''import QtQml
QtObject {
 objectName:"fakeVpnProfiles"
 property bool ready:true
 property string errorString:""
 property var profiles:[]
 readonly property var names:profiles.map(profile=>profile.name)
 readonly property var activeUuids:profiles.filter(profile=>profile.connected).map(profile=>profile.uuid)
 readonly property string activeNames:profiles.filter(profile=>profile.connected).map(profile=>profile.name).join(", ")
 property int refreshes:0
 function refresh() {refreshes++}
 function profile(uuid) {return profiles.find(profile=>profile.uuid.toLowerCase()===uuid.toLowerCase()) ?? ({})}
}
''')
    test = directory/'tst_vpn.qml'
    test.write_text('''import QtQuick
import QtTest
import qs.src.core.config
import qs.src.core.services
TestCase {
 name:"VpnActions";when:windowShown
 property string first:"3630bbf6-a548-41de-9f58-07eafde18739"
 property string second:"4630bbf6-a548-41de-9f58-07eafde18739"
 property QtObject model:null
 property QtObject process:null
 function init() {
  AppConfig.vpnEnabled=true;VPNService.init()
  tryVerify(()=>findChild(VPNService,"fakeVpnProfiles")!==null)
  model=findChild(VPNService,"fakeVpnProfiles");model.refreshes=0;process=findChild(VPNService,"vpnOperation")
  verify(process!==null)
  if(process.running) {process.running=false;process.exited(0)}
  VPNService.clearError();GlobalStates.connectionsOpen=true;GlobalStates.opened=""
  ToastService.failures=0;ToastService.successes=0
  model.profiles=[{uuid:first,name:"Duplicate: name",connected:false,busy:false,state:0},{uuid:second,name:"Duplicate: name",connected:false,busy:false,state:0}]
 }
 function finish(code) {process.running=false;process.exited(code)}
 function test_no_primary_name_required() {
  VPNService.toggle();compare(GlobalStates.opened,"vpn");verify(!process.running)
  verify(VPNService.connect(second));compare(process.command.join("|"),"nmcli|--wait|150|connection|up|uuid|"+second)
  verify(!VPNService.connect(first));compare(VPNService.busyVPN,second)
  finish(0);verify(!VPNService.busy);compare(model.refreshes,1)
 }
 function test_unknown_uuid_and_busy_profile_rejected() {
  verify(!VPNService.connect("profile name"))
  verify(!VPNService.connect("5630bbf6-a548-41de-9f58-07eafde18739"))
  model.profiles=[{uuid:first,name:"Busy",connected:false,busy:true,state:1}]
  verify(!VPNService.connect(first));verify(!process.running)
 }
 function test_multiple_active_and_named_disconnect() {
  model.profiles=[{uuid:first,name:"First",connected:true,busy:false,state:2},{uuid:second,name:"Second",connected:true,busy:false,state:2}]
  tryCompare(VPNService.activeUuids,"length",2);verify(VPNService.connected)
  verify(!VPNService.connect(first));verify(VPNService.disconnect(second))
  compare(process.command[4],"down");compare(process.command[6],second)
  finish(0)
 }
 function test_failure_does_not_remove_profiles() {
  verify(VPNService.connect(first));finish(3)
  verify(!VPNService.busy);verify(VPNService.errorMessage.includes("timed out"))
  compare(VPNService.profiles.length,2)
  verify(VPNService.connect(second));verify(VPNService.errorMessage!=="","failure remains visible during the next operation");finish(10)
  verify(VPNService.errorMessage.includes("no longer available"))
 }
 function test_error_survives_reopen_and_retry() {
  GlobalStates.connectionsOpen=false;verify(VPNService.connect(second));finish(3)
  compare(ToastService.failures,1);verify(VPNService.canRetry)
  const message=VPNService.errorMessage
  GlobalStates.connectionsOpen=true;compare(VPNService.errorMessage,message)
  verify(VPNService.retry());compare(process.command[6],second)
  verify(!VPNService.retry(),"duplicate retry is blocked")
  compare(VPNService.errorMessage,message);finish(0)
  compare(VPNService.errorMessage,"");verify(!VPNService.canRetry)
 }
 function test_retry_revalidates_deleted_profile_and_disconnect() {
  verify(VPNService.connect(first));finish(4)
  model.profiles=[];verify(!VPNService.canRetry);verify(!VPNService.retry())
  verify(VPNService.retryUnavailableReason.includes("Profile no longer available"))
  model.profiles=[{uuid:second,name:"Second",connected:true,busy:false,state:2}]
  verify(VPNService.disconnect(second));finish(4);verify(VPNService.canRetry)
  verify(VPNService.retry());compare(process.command[4],"down");finish(4)
  model.profiles=[{uuid:second,name:"Second",connected:false,busy:false,state:0}]
  compare(VPNService.errorMessage,"","observed completion clears obsolete failure")
 }
 function test_disabled_snapshot_and_late_result() {
  GlobalStates.connectionsOpen=false
  verify(VPNService.connect(first));AppConfig.vpnEnabled=false
  tryCompare(VPNService.profiles,"length",0)
  verify(!VPNService.connect(second));finish(4)
  compare(ToastService.failures,0);verify(!VPNService.busy)
 }
}
''')
    result = subprocess.run(['/usr/lib/qt6/bin/qmltestrunner','-input',str(test),'-import',str(imports)],
                            env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software'),capture_output=True,text=True,timeout=30)
    output=result.stdout+result.stderr
    print(output)
    failure=result.returncode or int(any(marker in output for marker in ['QWARN','ReferenceError','TypeError','Unable to assign']))
    if failure: raise SystemExit(failure)

if '--native' not in sys.argv:
    raise SystemExit(0)

# This native class has no activation methods and never requests GetSecrets.
with tempfile.TemporaryDirectory(prefix='shell-vpn-native-') as directory:
    directory=Path(directory)
    (directory/'shell.qml').write_text('''import QtQuick
import QtQml.Models
import Quickshell
import Connectivity 1.0
Scope {
 id:root
 VpnProfiles {id:profiles;enabled:true}
 Instantiator {
  id:rows
  model:ScriptModel {values:Array.from(profiles.profiles);objectProp:"uuid"}
  delegate:QtObject {required property var modelData;property string uuid:modelData.uuid;property string name:modelData.name}
 }
 Connections {target:profiles;function onChanged() {Qt.callLater(root.check)}}
 Timer {interval:8000;running:true;onTriggered:{console.warn("VPN NATIVE FAIL: timeout");Qt.exit(1)}}
 function check() {
  if(!profiles.ready)return
  if(profiles.errorString || rows.count!==profiles.profiles.length) {console.warn("VPN NATIVE FAIL: metadata/model bridge");Qt.exit(1);return}
  for(const profile of profiles.profiles)if(!profile.uuid || !profile.name) {console.warn("VPN NATIVE FAIL: incomplete profile");Qt.exit(1);return}
  console.warn("VPN NATIVE PASS: profiles="+rows.count);Qt.quit()
 }
}
''')
    result=subprocess.run(['qs','-p',str(directory)],env=os.environ.copy(),capture_output=True,text=True,timeout=12)
    output=result.stdout+result.stderr
    print(output)
    raise SystemExit(result.returncode or int('VPN NATIVE PASS' not in output or any(marker in output for marker in ['VPN NATIVE FAIL','ReferenceError','TypeError','Unable to assign'])))
