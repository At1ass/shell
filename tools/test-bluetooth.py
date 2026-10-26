#!/usr/bin/env python3
"""Exercise the real Bluetooth service with isolated QML transports, without BlueZ."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='shell-bluetooth-test-') as work:
    work = Path(work)
    imports = work / 'imports'
    def write(name, text):
        path = imports / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
    write('Quickshell/qmldir', 'module Quickshell\nSingleton 1.0 Singleton.qml\n')
    write('Quickshell/Singleton.qml', 'import QtQml\nQtObject {default property list<QtObject> children}\n')
    write('Quickshell/Bluetooth/qmldir', 'module Quickshell.Bluetooth\nsingleton Bluetooth 1.0 Bluetooth.qml\nBluetoothAdapter 1.0 BluetoothAdapter.qml\nBluetoothDevice 1.0 BluetoothDevice.qml\n')
    write('Quickshell/Bluetooth/Bluetooth.qml', 'pragma Singleton\nimport QtQml\nQtObject {property BluetoothAdapter defaultAdapter: BluetoothAdapter {}}\n')
    write('Quickshell/Bluetooth/BluetoothAdapter.qml', '''import QtQml
import QtQml.Models
QtObject {
 property bool enabled:true
 property bool discovering:false
 property QtObject devices: ListModel {
  property var values:[]
  dynamicRoles:true
  onValuesChanged: {clear(); for (const device of values) append({modelData:device})}
 }
}
''')
    write('Quickshell/Bluetooth/BluetoothDevice.qml', '''import QtQml
QtObject {
 property string dbusPath:"/org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF"
 property string address:"AA:BB:CC:DD:EE:FF"
 property string name:"Keyboard"
 property string icon:"input-keyboard"
 property bool paired:false
 property bool pairing:false
 property bool connected:false
 property bool trusted:false
 property bool blocked:false
 property bool batteryAvailable:false
 property real battery:-1
 property int pairCalls:0
 property int cancelCalls:0
 function pair() {pairCalls++; pairing=true}
 function cancelPair() {cancelCalls++;pairing=false}
 function forget() {}
}
''')
    service = imports / 'qs/src/core/services'
    service.mkdir(parents=True)
    shutil.copy2(ROOT / 'src/core/services/BluetoothService.qml', service)
    write('qs/src/core/services/qmldir', 'module qs.src.core.services\n' + ''.join(f'singleton {name} 1.0 {name}.qml\n' for name in ['BluetoothService','GlobalStates','SessionMonitor','AppLaunchService']))
    write('qs/src/core/services/GlobalStates.qml', '''pragma Singleton
import QtQml
QtObject {property bool connectionsOpen:true;property string connectionsSection:"bluetooth";property bool lockscreenActive:false}
''')
    write('qs/src/core/services/SessionMonitor.qml', 'pragma Singleton\nimport QtQml\nQtObject {signal resumed()}\n')
    write('qs/src/core/services/AppLaunchService.qml', 'pragma Singleton\nimport QtQml\nQtObject {function launchCommand(argv) {}}\n')
    write('qs/src/core/config/qmldir', 'module qs.src.core.config\nsingleton AppConfig 1.0 AppConfig.qml\n')
    write('qs/src/core/config/AppConfig.qml', 'pragma Singleton\nimport QtQml\nQtObject {property bool bluetoothAgentEnabled:true;property int bluetoothPairingTimeout:120;function moduleEnabled(name) {return true}}\n')
    write('qs/src/core/services/connectivity/NativeBluetoothAgent.qml', '''import QtQml
import qs.src.core.config
import qs.src.core.services
QtObject {
 id:root
 property bool enabled:AppConfig.bluetoothAgentEnabled
 property bool blocked:GlobalStates.lockscreenActive || !BluetoothService.enabled || !GlobalStates.connectionsOpen || GlobalStates.connectionsSection!=="bluetooth"
 property bool registered:true
 property bool armed:false
 property bool transport:false
 readonly property bool busy:armed || transport
 property string operationPath:""
 property string deviceName:""
 property string deviceAddress:""
 property string requestKind:""
 property string requestToken:""
 property string code:""
 property string serviceUuid:""
 property int entered:0
 property string validationError:""
 property int starts:0
 property int cancellations:0
 signal operationCancelled(string path,string reason)
 signal operationFinished(string path,bool success,string error)
 onBlockedChanged:if(blocked) abort()
 function arm(path,name,address) {if(!registered || blocked || busy) return false;operationPath=path;deviceName=name;deviceAddress=address;armed=true;return true}
 function startPair() {if(!armed || busy && transport) return false;starts++;transport=true;return true}
 function finish(success) {const path=operationPath;transport=false;armed=false;operationPath="";requestToken="";operationFinished(path,success,success?"":"Authentication failed")}
 function abort() {if(!armed)return;const path=operationPath;armed=false;operationPath="";requestToken="";cancellations++;operationCancelled(path,"Pairing cancelled")}
 function deviceRemoved(path) {if(path===operationPath) abort()}
 function submit(token,value) {if(!token || token!==requestToken) return false;requestToken="";return true}
 function reject(token) {if(!token || token!==requestToken) return false;abort();return true}
}
''')
    (work / 'tst_bluetooth.qml').write_text('''import QtQuick
import QtTest
import Quickshell.Bluetooth
import qs.src.core.config
import qs.src.core.services
Item {
 Component {id:deviceComponent;BluetoothDevice {}}
 TestCase {
  name:"BluetoothService"
  when:windowShown
  property BluetoothDevice device:null
  function init() {
   AppConfig.bluetoothAgentEnabled=true
   GlobalStates.connectionsOpen=true;GlobalStates.connectionsSection="bluetooth";GlobalStates.lockscreenActive=false
   Bluetooth.defaultAdapter.enabled=true
   device=deviceComponent.createObject(null)
   Bluetooth.defaultAdapter.devices.values=[device]
   tryVerify(()=>BluetoothService.pairingAgent!==null)
   BluetoothService.pairingAgent.transport=false
   BluetoothService.pairingAgent.starts=0
   wait(10)
  }
  function cleanup() {
   BluetoothService.cancelPairing()
   if(BluetoothService.pairingAgent) BluetoothService.pairingAgent.transport=false
   Bluetooth.defaultAdapter.devices.values=[]
   device.destroy();device=null
   wait(10)
  }
  function test_pair_success_and_failure() {
   const agent=BluetoothService.pairingAgent
   BluetoothService.pairDevice(device)
   compare(agent.starts,1);compare(agent.operationPath,device.dbusPath);compare(device.pairCalls,0)
   verify(BluetoothService.pairingPending);verify(!device.trusted);verify(!device.connected)
   device.paired=true;wait(10);verify(!device.trusted)
   agent.finish(true);tryVerify(()=>!BluetoothService.pairingPending)
   verify(device.trusted);verify(device.connected)
  }
  function test_pair_failure() {
   const agent=BluetoothService.pairingAgent
   BluetoothService.pairDevice(device);agent.finish(false)
   verify(!BluetoothService.pairingPending);verify(!device.trusted);verify(!device.connected)
   compare(BluetoothService.errorMessage,"Authentication failed")
  }
  function test_cancel_and_no_overlap() {
   const agent=BluetoothService.pairingAgent
   BluetoothService.pairDevice(device);const starts=agent.starts
   BluetoothService.cancelPairing();verify(!BluetoothService.pairingPending)
   BluetoothService.pairDevice(device);compare(agent.starts,starts)
   agent.transport=false;tryVerify(()=>BluetoothService.busyDeviceAddress==="")
   BluetoothService.pairDevice(device);compare(agent.starts,starts+1)
  }
  function test_transitions_data() {return [{tag:"lock"},{tag:"close"},{tag:"section"},{tag:"radio"},{tag:"resume"},{tag:"remove"}]}
  function test_transitions(data) {
   const agent=BluetoothService.pairingAgent
   BluetoothService.pairDevice(device);verify(BluetoothService.pairingPending)
   if(data.tag==="lock")GlobalStates.lockscreenActive=true
   if(data.tag==="close")GlobalStates.connectionsOpen=false
   if(data.tag==="section")GlobalStates.connectionsSection="wifi"
   if(data.tag==="radio")Bluetooth.defaultAdapter.enabled=false
   if(data.tag==="resume")SessionMonitor.resumed()
   if(data.tag==="remove")Bluetooth.defaultAdapter.devices.values=[]
   tryVerify(()=>!BluetoothService.pairingPending)
   verify(!device.trusted);verify(!device.connected);verify(!agent.armed)
  }
  function test_disable_agent_during_pairing() {
   BluetoothService.pairDevice(device);verify(BluetoothService.pairingPending)
   AppConfig.bluetoothAgentEnabled=false
   tryVerify(()=>!BluetoothService.pairingPending)
   verify(!device.trusted);verify(!device.connected)
  }
  function test_request_token() {
   const agent=BluetoothService.pairingAgent
   BluetoothService.pairDevice(device);agent.requestKind="confirm";agent.code="012345";agent.requestToken="current"
   compare(BluetoothService.pairingToken,"current");compare(BluetoothService.pairingCode,"012345")
   verify(!BluetoothService.answerPairing("old",""));compare(agent.requestToken,"current")
   verify(BluetoothService.answerPairing("current",""));compare(BluetoothService.pairingToken,"")
  }
  function test_unavailable_does_not_start() {
   const agent=BluetoothService.pairingAgent;agent.registered=false
   BluetoothService.pairDevice(device);verify(!BluetoothService.pairingPending);compare(device.pairCalls,0)
   verify(BluetoothService.errorMessage.length>0);agent.registered=true
  }
  function test_external_fallback() {
   AppConfig.bluetoothAgentEnabled=false;tryCompare(BluetoothService,"pairingAgent",null)
   BluetoothService.pairDevice(device);compare(device.pairCalls,1);verify(BluetoothService.pairingPending)
   device.paired=true;wait(10);verify(!device.trusted)
   device.pairing=false;tryVerify(()=>device.trusted);verify(device.connected)
  }
  function test_external_failure() {
   AppConfig.bluetoothAgentEnabled=false;tryCompare(BluetoothService,"pairingAgent",null)
   BluetoothService.pairDevice(device);device.pairing=false
   tryVerify(()=>!BluetoothService.pairingPending);verify(!device.trusted);verify(BluetoothService.errorMessage.length>0)
  }
 }
}
''')
    env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software', QT_ASSUME_STDERR_HAS_CONSOLE='1')
    runner = '/usr/lib/qt6/bin/qmltestrunner'
    result = subprocess.run([runner, '-input', str(work), '-import', str(imports)], env=env, capture_output=True, text=True, timeout=30)
    output = result.stdout + result.stderr
    print(output)
    if result.returncode or 'QWARN' in output:
        raise SystemExit(1)
