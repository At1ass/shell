#!/usr/bin/env python3
"""Read native workspace/window models and validate dispatch strings in isolation.

No real dispatch, focus change, move, close, capture, lock or clipboard access.
"""
from pathlib import Path
import os,subprocess,tempfile,shutil
ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='shell-overview-test-') as directory:
    tree=Path(directory)/'qs';tree.mkdir()
    services=tree/'src/core/services';services.mkdir(parents=True)
    config=tree/'src/core/config';config.mkdir(parents=True)
    (config/'qmldir').write_text('module qs.src.core.config\nsingleton AppConfig 1.0 AppConfig.qml\n')
    (config/'AppConfig.qml').write_text('pragma Singleton\nimport QtQml\nQtObject {property int overviewFirstWorkspace:1;property int overviewWorkspaceCount:3;property bool overviewIncludeSpecial:true;property bool overviewShowPreviews:true}\n')
    (services/'qmldir').write_text('module qs.src.core.services\nsingleton OverviewService 1.0 OverviewService.qml\nsingleton GlobalStates 1.0 GlobalStates.qml\nsingleton HyprlandDispatch 1.0 HyprlandDispatch.qml\n')
    shutil.copy2(ROOT/'src/core/services/OverviewService.qml',services/'OverviewService.qml')
    (services/'GlobalStates.qml').write_text('pragma Singleton\nimport QtQml\nQtObject {property bool overviewOpen:true;function closePanel(name){overviewOpen=false}}\n')
    (services/'HyprlandDispatch.qml').write_text('pragma Singleton\nimport QtQml\nQtObject {property int commands:0;function closeWindow(address){commands++} function focusWindow(address){commands++} function focusWorkspace(id,name){commands++} function moveWindowToWorkspace(address,id,name){commands++}}\n')
    fake=tree/'FixtureHyprland';fake.mkdir()
    (fake/'qmldir').write_text('module FixtureHyprland\nsingleton Hyprland 1.0 Hyprland.qml\n')
    (fake/'Hyprland.qml').write_text('pragma Singleton\nimport QtQml\nQtObject {property var commands:[];function dispatch(expression){commands=commands.concat([expression])}}\n')
    source=(ROOT/'src/core/services/HyprlandDispatch.qml').read_text().replace('pragma Singleton\n','',1).replace('import Quickshell.Hyprland','import FixtureHyprland').replace('Singleton {','QtObject {',1)
    (tree/'DispatchProbe.qml').write_text(source)
    probe=tree/'shell.qml'
    probe.write_text('''import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import FixtureHyprland as Fixture
import qs.src.core.services
ShellRoot {
 id:root
 property QtObject dispatch:DispatchProbe {id:dispatch}
 property int ticks:0
 property int phase:0
 Component.onCompleted:{OverviewService.query=""}
 function check(ok,message){if(!ok){console.warn("OVERVIEW FAIL "+message);Qt.exit(1);throw new Error(message)}}
 property Timer poll:Timer {
  interval:30;running:true;repeat:true
  onTriggered:{
   if(++root.ticks>100){root.check(false,"deadline");return}
   if(root.phase===0){
    if(root.ticks<8)return
    root.check(OverviewService._windows!==null && OverviewService._workspaces!==null,"native ObjectModel bridge")
    root.check(OverviewService.workspaces.length>=3,"empty workspace targets")
    root.check(OverviewService.windows.length===Hyprland.toplevels.values.length,"native window snapshot")
    for(const window of OverviewService.windows) {
     if(window.wayland)root.check(ToplevelManager.toplevels.values.includes(window.wayland),"native Wayland capture handle belongs to ToplevelManager")
    }
    console.warn("Native Wayland capture handles:",OverviewService.windows.filter(window=>!!window.wayland).length)
    const nativeCount=OverviewService.windows.length
    console.warn("Native window count:",nativeCount)
    if(nativeCount>0){
     const address=OverviewService.windows[0].address
     root.check(OverviewService.closeWindow(address),"close intent routed to fake dispatcher")
     const target=OverviewService.workspaces.find(workspace=>workspace.id!==OverviewService.windows[0].workspace?.id)
     if(target)root.check(OverviewService.moveWindow(address,target.id),"move intent routed to fake dispatcher")
    }
    const before=Fixture.Hyprland.commands.length
    root.check(!dispatch.moveWindowToWorkspace("not-an-address",2,""),"address validation")
    root.check(!dispatch.moveWindowToWorkspace("abc",0,""),"workspace zero refused")
    dispatch.moveWindowToWorkspace("abc",2,"")
    root.check(Fixture.Hyprland.commands.length===before+1,"one fake command")
    root.check(Fixture.Hyprland.commands[before]==='hl.dsp.window.move({window="address:0xabc",workspace=2,follow=false})',"silent move expression")
    dispatch.closeWindow("abc")
    root.check(Fixture.Hyprland.commands[Fixture.Hyprland.commands.length-1]==='hl.dsp.window.close({window="address:0xabc"})',"targeted normal close")
    const closeCount=Fixture.Hyprland.commands.length
    dispatch.closeWindow('abc\\";hl.dsp.exit()')
    root.check(Fixture.Hyprland.commands.length===closeCount,"malformed close target refused")
    const name='special:quotes"\\\\and unicode ё'
    const literal=dispatch._workspace(-99,name)
    root.check(JSON.parse(literal)===name,"workspace literal escaping")
    root.check(dispatch._workspace(-99,"bad\\nname")==="","control characters refused")
    OverviewService.query="temporary";GlobalStates.overviewOpen=false
    root.phase=1
   } else {
    root.check(OverviewService.windows.length===0 && OverviewService.workspaces.length===0,"hidden work released")
    root.check(OverviewService.query==="","hidden search reset")
    console.warn("OVERVIEW NATIVE PASS");Qt.quit()
   }
  }
 }
}
''')
    probe_env=dict(os.environ,QT_QPA_PLATFORM="offscreen",QML_IMPORT_PATH=str(tree)+os.pathsep+os.environ.get("QML_IMPORT_PATH",""))
    runtime=Path(probe_env.get('XDG_RUNTIME_DIR',f'/run/user/{os.getuid()}'))
    probe_env.setdefault('XDG_RUNTIME_DIR',str(runtime))
    displays=[path.name for path in runtime.glob('wayland-*') if path.is_socket()]
    if probe_env.get('WAYLAND_DISPLAY') or len(displays)==1:
        probe_env.setdefault('WAYLAND_DISPLAY',displays[0] if displays else '')
        probe_env['QT_QPA_PLATFORM']='wayland'
    if not probe_env.get('HYPRLAND_INSTANCE_SIGNATURE'):
        runtime=Path(probe_env.get('XDG_RUNTIME_DIR',f'/run/user/{os.getuid()}'))
        instances=[path.parent.name for path in (runtime/'hypr').glob('*/.socket.sock')]
        if len(instances)==1: probe_env['HYPRLAND_INSTANCE_SIGNATURE']=instances[0]
    result=subprocess.run(['qs' ,'-p',str(probe)],env=probe_env,capture_output=True,text=True,timeout=8)
    output=result.stdout+result.stderr;print(output)
    assert result.returncode==0 and 'OVERVIEW NATIVE PASS' in output and not any(word in output for word in ['ReferenceError','TypeError','Binding loop','OVERVIEW FAIL']),output
