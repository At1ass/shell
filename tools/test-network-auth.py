#!/usr/bin/env python3
"""Check prompt routing on isolated QML services; never contacts NetworkManager."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='shell-network-auth-') as directory:
    directory = Path(directory)
    imports = directory / 'imports'
    def write(name, value):
        path = imports / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(value)
    write('Quickshell/qmldir', 'module Quickshell\nSingleton 1.0 Singleton.qml\n')
    write('Quickshell/Singleton.qml', 'import QtQml\nQtObject {default property list<QtObject> children}\n')
    write('Quickshell/Io/qmldir', 'module Quickshell.Io\nIpcHandler 1.0 IpcHandler.qml\n')
    write('Quickshell/Io/IpcHandler.qml', 'import QtQml\nQtObject {property string target:""}\n')
    write('Connectivity/qmldir', 'module Connectivity\nNetworkSecretAgent 1.0 NetworkSecretAgent.qml\n')
    write('Connectivity/NetworkSecretAgent.qml', '''import QtQuick
QtObject {
 property bool enabled:false
 property bool blocked:true
 property int timeoutMs:0
 readonly property bool registered:enabled
 property bool busy:false
 property string requestToken:""
 property string connectionName:""
 property string message:""
 property string validationError:""
 property string section:"wifi"
 property bool requestNew:false
 property var fields:[]
 property string errorString:""
 property int cancellations:0
 function prompt(token,kind) {section=kind;busy=true;fields=[{key:"password",label:"Password",secret:true}];connectionName="Test";requestToken=token}
 function submit(token,answers) {if(token!==requestToken)return false;requestToken="";return true}
 function reject(token) {if(token!==requestToken)return false;cancel();return true}
 function cancel() {cancellations++;requestToken="";busy=false}
 onBlockedChanged: if(blocked) cancel()
}
''')
    write('qs/src/core/config/qmldir', 'module qs.src.core.config\nsingleton AppConfig 1.0 AppConfig.qml\n')
    write('qs/src/core/config/AppConfig.qml', '''pragma Singleton
import QtQml
QtObject {
 property bool ready:true
 property bool networkAgentEnabled:true
 property int networkAuthenticationTimeout:120
 function moduleEnabled(name) {return true}
}
''')
    module = 'qs/src/core/services/'
    write(module + 'qmldir', 'module qs.src.core.services\n' + ''.join(
        f'singleton {name} 1.0 {name}.qml\n' for name in ['NetworkAuthService','GlobalStates','SessionMonitor','ToastService']))
    write(module + 'GlobalStates.qml', '''pragma Singleton
import QtQml
QtObject {
 property string activePanel:""
 readonly property bool connectionsOpen:activePanel==="connections"
 property string connectionsSection:""
 property bool lockscreenActive:false
 function openConnections(section,source) {connectionsSection=section;activePanel="connections"}
 function closePanel(name) {if(activePanel===name)activePanel=""}
}
''')
    write(module + 'SessionMonitor.qml', 'pragma Singleton\nimport QtQml\nQtObject {signal resumed()}\n')
    write(module + 'ToastService.qml', 'pragma Singleton\nimport QtQml\nQtObject {property int errors:0;function error(message) {errors++}}\n')
    for name in ['NetworkAuthService.qml','connectivity/NativeNetworkAgent.qml']:
        target = imports / module / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / 'src/core/services' / name, target)
    test = directory / 'tst_auth.qml'
    test.write_text('''import QtQuick
import QtTest
import qs.src.core.config
import qs.src.core.services
TestCase {
 name:"NetworkAuthLifecycle"
 when:windowShown
 function init() {
  AppConfig.networkAgentEnabled=true;NetworkAuthService.init()
  tryVerify(()=>NetworkAuthService.agent!==null)
  NetworkAuthService.cancel();GlobalStates.lockscreenActive=false
  GlobalStates.activePanel="";GlobalStates.connectionsSection=""
  wait(1)
 }
 function test_prompt_routes_after_bindings_settle() {
  NetworkAuthService.agent.prompt("vpn","vpn")
  tryCompare(GlobalStates,"activePanel","connections")
  compare(GlobalStates.connectionsSection,"vpn")
  compare(NetworkAuthService.requestToken,"vpn")
  compare(NetworkAuthService.agent.timeoutMs,120000)
 }
 function test_cancel_on_panel_close_and_section_change() {
  NetworkAuthService.agent.prompt("one","wifi")
  tryCompare(GlobalStates,"activePanel","connections")
  GlobalStates.activePanel="dashboard"
  tryCompare(NetworkAuthService,"requestToken","")
  compare(GlobalStates.activePanel,"dashboard")
  NetworkAuthService.agent.prompt("two","vpn")
  tryCompare(GlobalStates,"activePanel","connections")
  GlobalStates.connectionsSection="bluetooth"
  tryCompare(NetworkAuthService,"requestToken","")
 }
 function test_waits_for_storage_and_preserves_existing_panel() {
  NetworkAuthService.agent.prompt("one","wifi")
  tryCompare(GlobalStates,"activePanel","connections")
  verify(NetworkAuthService.submit("one",{password:"test-only"}))
  wait(1);compare(GlobalStates.activePanel,"connections")
  NetworkAuthService.agent.busy=false
  tryCompare(GlobalStates,"activePanel","")
  GlobalStates.activePanel="connections"
  NetworkAuthService.agent.prompt("two","vpn")
  tryCompare(GlobalStates,"connectionsSection","vpn")
  NetworkAuthService.reject("two");wait(1)
  compare(GlobalStates.activePanel,"connections")
 }
 function test_lock_resume_and_disable() {
  NetworkAuthService.agent.prompt("one","wifi")
  tryCompare(GlobalStates,"activePanel","connections")
  GlobalStates.lockscreenActive=true
  tryCompare(NetworkAuthService,"requestToken","")
  verify(NetworkAuthService.registered)
  GlobalStates.lockscreenActive=false
  NetworkAuthService.agent.prompt("two","wifi")
  SessionMonitor.resumed();tryCompare(NetworkAuthService,"requestToken","")
  AppConfig.networkAgentEnabled=false
  tryCompare(NetworkAuthService,"agent",null)
 }
}
''')
    env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software')
    result = subprocess.run(['/usr/lib/qt6/bin/qmltestrunner', '-input', str(test), '-import', str(imports)],
                            env=env, capture_output=True, text=True, timeout=30)
    output = result.stdout + result.stderr
    print(output)
    raise SystemExit(result.returncode or int(any(value in output for value in ['QWARN', 'ReferenceError', 'TypeError', 'Unable to assign'])))
