#!/usr/bin/env python3
"""Check address-family-independent Ethernet state with isolated QML models."""
from pathlib import Path
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='shell-ip-info-') as temp:
    temp = Path(temp)
    imports = temp / 'imports'
    def write(name, text):
        target = imports / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text)
    write('Quickshell/qmldir', 'module Quickshell\nSingleton 1.0 Singleton.qml\n')
    write('Quickshell/Singleton.qml', 'import QtQml\nQtObject {default property list<QtObject> children}\n')
    module = 'Quickshell/Networking/'
    write(module + 'qmldir', 'module Quickshell.Networking\nsingleton Networking 1.0 Networking.qml\nsingleton DeviceType 1.0 DeviceType.qml\nNetworkDevice 1.0 NetworkDevice.qml\nWiredDevice 1.0 WiredDevice.qml\n')
    write(module + 'Networking.qml', 'pragma Singleton\nimport QtQml\nQtObject {property QtObject devices:QtObject {property list<NetworkDevice> values:[]}}\n')
    write(module + 'DeviceType.qml', 'pragma Singleton\nimport QtQml\nQtObject {enum Kind {Wifi,Wired}}\n')
    write(module + 'NetworkDevice.qml', 'import QtQml\nQtObject {property string name:"eth0";property int type:DeviceType.Wired;property bool connected:false}\n')
    write(module + 'WiredDevice.qml', 'NetworkDevice {}\n')
    module = 'qs/src/core/services/'
    write(module + 'qmldir', 'module qs.src.core.services\nsingleton EthernetService 1.0 EthernetService.qml\nNetworkInfo 1.0 NetworkInfo.qml\n')
    for name in ['EthernetService.qml', 'NetworkInfo.qml']:
        shutil.copy2(ROOT / 'src/core/services' / name, imports / module / name)
    write(module + 'connectivity/NativeNetworkInfo.qml', '''import QtQml
QtObject {
 objectName:"testNativeInfo"
 property string interfaceName:""
 property bool ready:interfaceName!==""
 property var ipv4Addresses:[]
 property var ipv6Addresses:["2001:db8::10/64","fe80::10/64"]
 property string ipv4Gateway:""
 property string ipv6Gateway:"fe80::1"
 function refresh() {}
}
''')
    test = temp / 'tst_info.qml'
    test.write_text('''import QtQuick
import QtTest
import Quickshell.Networking
import qs.src.core.services
TestCase {
 name:"EthernetIpFamilies"
 when:windowShown
 Component {id:node;WiredDevice {}}
 function init() {Networking.devices.values=[];wait(1)}
 function test_ipv6_only_has_connected_status() {
  const device=createTemporaryObject(node,this,{connected:true})
  Networking.devices.values=[device]
  tryCompare(EthernetService,"connected",true)
  tryCompare(EthernetService,"detailsReady",true)
  compare(EthernetService.interfaceName,"eth0")
  compare(EthernetService.ipv4Addresses.length,0)
  compare(EthernetService.ipv6Addresses.length,2)
  compare(EthernetService.ipv6Gateway,"fe80::1")
 }
 function test_address_changes_never_decide_link_state() {
  const device=createTemporaryObject(node,this,{connected:true})
  Networking.devices.values=[device]
  tryCompare(EthernetService,"detailsReady",true)
  const native=findChild(EthernetService,"testNativeInfo")
  verify(native!==null)
  native.ipv4Addresses=["192.0.2.10/24"];native.ipv4Gateway="192.0.2.1"
  tryCompare(EthernetService,"ipv4Gateway","192.0.2.1")
  native.ipv6Addresses=[];native.ipv6Gateway=""
  tryCompare(EthernetService.ipv6Addresses,"length",0)
  verify(EthernetService.connected)
  native.ipv4Addresses=[];native.ipv4Gateway=""
  tryCompare(EthernetService.ipv4Addresses,"length",0)
  verify(EthernetService.connected)
  device.connected=false
  tryCompare(EthernetService,"connected",false)
  tryCompare(EthernetService,"detailsReady",false)
  compare(EthernetService.ipv6Gateway,"")
 }
 function test_adapter_replacement_and_removal() {
  const first=createTemporaryObject(node,this,{name:"eth0",connected:true})
  const second=createTemporaryObject(node,this,{name:"eth1",connected:false})
  Networking.devices.values=[first,second]
  tryCompare(EthernetService,"interfaceName","eth0")
  first.connected=false;second.connected=true
  tryCompare(EthernetService,"interfaceName","eth1")
  Networking.devices.values=[]
  tryCompare(EthernetService,"connected",false)
  compare(EthernetService.interfaceName,"")
  tryCompare(EthernetService.ipv6Addresses,"length",0)
 }
}
''')
    env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software')
    result = subprocess.run(['/usr/lib/qt6/bin/qmltestrunner', '-input', str(test), '-import', str(imports)],
                            env=env, capture_output=True, text=True, timeout=30)
    output = result.stdout + result.stderr
    print(output)
    failure = result.returncode or int(any(marker in output for marker in ['QWARN', 'ReferenceError', 'TypeError', 'Unable to assign']))
    if failure:
        raise SystemExit(failure)

if '--native' not in sys.argv:
    raise SystemExit(0)

# Load the actual QS model and optional C++ detail reader. This only reads the
# active interface: no scanning, activation, profile updates or radio commands.
with tempfile.TemporaryDirectory(prefix='shell-ip-info-native-') as temp:
    temp = Path(temp)
    (temp / 'src').symlink_to(ROOT / 'src', target_is_directory=True)
    (temp / 'shell.qml').write_text('''import QtQuick
import Quickshell
import Quickshell.Networking
import qs.src.core.services
QtObject {
 id:root
 readonly property QtObject deviceModel:Networking.devices
 readonly property list<NetworkDevice> devices:deviceModel ? (deviceModel["values"] ?? []) : []
 readonly property NetworkDevice device:{for(const candidate of root.devices)if(candidate.connected)return candidate;return null}
 property NetworkInfo info:NetworkInfo {interfaceName:root.device?.name ?? ""}
 property Connections changes:Connections {
  target:root.info
  function onReadyChanged() {Qt.callLater(root.check)}
 }
 property Timer deadline:Timer {interval:8000;running:true;onTriggered:{console.warn("IP INFO NATIVE FAIL: timeout or no active interface");Qt.exit(1)}}
 function check() {
  if(!info.ready)return
  if(!root.device || info.interfaceName!==root.device.name) {console.warn("IP INFO NATIVE FAIL: stale interface");Qt.exit(1);return}
  for(const address of info.ipv6Addresses)if(!address.includes(":")) {console.warn("IP INFO NATIVE FAIL: IPv6 decoding");Qt.exit(1);return}
  for(const address of info.ipv4Addresses)if(!address.includes(".")) {console.warn("IP INFO NATIVE FAIL: IPv4 decoding");Qt.exit(1);return}
  console.warn("IP INFO NATIVE PASS: IPv4="+info.ipv4Addresses.length+" IPv6="+info.ipv6Addresses.length)
  Qt.quit()
 }
}
''')
    result = subprocess.run(['qs', '-p', str(temp)], env=os.environ.copy(), capture_output=True, text=True, timeout=12)
    output = result.stdout + result.stderr
    print(output)
    raise SystemExit(result.returncode or int('IP INFO NATIVE PASS' not in output or any(
        marker in output for marker in ['IP INFO NATIVE FAIL', 'ReferenceError', 'TypeError', 'Unable to assign'])))
