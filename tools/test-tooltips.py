#!/usr/bin/env python3
"""Exercise real Wayland PopupWindow sizing and tooltip lifecycle without services."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='shell-tooltip-test-') as directory:
    tree = Path(directory) / 'qs'
    tree.mkdir()
    shutil.copytree(ROOT / 'src/ui', tree / 'src/ui')
    config = tree / 'src/core/config'
    config.mkdir(parents=True)
    for name in ['Tokens', 'Theme']:
        shutil.copy2(ROOT / f'src/core/config/{name}.qml', config / f'{name}.qml')
    (config / 'qmldir').write_text('module qs.src.core.config\n'+''.join(
        f'singleton {name} 1.0 {name}.qml\n' for name in ['Tokens','Theme','AppConfig']))
    (config / 'AppConfig.qml').write_text('''pragma Singleton
import QtQml
QtObject {
 property string designSystem:"minimal"
 property real fontScale:1.3
 property string fontFamily:""
 property string monoFamily:""
 property bool darkMode:true
 property string themeVariant:"tonalspot"
 property real themeContrast:0
 property bool reduceMotion:false
 property real motionScale:1
 property string barPosition:"top"
}
''')
    shutil.copy2(ROOT / 'src/features/popouts/TrayMenu.qml', tree / 'NativeTrayMenu.qml')
    (tree / 'shell.qml').write_text('''import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import qs.src.core.config
import qs.src.ui.feedback

ShellRoot {
 id: root
 property int step:0
 property int ticks:0
 property real firstHeight:0
 property QsMenuHandle menuHandle:null
 readonly property int trayCount:SystemTray.items.values.length
 function hasActions(item) {
  if (item.headline && item.headline !== "Back") return true
  for (const child of item.children ?? []) if (hasActions(child)) return true
  return false
 }
 function check(ok, message) { if (!ok) {console.warn("TOOLTIP FAIL: "+message);Qt.exit(1)} }
 PanelWindow {
  id: bar
  anchors {top:true;left:true;right:true}
  implicitHeight:32
  color:"transparent"
  exclusiveZone:0
  mask:Region {}
  WlrLayershell.layer:WlrLayer.Overlay
  WlrLayershell.namespace:"shell:tooltip-test"
  NativeTrayMenu {id:nativeMenu;trayItem:root.menuHandle;maximumHeight:180;visible:false}
  Item {id:sourceItem; x:bar.width-40;width:32;height:32}
 }
 TooltipManager {id:manager;bar:bar}
 TooltipItem {id:first;tooltip:manager;owner:sourceItem;text:"Network"}
 TooltipItem {id:second;tooltip:manager;owner:sourceItem;text:"<b>Literal network name</b> "+"Long text ".repeat(40)}
 Component {id:temporary;TooltipItem {tooltip:manager;owner:sourceItem;text:"Temporary"}}
 property TooltipItem ephemeral:null
 Timer {
  interval:40;repeat:true;running:true
  onTriggered: {
   root.ticks++
   root.check(root.ticks<200,"lifecycle deadline")
   switch(root.step) {
   case 0:first.show=true;root.step++;break
   case 1:
    if(first.opacity<1 || !manager.container) return
    root.check(manager.shownItem===first,"first tooltip shown")
    root.check(manager.container.Window.window!==null,"real popup window")
    root.check(manager.container.Window.window.width>=Math.ceil(first.width),"first width fits window")
    root.firstHeight=first.height
    first.show=false;second.show=true;root.step++;break
   case 2:
    if(manager.shownItem!==second || second.opacity<1) return
    root.check(!first.visible,"old hint hidden on switch")
    root.check(second.height>root.firstHeight,"long text wraps")
    root.check(second.width<=manager.maximumWidth,"width bounded")
    root.check(manager.container.Window.window.width>=Math.ceil(second.width),"long width fits window")
    root.check(manager.container.Window.window.height>=Math.ceil(second.height),"long height fits window")
    second.grabToImage(result=>result.saveToFile("/tmp/shell-ui-renders/tooltip-native.png"))
    second.show=false;root.step++;break
   case 3:
    if(manager.shownItem) return
    root.ephemeral=temporary.createObject(bar.contentItem,{show:true});root.step++;break
   case 4:
    if(manager.shownItem!==root.ephemeral || root.ephemeral.opacity<1) return
    root.ephemeral.destroy();root.ephemeral=null;root.step++;break
   case 5:
    if(manager.shownItem || manager.activeTooltip) return
    AppConfig.barPosition="bottom";first.show=true;root.step++;break
   case 6:
    if(manager.shownItem!==first || first.opacity<1) return
    first.show=false;root.step++;break
   case 7:
    if(manager.shownItem) return
    const item=SystemTray.items.values.find(item=>item.hasMenu)
    if (item) {root.menuHandle=item.menu;root.step++}
    else {console.warn("TOOLTIP PASS (no application menu available)");Qt.quit()}
    break
   case 8:
    if (!root.hasActions(nativeMenu)) return
    root.check(nativeMenu.implicitHeight<=180,"native application menu bounded")
    console.warn("TOOLTIP PASS; NATIVE MENU PASS");Qt.quit()
   }
  }
 }
}
''')
    env = dict(os.environ, QT_QPA_PLATFORM='wayland', QML_IMPORT_PATH=directory)
    result = subprocess.run(['qs', '-p', str(tree)], env=env, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=15)
    print(result.stdout)
    if result.returncode or 'TOOLTIP PASS' not in result.stdout or any(
        marker in result.stdout for marker in ['TOOLTIP FAIL','ERROR','TypeError','ReferenceError','Binding loop','Unable to assign']):
        raise SystemExit(1)
