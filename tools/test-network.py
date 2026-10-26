#!/usr/bin/env python3
"""Check native PSK dispatch and lifecycle with no NetworkManager connection."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='shell-network-test-') as work:
    work = Path(work)
    imports = work / 'imports'
    def write(name, text):
        path = imports / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
    write('Quickshell/qmldir', 'module Quickshell\nSingleton 1.0 Singleton.qml\nScriptModel 1.0 ScriptModel.qml\n')
    write('Quickshell/Singleton.qml', 'import QtQml\nQtObject {default property list<QtObject> children}\n')
    write('Quickshell/ScriptModel.qml', 'import QtQml.Models\nListModel {property var values:[];dynamicRoles:true;onValuesChanged:{clear();for(const entry of values)append({modelData:entry})}}\n')
    module = 'Quickshell/Networking/'
    write(module + 'qmldir', 'module Quickshell.Networking\n' + ''.join(
        f'singleton {name} 1.0 {name}.qml\n' for name in ['Networking','DeviceType','WifiSecurityType','ConnectionFailReason']) + 'WifiNetwork 1.0 WifiNetwork.qml\n')
    write(module + 'DeviceType.qml', 'pragma Singleton\nimport QtQml\nQtObject {enum Kind {Wifi,Wired}}\n')
    write(module + 'WifiSecurityType.qml', 'pragma Singleton\nimport QtQml\nQtObject {enum Kind {Open,WpaPsk,Wpa2Psk,Sae,StaticWep,Wpa2Eap,Owe} function toString(value){return "Security"}}\n')
    write(module + 'ConnectionFailReason.qml', 'pragma Singleton\nimport QtQml\nQtObject {enum Reason {Unknown,NoSecrets} function toString(value){return "Failure"}}\n')
    write(module + 'Networking.qml', '''pragma Singleton
import QtQml
import QtQml.Models
QtObject {
 property bool wifiEnabled:true
 property bool wifiHardwareEnabled:true
 property QtObject devices:ListModel {
  property var values:[]
  dynamicRoles:true
  onValuesChanged:{clear();for(const device of values)append({modelData:device})}
 }
}
''')
    write(module + 'WifiNetwork.qml', '''import QtQml
QtObject {
 property string name:"Test Wi-Fi"
 property int security:WifiSecurityType.Wpa2Psk
 property bool connected:false
 property bool stateChanging:false
 property bool known:false
 property real signalStrength:0.8
 property int pskCalls:0
 property int connectCalls:0
 property int disconnectCalls:0
 property string testPsk:""
 signal connectionFailed(int reason)
 function connectWithPsk(password){pskCalls++;testPsk=password}
 function connect(){connectCalls++}
 function disconnect(){disconnectCalls++}
 function forget(){}
}
''')
    service = imports / 'qs/src/core/services'
    service.mkdir(parents=True)
    shutil.copy2(ROOT / 'src/core/services/NetworkService.qml', service)
    write('qs/src/core/services/qmldir', 'module qs.src.core.services\n' + ''.join(
        f'singleton {name} 1.0 {name}.qml\n' for name in ['NetworkService','GlobalStates','ToastService','AppLaunchService']))
    write('qs/src/core/services/GlobalStates.qml', 'pragma Singleton\nimport QtQml\nQtObject {property bool connectionsOpen:true}\n')
    write('qs/src/core/services/ToastService.qml', 'pragma Singleton\nimport QtQml\nQtObject {property int errors:0;function error(message){errors++}}\n')
    write('qs/src/core/services/AppLaunchService.qml', 'pragma Singleton\nimport QtQml\nQtObject {function launchCommand(argv){}}\n')
    (work / 'tst_network.qml').write_text('''import QtQuick
import QtQml.Models
import QtTest
import Quickshell.Networking
import qs.src.core.services
Item {
 id:scene
 QtObject {
  id:device
  property int type:DeviceType.Wifi
  property bool scannerEnabled:false
  property QtObject networks:ListModel {
   property var values:[]
   dynamicRoles:true
   onValuesChanged:{clear();for(const network of values)append({modelData:network})}
  }
 }
 Component {id:networkComponent;WifiNetwork{}}
 TestCase {
  name:"NetworkService"
  when:windowShown
  property WifiNetwork network:null
  function init(){
   GlobalStates.connectionsOpen=true;ToastService.errors=0
   network=networkComponent.createObject(scene)
   device.networks.values=[network];Networking.devices.values=[device]
   NetworkService.clearError();wait(10)
  }
  function cleanup(){
   device.networks.values=[]
   if(network)network.destroy()
   network=null;wait(10)
   verify(!NetworkService.newConnectionBusy)
  }
  function test_native_psk_data(){return [{tag:"wpa",security:WifiSecurityType.WpaPsk},{tag:"wpa2",security:WifiSecurityType.Wpa2Psk},{tag:"sae",security:WifiSecurityType.Sae}]}
  function test_native_psk(data){
   network.security=data.security
   NetworkService.connectToNewNetwork(network,"test-passphrase")
   compare(network.pskCalls,1);compare(network.testPsk,"test-passphrase")
   verify(NetworkService.newConnectionBusy)
   NetworkService.connectToNewNetwork(network,"second-passphrase");compare(network.pskCalls,1)
   network.stateChanging=true;network.connected=true
   tryVerify(()=>!NetworkService.newConnectionBusy)
  }
  function test_reject_invalid_targets(){
   NetworkService.connectToNewNetwork(null,"secret")
   NetworkService.connectToNewNetwork(network,"");compare(network.pskCalls,0)
   network.connected=true;NetworkService.connectToNewNetwork(network,"secret");compare(network.pskCalls,0)
   network.connected=false;network.stateChanging=true;NetworkService.connectToNewNetwork(network,"secret");compare(network.pskCalls,0)
   network.stateChanging=false
   for(const security of [WifiSecurityType.StaticWep,WifiSecurityType.Wpa2Eap,WifiSecurityType.Open,WifiSecurityType.Owe]){
    network.security=security;NetworkService.connectToNewNetwork(network,"secret");compare(network.pskCalls,0)
   }
   verify(!NetworkService.newConnectionBusy)
  }
  function test_no_secrets_releases_busy_and_reports(){
   NetworkService.connectToNewNetwork(network,"test-passphrase")
   network.connectionFailed(ConnectionFailReason.NoSecrets)
   tryVerify(()=>!NetworkService.newConnectionBusy)
   verify(NetworkService.errorMessage.length>0)
   NetworkService.connectToNewNetwork(network,"retry-passphrase");compare(network.pskCalls,2)
  }
  function test_failed_activation_releases_busy(){
   NetworkService.connectToNewNetwork(network,"test-passphrase")
   network.stateChanging=true;network.stateChanging=false
   tryVerify(()=>!NetworkService.newConnectionBusy)
  }
  function test_device_disappears(){
   NetworkService.connectToNewNetwork(network,"test-passphrase")
   device.networks.values=[];network.destroy();network=null
   tryVerify(()=>!NetworkService.newConnectionBusy)
  }
  function test_panel_close_keeps_connection_attempt(){
   NetworkService.connectToNewNetwork(network,"test-passphrase")
   GlobalStates.connectionsOpen=false
   verify(NetworkService.newConnectionBusy)
   network.stateChanging=true;network.connected=true
   tryVerify(()=>!NetworkService.newConnectionBusy)
  }
  function test_known_network_stays_native(){
   network.known=true;NetworkService.connectToNetwork(network)
   compare(network.connectCalls,1);compare(network.pskCalls,0)
  }
 }
}
''')
    env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software', QT_ASSUME_STDERR_HAS_CONSOLE='1')
    result = subprocess.run(['/usr/lib/qt6/bin/qmltestrunner', '-input', str(work), '-import', str(imports)],
                            env=env, capture_output=True, text=True, timeout=30)
    output = result.stdout + result.stderr
    print(output)
    if result.returncode or 'QWARN' in output:
        raise SystemExit(1)
