#!/usr/bin/env python3
"""Check native PSK dispatch and lifecycle with no NetworkManager connection."""
from pathlib import Path
import os
import shutil
import subprocess
import sys
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
        f'singleton {name} 1.0 {name}.qml\n' for name in ['Networking','DeviceType','WifiSecurityType','ConnectionFailReason','ConnectionState']) + 'WifiNetwork 1.0 WifiNetwork.qml\nWifiDevice 1.0 WifiDevice.qml\n')
    write(module + 'DeviceType.qml', 'pragma Singleton\nimport QtQml\nQtObject {enum Kind {Wifi,Wired}}\n')
    write(module + 'WifiSecurityType.qml', 'pragma Singleton\nimport QtQml\nQtObject {enum Kind {Open,WpaPsk,Wpa2Psk,Sae,StaticWep,Wpa2Eap,Owe} function toString(value){return "Security"}}\n')
    write(module + 'ConnectionFailReason.qml', 'pragma Singleton\nimport QtQml\nQtObject {enum Reason {Unknown,NoSecrets,WifiClientDisconnected,WifiClientFailed,WifiAuthTimeout,WifiNetworkLost} function toString(value){return "Failure"}}\n')
    write(module + 'ConnectionState.qml', 'pragma Singleton\nimport QtQml\nQtObject {enum State {Unknown,Connecting,Connected,Disconnecting,Disconnected}}\n')
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
 property WifiDevice device:null
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
    write(module + 'WifiDevice.qml', """import QtQml
import QtQml.Models
QtObject {
 property string name:"test-wifi"
 property int type:DeviceType.Wifi
 property int state:ConnectionState.Disconnected
 property bool scannerEnabled:false
 property QtObject networks:ListModel {
  property var values:[]
  dynamicRoles:true
  onValuesChanged:{clear();for(const network of values)append({modelData:network})}
 }
}
""")
    service = imports / 'qs/src/core/services'
    service.mkdir(parents=True)
    shutil.copy2(ROOT / 'src/core/services/NetworkService.qml', service)
    write('qs/src/core/services/qmldir', 'module qs.src.core.services\n' + ''.join(
        f'singleton {name} 1.0 {name}.qml\n' for name in ['NetworkService','GlobalStates','ToastService','AppLaunchService']))
    write('qs/src/core/services/GlobalStates.qml', 'pragma Singleton\nimport QtQml\nQtObject {property bool connectionsOpen:true;property string connectionsSection:"wifi"}\n')
    write('qs/src/core/services/ToastService.qml', 'pragma Singleton\nimport QtQml\nQtObject {property int errors:0;function error(message){errors++}}\n')
    write('qs/src/core/services/AppLaunchService.qml', 'pragma Singleton\nimport QtQml\nQtObject {function launchCommand(argv){}}\n')
    (work / 'tst_network.qml').write_text('''import QtQuick
import QtQml.Models
import QtTest
import Quickshell.Networking
import qs.src.core.services
Item {
 id:scene
 WifiDevice {id:device}
 Component {id:deviceComponent;WifiDevice{}}
 Component {id:networkComponent;WifiNetwork{}}
 TestCase {
  name:"NetworkService"
  when:windowShown
  property WifiNetwork network:null
  function init(){
   GlobalStates.connectionsOpen=true;GlobalStates.connectionsSection="wifi";ToastService.errors=0
   Networking.wifiEnabled=true;Networking.wifiHardwareEnabled=true;device.state=ConnectionState.Disconnected
   network=networkComponent.createObject(scene,{device:device})
   device.networks.values=[network];Networking.devices.values=[device]
   NetworkService.stopScan()
   NetworkService.clearError();wait(10)
  }
  function cleanup(){
   device.networks.values=[]
   if(network)network.destroy()
   network=null;wait(10)
   verify(!NetworkService.newConnectionBusy)
   compare(Object.keys(NetworkService._networkIndex).length,0,"watcher index releases removed devices")
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
  function test_failure_waits_for_teardown_before_retry(){
   verify(NetworkService.connectToNewNetwork(network,"wrong-passphrase"))
   network.stateChanging=true
   network.connectionFailed(ConnectionFailReason.NoSecrets);wait(10)
   verify(NetworkService.newConnectionBusy)
   verify(!NetworkService.connectToNewNetwork(network,"correct-passphrase"));compare(network.pskCalls,1)
   network.stateChanging=false;tryVerify(()=>!NetworkService.newConnectionBusy)
   verify(NetworkService.connectToNewNetwork(network,"correct-passphrase"));compare(network.pskCalls,2)
   network.stateChanging=true;network.connected=true
   tryVerify(()=>!NetworkService.newConnectionBusy);compare(NetworkService.errorMessage,"")
  }
  function test_retry_waits_for_native_device_teardown(){
   NetworkService.connectToNewNetwork(network,"wrong-passphrase")
   network.stateChanging=true;device.state=ConnectionState.Connecting
   network.connectionFailed(ConnectionFailReason.NoSecrets)
   network.stateChanging=false;device.state=ConnectionState.Disconnecting
   wait(10);verify(NetworkService.newConnectionBusy)
   device.state=ConnectionState.Disconnected
   tryVerify(()=>!NetworkService.newConnectionBusy)
   verify(NetworkService.connectToNewNetwork(network,"correct-passphrase"));compare(network.pskCalls,2)
  }
  function test_error_while_adapter_unavailable_is_not_revived(){
   device.state=ConnectionState.Unknown
   network.connectionFailed(ConnectionFailReason.WifiNetworkLost)
   device.state=ConnectionState.Disconnected
   wait(10);compare(NetworkService.errorMessage,"")
  }
  function test_retry_resolves_replaced_model_entry(){
   const replacement=networkComponent.createObject(scene,{device:device})
   device.networks.values=[replacement];wait(10)
   verify(NetworkService.connectToNewNetwork(network,"new-passphrase"))
   compare(network.pskCalls,0);compare(replacement.pskCalls,1)
   replacement.stateChanging=true;replacement.connected=true
   tryVerify(()=>!NetworkService.newConnectionBusy)
   device.networks.values=[];replacement.destroy()
  }
  function test_radio_cycle_clears_error_and_recovers_scan(){
   NetworkService.startScan();tryCompare(device,"scannerEnabled",true)
   NetworkService.connectToNewNetwork(network,"wrong-passphrase")
   network.connectionFailed(ConnectionFailReason.WifiNetworkLost)
   tryVerify(()=>NetworkService.errorMessage!=="")
   verify(NetworkService.errorMessage.includes("password") && NetworkService.errorMessage.includes("signal"))
   Networking.wifiEnabled=false;device.state=ConnectionState.Unknown
   compare(NetworkService.errorMessage,"");verify(!NetworkService.newConnectionBusy)
   tryCompare(device,"scannerEnabled",false)
   Networking.wifiEnabled=true;wait(10);verify(!device.scannerEnabled)
   device.state=ConnectionState.Disconnected
   tryCompare(device,"scannerEnabled",true)
  }
  function test_late_failure_cannot_restore_radio_error(){
   NetworkService.connectToNewNetwork(network,"wrong-passphrase")
   network.connectionFailed(ConnectionFailReason.WifiNetworkLost)
   Networking.wifiEnabled=false;Networking.wifiEnabled=true
   wait(10);compare(NetworkService.errorMessage,"")
  }
  function test_scan_survives_adapter_replacement(){
   NetworkService.startScan();tryCompare(device,"scannerEnabled",true)
   const replacement=deviceComponent.createObject(scene)
   Networking.devices.values=[replacement]
   tryCompare(device,"scannerEnabled",false)
   tryCompare(replacement,"scannerEnabled",true)
   Networking.devices.values=[device];tryCompare(device,"scannerEnabled",true)
   replacement.destroy()
  }
  function test_stop_scan_remains_stopped(){
   NetworkService.startScan();tryCompare(device,"scannerEnabled",true)
   NetworkService.stopScan();tryCompare(device,"scannerEnabled",false)
   device.state=ConnectionState.Unknown;device.state=ConnectionState.Disconnected
   wait(10);verify(!device.scannerEnabled)
  }
  function test_selected_target_survives_discovery_deadline(){
   NetworkService.stopScan();tryCompare(device,"scannerEnabled",false)
   device.networks.values=[];wait(10)
   verify(NetworkService.connectToNewNetwork(network,"new-passphrase"))
   compare(network.pskCalls,1);tryCompare(device,"scannerEnabled",true)
   network.connectionFailed(ConnectionFailReason.NoSecrets)
   tryVerify(()=>NetworkService.errorMessage!=="")
  }
  function test_retry_refreshes_expired_scan(){
   NetworkService.stopScan();tryCompare(device,"scannerEnabled",false)
   NetworkService.connectToNewNetwork(network,"new-passphrase")
   tryCompare(device,"scannerEnabled",true)
  }
  function test_native_adapter_unavailable_clears_wait(){
   NetworkService.connectToNewNetwork(network,"wrong-passphrase")
   NetworkService.errorMessage="Previous failure"
   device.state=ConnectionState.Unknown
   verify(!NetworkService.newConnectionBusy);compare(NetworkService.errorMessage,"")
  }
  function test_hardware_block_clears_busy_and_error(){
   NetworkService.connectToNewNetwork(network,"wrong-passphrase")
   NetworkService.errorMessage="Previous failure"
   Networking.wifiHardwareEnabled=false
   verify(!NetworkService.newConnectionBusy);compare(NetworkService.errorMessage,"")
  }
  function test_foreign_failure_does_not_override_current_attempt(){
   const other=networkComponent.createObject(scene,{device:device,name:"Other network"})
   device.networks.values=[network,other];wait(10)
   NetworkService.connectToNewNetwork(network,"new-passphrase")
   other.connectionFailed(ConnectionFailReason.NoSecrets);wait(10)
   compare(NetworkService.errorMessage,"")
   device.networks.values=[network];other.destroy()
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

    if '--native-model' in sys.argv:
        # Load the actual Quickshell model with inert service dependencies.
        # Discovery is never requested and no activation/radio method is called.
        shutil.rmtree(imports / 'Quickshell')
        probe = imports / 'qs/native-network.qml'
        probe.write_text("""import QtQuick
import Quickshell.Networking
import qs.src.core.services
QtObject {
 property int ticks:0
 property Timer deadline:Timer {
  interval:50;repeat:true;running:true
  onTriggered:{
   const device=NetworkService.wifiDevice
   if(!device && ++ticks<20)return
   console.warn("NATIVE NETWORK MODEL PASS adapter="+(device!==null)+" ready="+NetworkService.wifiReady+" networks="+NetworkService.networks.length)
   Qt.quit()
  }
 }
}
""")
        native = subprocess.run(['qs','-p',str(probe)],env=env,capture_output=True,text=True,timeout=10)
        native_output = native.stdout + native.stderr
        print(native_output)
        if native.returncode or 'NATIVE NETWORK MODEL PASS' not in native_output or any(
            marker in native_output for marker in ['TypeError', 'Unable to assign', 'Cannot assign', 'ReferenceError']):
            raise SystemExit(1)
