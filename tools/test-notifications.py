#!/usr/bin/env python3
"""Check notification geometry and view state in an isolated offscreen shell.

Uses the real list, cards and history service, with a mock live notification
server. XDG directories are temporary; the running shell and history are untouched.
"""
from pathlib import Path
import os,subprocess,tempfile,shutil,re,json
stage=Path(__file__).resolve().parents[1]
tmp=Path(tempfile.mkdtemp(prefix='qs-notif-regression-'))
for d in ['src/ui','src/core/config','config','src/features/notifications']:
 shutil.copytree(stage/d,tmp/d)
srv=tmp/'src/core/services';srv.mkdir();shutil.copy(stage/'src/core/services/NotificationHistory.qml',srv/'NotificationHistory.qml')
shutil.copy(stage/'src/core/services/NotificationRateLimiter.qml',srv/'NotificationRateLimiter.qml')
(srv/'qmldir').write_text('singleton NotificationHistory 1.0 NotificationHistory.qml\nsingleton NotificationService 1.0 NotificationService.qml\nsingleton DateTime 1.0 DateTime.qml\nsingleton NotificationRateLimiter 1.0 NotificationRateLimiter.qml\n')
(srv/'DateTime.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject {property var clock: ({date:new Date()})}')
(srv/'NotificationService.qml').write_text('''pragma Singleton
import QtQuick
QtObject {
 property var historyList: NotificationHistory.historyList
 function isLive(i) {return false}
 function removeFromHistory(i) {NotificationHistory.remove(i)}
 function removeGroupFromHistory(n) {NotificationHistory.removeGroup(n)}
 function invokeActionFromHistory(i,a) {}
 function isGroupExpanded(n) {return NotificationHistory.isGroupExpanded(n)}
 function toggleGroupExpanded(n) {NotificationHistory.toggleGroupExpanded(n)}
 function getGroupCount(n) {return NotificationHistory.getGroupCount(n)}
 function getGroupIcon(n) {return NotificationHistory.getGroupIcon(n)}
 function markAllRead() {NotificationHistory.markAllRead()}
 function clearHistory() {return NotificationHistory.clearUndoable()}
 function undoClearHistory() {return NotificationHistory.undoClear()}
 function refreshClearUndo() {NotificationHistory.refreshUndo()}
 readonly property bool canUndoClear:NotificationHistory.canUndoClear
 readonly property bool historyClearing:NotificationHistory.clearing
 readonly property bool historyRestoring:NotificationHistory.restoring
 readonly property int clearedHistoryCount:NotificationHistory.undoCount
 property bool doNotDisturb:false
 function toggleDoNotDisturb() {doNotDisturb=!doNotDisturb}
}''')
s=(stage/'src/features/notifications/NotificationCenter.qml').read_text();block=s[s.index('                        ListView {'):s.index('\n\n                        EmptyState')]
nav=s[s.index('            property string _selectedEntryId:'):s.index('\n\n            Keys.onPressed:')]
qml='''pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import qs.src.core.config
import qs.src.core.services
import qs.src.ui.base
import qs.src.ui.containers
import qs.src.ui.feedback
import qs.src.features.notifications
Window {
 id:win; width:430;height:750;visible:true
 property var centerWindow:win
 property int step:0
 property string collapsedId:""
 property int errors:0
 property string selectedId:""
 Item {id:panelSlide
'''+nav+'''
 }
 function makeRow(i) {return {notificationId:String(i),notifId:0,summary:"Long notification headline "+i,body:("Text of notification for wrapping. ").repeat(i%8+2),appName:"App"+Math.floor(i/3),appIcon:"",image:"",urgency:1,timestamp:Date.now(),count:1,unread:true,expireTimeout:7000,actions:[{identifier:"a",text:"Long action number one"},{identifier:"b",text:"Second action"},{identifier:"c",text:"Third"}]}}
 function indexOf(id) {for(let i=0;i<NotificationHistory.historyList.count;i++) if(NotificationHistory.historyList.get(i).notificationId===id)return i;return -1}
 function unreadMatches() {let n=0;for(let i=0;i<NotificationHistory.historyList.count;i++)if(NotificationHistory.historyList.get(i).unread)n++;return n===NotificationHistory.unreadCount}
 function setOptions(fields) {AppConfig.data=Object.assign({},AppConfig.data,{notifications:Object.assign({},AppConfig.data.notifications,fields)})}
 function check(ok,msg) {if(!ok){errors++;console.warn("FAIL "+msg)}}
 function geometry() {
  let rows=[]
  for(let i=0;i<notifList.count;i++) {
   const row=notifList.itemAtIndex(i);if(!row||!row.visible)continue
   const card=row.children.find(x=>String(x).includes("NotificationHistoryItem"));if(!card)continue
   const layout=card.contentItem.children.find(x=>String(x).includes("QQuickColumnLayout"))
   check(card.height+.1>=card.implicitHeight,"card clipping at step "+step)
   for(const child of layout.children)if(child.visible&&child.contentHeight!==undefined) check(child.height+.1>=child.contentHeight,"text clipping at step "+step)
   rows.push({i,y:row.y,h:row.height})
  }
  if(win.visible) check(rows.length>0,"no delegates checked")
  rows.sort((a,b)=>a.i-b.i)
  for(let j=1;j<rows.length;j++) if(rows[j].i===rows[j-1].i+1)check(rows[j-1].y+rows[j-1].h<=rows[j].y+.1,"overlap at step "+step+" indices "+rows[j-1].i+","+rows[j].i)
  console.warn("PASS geometry step "+step+" delegates "+rows.length)
 }
'''+block+'''
 Timer {interval:400;repeat:true;running:true;onTriggered:{
  const m=NotificationHistory.historyList
  if(win.step===0) {check(m.count===500,"startup configured cap");setOptions({maxHistory:200});check(m.count===200,"cap reduction");NotificationHistory.clear();for(let i=0;i<45;i++)NotificationHistory.add(makeRow(i)); win.step++;return}
  if(win.step<=10) win.geometry()
  if(win.step===1) {check(m.count===45,"history fixture did not load");collapsedId=m.get(0).notificationId;NotificationHistory.setEntryExpanded(collapsedId,false);notifList.positionViewAtIndex(25,ListView.Beginning)}
  if(win.step===2) notifList.positionViewAtBeginning()
  if(win.step===3) {
   const card=notifList.itemAtIndex(0)?.children.find(x=>String(x).includes("NotificationHistoryItem"))
   check(card && !card.expanded,"entry expansion lost after scrolling")
   NotificationHistory.setEntryExpanded(collapsedId,true)
   m.setProperty(1,"body",("An updated lengthy paragraph. ").repeat(65))
  }
  if(win.step===4) win.width=340
  if(win.step===5) {
   win.width=430
   const name=m.get(0).appName
   NotificationHistory.toggleGroupExpanded(name)
   panelSlide._selectIndex(-1,false);panelSlide._moveCursor(1)
   check(notifList.currentIndex===0,"collapsed header not selected")
   panelSlide._moveCursor(1)
   check(notifList.currentIndex===3,"hidden children selected")
   panelSlide._moveCursor(-1)
   check(notifList.currentIndex===0,"cannot return to collapsed header")
  }
  if(win.step===6) {NotificationHistory.toggleGroupExpanded(m.get(0).appName); selectedId=panelSlide._selectedEntryId;NotificationHistory.add(makeRow(99))}
  if(win.step===7) {
   check(m.get(notifList.currentIndex).notificationId===selectedId,"selection moved to another notification after insertion")
   m.setProperty(1,"image",win.testImage)
   NotificationHistory.update(m.get(0).notificationId,{actions:[{identifier:"updated",text:"A replacement action label"}]})
   check(NotificationHistory.actionsAt(0).length===1 && NotificationHistory.actionsAt(0)[0].identifier==="updated","replacement actions not updated")
  }
  if(win.step===8) {
   const row=notifList.itemAtIndex(1)
   const card=row?.children.find(x=>String(x).includes("NotificationHistoryItem"))
   const layout=card?.contentItem.children.find(x=>String(x).includes("QQuickColumnLayout"))
   const holder=layout?.children.find(x=>x.imageSource!==undefined)
   check(holder && holder.height>0 && holder.children[0].status===Image.Ready,"async image did not expand")
   win.visible=false
  }
  if(win.step===9) win.visible=true
  if(win.step===10) {NotificationHistory.setEntryExpanded(collapsedId,false);NotificationHistory.remove(collapsedId);check(NotificationHistory._collapsedEntries[collapsedId]===undefined,"stale expansion state")}
  if(win.step===11) {
   check(unreadMatches(),"unread before clear")
   check(NotificationHistory.clearUndoable(),"clear starts")
   NotificationHistory.add(makeRow(900))
   check(NotificationHistory.undoClear(),"undo accepted during batched clear")
  }
  if(win.step===12) {
   check(m.count===46 && m.get(0).notificationId==="900","new arrival retained above restored rows")
   check(unreadMatches(),"unread after restore")
   check(NotificationHistory.actionsAt(indexOf("99"))[0].identifier==="updated","nested actions restored")
   NotificationHistory.clearUndoable()
   NotificationHistory.update("99",{summary:"Changed while cleared",actions:[{identifier:"pending",text:"Updated pending action"}]})
   NotificationHistory._undoEntries.find(entry=>entry.notificationId==="99").image="image://qsimage/closed-test"
   NotificationHistory.tagCloseReason("99",1)
   NotificationHistory.markAllRead()
   NotificationHistory.add(makeRow(901))
   NotificationHistory.undoClear()
  }
  if(win.step===13) {
   check(m.count===47,"second undo merges once")
   check(m.get(indexOf("99")).image==="","closed transient image is not restored")
   check(m.get(indexOf("99")).summary==="Changed while cleared" && m.get(indexOf("99")).closeReason===1,"pending metadata follows replacement and close")
   check(NotificationHistory.actionsAt(indexOf("99"))[0].identifier==="pending","pending nested actions updated")
   check(NotificationHistory.unreadCount===1 && unreadMatches(),"closing centre marks pending records read")
   setOptions({maxHistory:20})
  }
  if(win.step===14) {
   check(m.count===20 && unreadMatches(),"hot-reload cap")
   NotificationHistory.clearUndoable();NotificationHistory.add(makeRow(1000));NotificationHistory.undoClear()
  }
  if(win.step===15) {
   check(m.count===20 && m.get(0).notificationId==="1000","restore respects cap and keeps new arrival")
   check(unreadMatches(),"bounded restore unread")
   NotificationHistory.clearUndoable();NotificationHistory.clear();NotificationHistory.add(makeRow(1400))
   check(!NotificationHistory.canUndoClear,"explicit permanent clear invalidates undo")
  }
  if(win.step===16) {
   check(m.count===1 && m.get(0).notificationId==="1400","permanent clear preserves concurrent arrival")
   NotificationHistory.clearUndoable();NotificationHistory._undoDeadline=Date.now()-1;NotificationHistory.refreshUndo()
   check(!NotificationHistory.canUndoClear && !NotificationHistory.undoClear(),"expired undo is rejected")
   const old=makeRow(1500);old.timestamp=Date.now()-86400000*40
   NotificationHistory.add(old);NotificationHistory.clearUndoable();setOptions({historyTTLDays:1});NotificationHistory.undoClear()
  }
  if(win.step===17) {
   check(m.count===0,"TTL prevents resurrection")
   NotificationHistory.add(makeRow(2001));NotificationHistory.add(makeRow(2002));NotificationHistory.clearUndoable()
   NotificationHistory._undoEntries[0].image="image://qsimage/test-only"
   NotificationHistory._undoEntries[0].notifId=123
   NotificationHistory._persist()
  }
  if(win.step===18) {console.warn("RESULT errors="+errors);Qt.quit()}
  win.step++
 }}
 property string testImage: "file://IMAGE_PATH"
}'''
# A local PNG with known dimensions, decoded asynchronously by the real item.
import struct,zlib
w,h=640,360
raw=b''.join(b'\0'+b'\x80\x80\x80'*w for _ in range(h))
def chunk(k,v):return struct.pack('!I',len(v))+k+v+struct.pack('!I',zlib.crc32(k+v)&0xffffffff)
img=tmp/'image.png';img.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('!2I5B',w,h,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(raw))+chunk(b'IEND',b''))
qml=qml.replace('IMAGE_PATH',str(img));(tmp/'shell.qml').write_text(qml)
userconfig=tmp/'config-home/quickshell'
userconfig.mkdir(parents=True)
initial_config=json.loads((tmp/'config/default.json').read_text());initial_config['notifications']['maxHistory']=500
(userconfig/'config.json').write_text(json.dumps(initial_config))
(userconfig/'state.json').write_text('{}')
import time
seeds=[dict(notificationId='seed:'+str(i),summary='Seed',body='',appName='Seed',timestamp=time.time()*1000+i,urgency=1,unread=True,actions=[]) for i in range(600)]
(userconfig/'notification-history.json').write_text(json.dumps({'notifications':seeds}))
env=dict(os.environ,QT_QPA_PLATFORM='offscreen',XDG_CONFIG_HOME=str(tmp/'config-home'),XDG_CACHE_HOME=str(tmp/'cache-home'),XDG_RUNTIME_DIR=os.environ.get('XDG_RUNTIME_DIR', '/run/user/'+str(os.getuid())),QSG_RHI_BACKEND='software')
r=subprocess.run(['timeout','20','qs','-p',str(tmp/'shell.qml')],env=env,capture_output=True,text=True)
(tmp/'output.txt').write_text(r.stdout+r.stderr)
output=r.stdout+r.stderr
print(output)
if not (r.returncode==0 and 'RESULT errors=0' in output and not re.search(r'\bFAIL |Error:|Binding loop|polish loop',output)):
 shutil.rmtree(tmp);raise SystemExit(1)
saved=json.loads((userconfig/'notification-history.json').read_text())
assert len(saved['undoEntries'])==2 and not saved['notifications']
print('Saved undo entries/deadline:',len(saved['undoEntries']),saved['undoDeadline'])
assert all(row['notifId']==0 and not row.get('image','').startswith('image://qsimage/') for row in saved['undoEntries'])
restart=tmp/'restart.qml'
restart.write_text('''import QtQuick
import Quickshell
import qs.src.core.services
Scope {
 property int step:0
 function check(ok,message) {if(!ok){console.warn("FAIL "+message);Qt.exit(1);throw new Error(message)}}
 Timer {interval:300;running:true;repeat:true;onTriggered:{
  if(parent.step===0) {
   if (!NotificationHistory._loadDone) return
   parent.check(NotificationHistory.canUndoClear,"restart recovers pending clear: entries="+NotificationHistory._undoEntries.length+" deadline="+NotificationHistory._undoDeadline+" now="+Date.now())
   parent.check(NotificationHistory.historyList.count===0,"restart hides cleared entries")
   parent.check(NotificationHistory.undoClear(),"restart undo")
  } else if(parent.step===1) {
   parent.check(NotificationHistory.historyList.count===2 && NotificationHistory.unreadCount===2,"restart restores records and unread")
   parent.check(!NotificationHistory.canUndoClear && !NotificationHistory.restoring,"restore ends")
  } else {console.warn("RESTART PASS");Qt.quit()}
  parent.step++
 }}
}
''')
r=subprocess.run(['timeout','10','qs','-p',str(restart)],env=env,capture_output=True,text=True)
output=r.stdout+r.stderr;print(output)
passed=r.returncode==0 and 'RESTART PASS' in output and not re.search(r'\bFAIL |Error:|Binding loop',output)
if not passed:
 shutil.rmtree(tmp);raise SystemExit(1)
# Exercise the actual centre window without a focus grab or input region.
(srv/'qmldir').write_text((srv/'qmldir').read_text()+'singleton GlobalStates 1.0 GlobalStates.qml\nsingleton NotificationDND 1.0 NotificationDND.qml\n')
(srv/'GlobalStates.qml').write_text('pragma Singleton\nimport QtQuick\nimport Quickshell\nQtObject {property bool notificationCenterOpen:true;property ShellScreen activePanelScreen:Quickshell.screens[0] ?? null;signal panelOpened(string name);function closePanel(name) {notificationCenterOpen=false}}\n')
(srv/'NotificationDND.qml').write_text('pragma Singleton\nimport QtQml\nQtObject {property bool enabled:false;property bool active:false}\n')
source=(stage/'src/features/notifications/NotificationCenter.qml').read_text()
source=source.replace('import QtQuick\n','import QtQuick\nimport qs.src.features.notifications\n',1)
start=source.index('        HyprlandFocusGrab {');level=0
for index in range(source.index('{',start),len(source)):
 if source[index]=='{':level+=1
 elif source[index]=='}':level-=1
 if level==0:source=source[:start]+source[index+1:];break
source=source.replace('Scope {','Scope {\n    readonly property PanelWindow window: centerWindow\n    readonly property Item panel: panelSlide\n    readonly property Item header: titleLabel.parent\n    readonly property Item controls: headerActions\n    readonly property Item clearAction: clearButton\n    readonly property Item notice: undoNotice',1)
source=source.replace('        color: "transparent"','        contentItem.opacity: 0\n        mask: Region {}\n        color: "transparent"',1).replace('focusable: true','focusable: false').replace('WlrKeyboardFocus.OnDemand','WlrKeyboardFocus.None').replace('quickshell:notification-center','shell:test:notification-center')
(tmp/'NativeCenter.qml').write_text(source)
probe=tmp/'center-probe.qml'
probe.write_text('''import QtQuick
import Quickshell
import qs.src.core.config
import qs.src.core.services
Scope {
 id:root
 property int step:0
 property int index:0
 property int ticks:0
 property int accepted:0
 property int dropped:0
 property int popups:0
 property int popupDropped:0
 property var cases:[]
 NativeCenter {id:center}
 Connections {target:NotificationRateLimiter
  function onIngressAccepted(notification) {root.accepted++}
  function onIngressDropped(notification) {root.dropped++}
  function onPopupReady(notification,data) {root.popups++}
  function onPopupDropped(notification) {root.popupDropped++}
 }
 function check(ok,message) {if(!ok){console.warn("FAIL "+message);Qt.exit(1);throw new Error(message)}}
 function applyCase(entry) {
  AppConfig.data=Object.assign({},AppConfig.data,{appearance:Object.assign({},AppConfig.data.appearance,{designSystem:entry.pack,fontScale:entry.scale}),notifications:Object.assign({},AppConfig.data.notifications,{panel:Object.assign({},AppConfig.data.notifications.panel,{width:entry.width})})})
 }
 Component.onCompleted: {
  for(const pack of ["minimal","md3"])for(const scale of [1,1.3,2])for(const width of [280,400])cases.push({pack:pack,scale:scale,width:width})
 }
 Timer {interval:100;repeat:true;running:true;onTriggered:{
  root.check(++root.ticks<100,"native centre deadline")
  if(root.step===0) {
   if(!NotificationHistory._loadDone || !center.window.visible) return
   for(let i=0;i<100;i++){NotificationRateLimiter.ingest({id:i,urgency:1});NotificationRateLimiter.popupShow({id:i,urgency:1},{})}
   root.check(root.accepted===AppConfig.notificationIngressPerSecond && NotificationRateLimiter._ingressQueue.length===AppConfig.notificationMaxQueue,"ingress cap")
   root.check(root.dropped===100-root.accepted-AppConfig.notificationMaxQueue,"ingress overflow verdicts")
   root.check(root.popups===1 && NotificationRateLimiter._gateQueue.length===AppConfig.notificationMaxPopupQueue,"popup queue cap")
   NotificationRateLimiter.ingest({id:101,urgency:2});root.check(root.accepted===AppConfig.notificationIngressPerSecond+1,"critical admission bypass")
   NotificationRateLimiter._tokens=20
   AppConfig.data=Object.assign({},AppConfig.data,{notifications:Object.assign({},AppConfig.data.notifications,{rateLimit:Object.assign({},AppConfig.data.notifications.rateLimit,{ingressPerSecond:5,maxQueue:4,maxPopupQueue:2})})})
   root.check(NotificationRateLimiter._tokens===5 && NotificationRateLimiter._ingressQueue.length===4 && NotificationRateLimiter._gateQueue.length===2,"hot reload tightens all limits")
   center.clearAction.clicked();root.check(NotificationHistory.canUndoClear,"centre Clear all enables undo")
   root.applyCase(root.cases[0]);root.step=1;return
  }
  if(root.step===1) {root.step=2;return}
  if(root.step===2) {
   root.check(center.panel.width<=center.window.width,"panel width bounded")
   root.check(center.header.width<=center.panel.width,"header fits")
   for(const child of center.controls.children) if(child.visible)root.check(child.x>=0 && child.x+child.width<=center.controls.width+1,"header action fits")
   root.check(center.notice.visible && center.notice.width<=center.panel.width,"undo notice visible and bounded")
   if(++root.index<root.cases.length){root.applyCase(root.cases[root.index]);root.step=1;return}
   center.notice.actionClicked();root.step=3;return
  }
  if(root.step===3) {
   if(NotificationHistory.restoring)return
   root.check(NotificationHistory.historyList.count===2 && !NotificationHistory.canUndoClear,"native centre Undo restores")
   GlobalStates.closePanel("notificationCenter");console.warn("CENTRE PASS");Qt.quit()
  }
 }}
}
''')
display=os.environ.get('WAYLAND_DISPLAY','')
if display and (Path(env['XDG_RUNTIME_DIR'])/display).is_socket():
 native_env=dict(env,QT_QPA_PLATFORM='wayland',QT_QUICK_BACKEND='software');native_env.pop('QSG_RHI_BACKEND',None)
 r=subprocess.run(['timeout','15','qs','-p',str(probe)],env=native_env,capture_output=True,text=True)
 output=r.stdout+r.stderr;print(output)
 passed=r.returncode==0 and 'CENTRE PASS' in output and not re.search(r'\bFAIL |Error:|Binding loop|polish loop|rearrange|Unable to assign',output)
else: print('Native centre skipped: no Wayland display')
shutil.rmtree(tmp)
raise SystemExit(0 if passed else 1)
