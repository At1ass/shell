#!/usr/bin/env python3
"""Probe the real GreeterData plugin through Quickshell without creating windows."""
from pathlib import Path
import tempfile, subprocess, os

with tempfile.TemporaryDirectory(prefix='shell-greeter-data-probe-') as directory:
    path = Path(directory) / 'shell.qml'
    path.write_text('''import QtQuick
import Quickshell
import GreeterData 1.0
ShellRoot {
 property bool finished:false
 function verifyData() {
  if(finished || !GreeterDataBackend.ready) return
  finished=true
  const sessions=Array.from(GreeterDataBackend.sessions)
  const users=Array.from(GreeterDataBackend.users)
  for(const entry of sessions) {
   const argv=Array.from(entry.argv)
   if(!entry.id || !entry.name || argv.length===0 || !argv[0] || argv.some(arg=>typeof arg!=="string")) {console.warn("INVALID SESSION DTO");Qt.exit(1);return}
  }
  if(sessions.length && GreeterDataBackend.sessionIndex(sessions[0].id)!==0) {Qt.exit(2);return}
  if(users.length && GreeterDataBackend.userIndex(users[0].username)!==0) {Qt.exit(3);return}
  if(GreeterDataBackend.sessionNames.length!==sessions.length || GreeterDataBackend.userNames.length!==users.length) {Qt.exit(4);return}
  console.warn("NATIVE GREETER DATA PASS sessions="+sessions.length+" users="+users.length)
  Qt.quit()
 }
 Connections {target:GreeterDataBackend;function onReadyChanged() {verifyData()}}
 Component.onCompleted: verifyData()
 Timer {running:true;interval:5000;onTriggered:{console.warn("DATA PROBE TIMEOUT");Qt.exit(5)}}
}
''')
    env=dict(os.environ,QT_QPA_PLATFORM='offscreen')
    result=subprocess.run(['qs','-p',str(path)],env=env,text=True,capture_output=True,timeout=10)
    print(result.stdout+result.stderr)
    assert result.returncode==0 and 'NATIVE GREETER DATA PASS' in result.stdout+result.stderr
