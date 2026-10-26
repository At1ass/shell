#!/usr/bin/env python3
"""Verify native background sampling and bootstrap independently of any window."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='shell-statistics-test-') as directory:
    tree = Path(directory) / 'qs'
    services = tree / 'src/core/services'
    services.mkdir(parents=True)
    names = ['SystemMonitorService','ServiceBootstrap']
    for name in names:
        shutil.copy2(ROOT / f'src/core/services/{name}.qml', services / f'{name}.qml')
    for name in ['NightLightService','IdleInhibitorService','GamingModeService']:
        names.append(name)
        (services / f'{name}.qml').write_text('pragma Singleton\nimport QtQml\nQtObject {property int calls:0;function init(){calls++}}\n')
    names.append('GlobalStates')
    (services / 'GlobalStates.qml').write_text('pragma Singleton\nimport QtQml\nQtObject {property bool dashboardOpen:false}\n')
    (services / 'qmldir').write_text('module qs.src.core.services\n'+''.join(
        f'singleton {name} 1.0 {name}.qml\n' for name in names))
    config = tree / 'src/core/config'
    config.mkdir(parents=True)
    shutil.copytree(ROOT / 'src/ui', tree / 'src/ui')
    for name in ['Tokens','Theme']:
        shutil.copy2(ROOT / f'src/core/config/{name}.qml',config / f'{name}.qml')
    (config / 'qmldir').write_text('module qs.src.core.config\n'+''.join(f'singleton {name} 1.0 {name}.qml\n' for name in ['AppConfig','Tokens','Theme']))
    (config / 'AppConfig.qml').write_text('pragma Singleton\nimport QtQml\nQtObject {property real storageWarningFreePercent:10;property real storageCriticalFreePercent:5;property var storageExcludedMounts:["/boot","/boot/efi","/efi"];property var storageOrder:["/","/home"];property var storageLabels:({});property string designSystem:"minimal";property real fontScale:1.3;property string fontFamily:"";property string monoFamily:"";property bool darkMode:true;property string themeVariant:"tonalspot";property real themeContrast:0;property bool reduceMotion:true;property real motionScale:1}\n')
    shutil.copy2(ROOT / 'src/features/dashboard/components/maintab_elements/StorageSection.qml',tree / 'NativeStorage.qml')
    (tree / 'shell.qml').write_text('''import QtQuick
import Quickshell
import qs.src.core.services
import qs.src.core.config
ShellRoot {
 id: root
 property int step:0
 property int ticks:0
 property int savedCount:0
 property Item savedRow:null
 property string renamedId:""
 function row(item, title) {
  if(item.headline===title) return item
  for(const child of item.children ?? []) {const found=row(child,title);if(found) return found}
  return null
 }
 Window {
  visible:true;width:600;height:700
  Loader {id:view;active:GlobalStates.dashboardOpen;sourceComponent:NativeStorage {width:600;expanded:true}}
 }
 function check(ok,message) {if (!ok) {console.warn("STATS FAIL: "+message);Qt.exit(1)}}
 Component.onCompleted: ServiceBootstrap.init()
 Timer {
  interval:100;running:true;repeat:true
  onTriggered: {
   root.ticks++
   root.check(root.ticks<120,"native sampling deadline")
   root.check(SystemMonitorService.isMonitoring,"sampling active with Dashboard hidden")
   const count=SystemMonitorService.cpuHistory.length
   if(root.step===0) {
    root.check(!GlobalStates.dashboardOpen,"Dashboard starts hidden")
    if(count<2) return
    root.check(SystemMonitorService.cpuHistory.every(value=>value>=0 && value<=1),"CPU samples normalized")
    root.check(SystemMonitorService.ramHistory.length===count,"aligned history")
    root.check(NightLightService.calls===1 && IdleInhibitorService.calls===1 && GamingModeService.calls===1,"bootstrap preserves existing services")
    root.savedCount=count;GlobalStates.dashboardOpen=true;root.step++
   } else if(root.step===1) {
    if(count<=root.savedCount) return
    if(SystemMonitorService.storageAvailable) {
     const first=SystemMonitorService.storageVolumes[0]
     root.savedRow=root.row(view.item,first.name)
     root.check(root.savedRow!==null,"native volume delegates render")
     root.renamedId=first.id
     AppConfig.storageLabels=({[first.mountPoint]:"Fixture volume"})
     AppConfig.storageWarningFreePercent=100
     AppConfig.storageCriticalFreePercent=100
     root.step=2
     return
    }
    root.savedCount=count;GlobalStates.dashboardOpen=false;root.step=3
   } else if(root.step===2) {
    const renamed=SystemMonitorService.storageVolumes.find(volume=>volume.id===root.renamedId)
    if(!renamed || renamed.name!=="Fixture volume" || SystemMonitorService.storageSeverity!==2) return
    root.check(root.row(view.item,"Fixture volume")===root.savedRow,"native keyed delegate survives updated DTO")
    root.check(SystemMonitorService.storageAlertText.indexOf("Critical space")>=0,"native warning policy propagates to UI")
    root.savedCount=count;GlobalStates.dashboardOpen=false;root.step=3
   } else {
    if(count<=root.savedCount) return
    if(SystemMonitorService.storageAvailable) {
     root.check(SystemMonitorService.storageVolumes.length>0,"mounted storage discovered")
     root.check(SystemMonitorService.storageDrives.length>0,"physical drives discovered")
     const ids=SystemMonitorService.storageVolumes.map(volume=>volume.id)
     root.check(new Set(ids).size===ids.length,"filesystem identities are unique")
     console.warn("STORAGE PASS: volumes="+SystemMonitorService.storageVolumes.length+" drives="+SystemMonitorService.storageDrives.length)
    }
    root.check(!SystemMonitorService.hasCpuTemp || SystemMonitorService.cpuTempHistory.length>0,"CPU temperature samples")
    root.check(!SystemMonitorService.hasGpuTemp || SystemMonitorService.gpuTempHistory.length>0,"GPU temperature samples")
    console.warn("STATS PASS: hidden/open/hidden sampling; CPU temperature="+SystemMonitorService.cpuTemp+" available="+SystemMonitorService.hasCpuTemp+"; GPU temperature="+SystemMonitorService.gpuTemp+" available="+SystemMonitorService.hasGpuTemp)
    Qt.quit()
   }
  }
 }
}
''')
    env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QML_IMPORT_PATH=directory + (os.pathsep + os.environ['STORAGE_PLUGIN_IMPORT'] if 'STORAGE_PLUGIN_IMPORT' in os.environ else ''))
    env.pop('WAYLAND_DISPLAY', None)
    result = subprocess.run(['qs','-p',str(tree)],env=env,text=True,
                            stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=20)
    print(result.stdout)
    if result.returncode or 'STATS PASS' not in result.stdout or any(marker in result.stdout for marker in [
        'STATS FAIL','ERROR','TypeError','ReferenceError','Binding loop','Unable to assign']):
        raise SystemExit(1)
