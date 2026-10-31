#!/usr/bin/env python3
"""Exercise real Quickshell focus events against private fake Hyprland sockets."""
import json
import os
from pathlib import Path
import queue
import socket
import subprocess
import tempfile
import threading
import time

ROOT = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='shell-focus-test-') as directory:
    tree = Path(directory)
    runtime = tree / 'runtime'
    runtime.mkdir(mode=0o700)
    sockets = runtime / 'hypr/focus-test'
    sockets.mkdir(parents=True)
    requests = socket.socket(socket.AF_UNIX)
    requests.bind(str(sockets / '.socket.sock'))
    requests.listen()
    requests.settimeout(0.2)
    events = socket.socket(socket.AF_UNIX)
    events.bind(str(sockets / '.socket2.sock'))
    events.listen()
    events.settimeout(8)
    stopped = threading.Event()
    errors = []
    workspaces = [dict(id=i, address=str(i), name=str(i), monitor='DP-3' if i == 3 else 'DP-2', monitorID=1 if i == 3 else 0) for i in [1, 2, 3]]
    responses = {
        'j/status': {'configProvider': 'hyprlang'},
        'j/monitors': [dict(id=i, name=name, focused=i == 0, activeWorkspace=dict(id=ws, address=str(ws), name=str(ws)), width=1080, height=1080, scale=1) for i, name, ws in [(0, 'DP-2', 1), (1, 'DP-3', 3)]],
        'j/workspaces': workspaces,
        'j/clients': [dict(address='0xabc', title='Editor', workspace=dict(id=1, name='1'), monitor=0, **{'class': 'editor'})],
    }

    def serve():
        while not stopped.is_set():
            try:
                connection, _ = requests.accept()
            except socket.timeout:
                continue
            except OSError:
                return
            with connection:
                connection.settimeout(2)
                try:
                    request = connection.recv(4096).decode()
                    if request not in responses:
                        errors.append('Unexpected request: ' + request)
                    connection.sendall(json.dumps(responses.get(request, {})).encode())
                except OSError as error:
                    errors.append(str(error))

    worker = threading.Thread(target=serve)
    worker.start()
    module = tree / 'imports/TestFocus'
    module.mkdir(parents=True)
    (module / 'qmldir').write_text('module TestFocus\nsingleton ActiveWindow 1.0 ActiveWindow.qml\n')
    (module / 'ActiveWindow.qml').write_text((ROOT / 'src/core/services/ActiveWindowService.qml').read_text())
    (tree / 'probe.qml').write_text('''import QtQuick
import Quickshell
import Quickshell.Hyprland
import TestFocus
Scope {
 id:root
 property int step:0
 property int ticks:0
 property var initialWindow:null
 readonly property QtObject service:ActiveWindow
 function check(ok,message) {if(!ok){console.warn("FOCUS FAIL",message);Qt.exit(1)}}
 Timer {
  interval:20;running:true;repeat:true
  onTriggered:{
   if(++root.ticks>200){console.warn("FOCUS FAIL timeout at",root.step);Qt.exit(1);return}
   if(root.step===0){
    if(Hyprland.toplevels.values.length!==1 || Hyprland.monitors.values.length!==2) return
    console.warn("FOCUS READY");root.step=1
   }else if(root.step===1){
    if(service.windowTitle!=="Editor")return
    root.initialWindow=Hyprland.activeToplevel
    console.warn("FOCUS CLEAR WORKSPACE");root.step=2
   }else if(root.step===2){
    if(Hyprland.focusedWorkspace?.id!==2)return
    root.check(service.windowTitle==="" && service.windowClass==="","empty workspace title")
    console.warn("FOCUS NATIVE RETAINED",Hyprland.activeToplevel===root.initialWindow)
    console.warn("FOCUS RESTORE WORKSPACE");root.step=3
   }else if(root.step===3){
    if(service.windowTitle!=="Editor")return
    root.check(Hyprland.activeToplevel===root.initialWindow,"same window restored")
    console.warn("FOCUS CLEAR MONITOR");root.step=4
   }else if(root.step===4){
    if(Hyprland.focusedMonitor?.name!=="DP-3")return
    root.check(service.windowTitle==="" && service.windowClass==="","empty monitor title")
    console.warn("FOCUS RESTORE MONITOR");root.step=5
   }else if(root.step===5){
    if(service.windowTitle!=="Editor")return
    root.check(Hyprland.focusedMonitor?.name==="DP-2","focused monitor restored")
    console.warn("FOCUS PASS");Qt.quit()
   }
  }
 }
}''')
    environment = dict(os.environ, QT_QPA_PLATFORM='offscreen', XDG_RUNTIME_DIR=str(runtime),
                       XDG_CONFIG_HOME=str(tree / 'config'), XDG_CACHE_HOME=str(tree / 'cache'),
                       HYPRLAND_INSTANCE_SIGNATURE='focus-test', QML_IMPORT_PATH=str(tree / 'imports'))
    environment.pop('WAYLAND_DISPLAY', None)
    process = None
    event_connection = None
    lines = queue.Queue()
    output = []
    commands = {
        'FOCUS READY': 'activewindowv2>>abc\n',
        'FOCUS CLEAR WORKSPACE': 'workspacev2>>2,2\nactivewindowv2>>\n',
        'FOCUS RESTORE WORKSPACE': 'workspacev2>>1,1\nactivewindowv2>>abc\n',
        'FOCUS CLEAR MONITOR': 'focusedmon>>DP-3,3\nactivewindowv2>>\n',
        'FOCUS RESTORE MONITOR': 'focusedmon>>DP-2,1\nactivewindowv2>>abc\n',
    }
    reader = None
    try:
        process = subprocess.Popen(['qs', '-p', str(tree / 'probe.qml')], env=environment,
                                   stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)

        def read_output():
            for line in process.stdout:
                lines.put(line)

        reader = threading.Thread(target=read_output)
        reader.start()
        event_connection, _ = events.accept()
        deadline = time.monotonic() + 8
        while time.monotonic() < deadline:
            try:
                line = lines.get(timeout=0.1)
            except queue.Empty:
                if process.poll() is not None and not reader.is_alive():
                    break
                continue
            output.append(line)
            for marker, event in commands.items():
                if marker in line:
                    event_connection.sendall(event.encode())
        process.wait(timeout=2)
        text = ''.join(output)
        print(text)
        assert process.returncode == 0 and 'FOCUS PASS' in text and 'FOCUS FAIL' not in text, 'Native focus regression failed'
        assert not errors, errors
        print('PASS: real Quickshell empty-workspace/monitor events and same-window restoration; private sockets only')
    finally:
        if process is not None:
            if process.poll() is None:
                process.kill()
            process.wait()
            if reader is not None:
                reader.join(timeout=2)
            process.stdout.close()
        stopped.set()
        requests.close()
        events.close()
        if event_connection is not None:
            event_connection.close()
        worker.join(timeout=2)
