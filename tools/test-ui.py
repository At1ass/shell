#!/usr/bin/env python3
"""Check shared controls with real Qt key events; render both design packs."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile
import re

ROOT = Path(__file__).resolve().parents[1]
RENDERS = Path('/tmp/shell-ui-renders')
RENDERS.mkdir(exist_ok=True)

with tempfile.TemporaryDirectory(prefix='shell-ui-test-') as temp:
    temp = Path(temp)
    tree = temp / 'imports/qs'
    shutil.copytree(ROOT / 'src/ui', tree / 'src/ui')
    config = tree / 'src/core/config'
    config.mkdir(parents=True)
    for name in ['Tokens.qml', 'Keycodes.qml', 'Theme.qml', 'BarMetrics.qml']:
        shutil.copy2(ROOT / 'src/core/config' / name, config / name)
    (config / 'qmldir').write_text('module qs.src.core.config\n' + '\n'.join(
        f'singleton {name} 1.0 {name}.qml' for name in ['Tokens', 'Keycodes', 'Theme', 'BarMetrics', 'AppConfig']) + '\n')
    (config / 'AppConfig.qml').write_text('''pragma Singleton
import QtQml
QtObject {
 property string designSystem: "minimal"
 property real fontScale: 1.3
 property string fontFamily: ""
 property string monoFamily: ""
 property bool darkMode: true
 property string themeVariant: "tonalspot"
 property real themeContrast: 0
 property bool reduceMotion: true
 property real panelOpacity: 1
 property real motionScale: 1
 property var disabledModules:[]
 property bool ready:true
 property bool stateReady:false
 property bool dockAutoHide:false
 property bool dockExclusive:false
 property string dockPosition:"bottom"
 property int dockIconSize:48
 property var dockPinnedApps:[]
 function shouldShowOnMonitor(widget,screen) {return !widget.monitors || widget.monitors.length===0 || widget.monitors.includes(screen)}
 function barWidgetPriority(widget) {return widget?.priority ?? ({clock:100,workspaces:90,battery:85,volume:80,network:75,notifications:70,layout:60,tray:50,media:40,weather:30,activewindow:20})[widget?.type] ?? 50}
 function moduleEnabled(name) {return !disabledModules.includes(name)}
 function panelKeptLoaded(name) {return false}
 property var data:({})
 property var stateData:({})
 property var temporaryModeDurations:[15,30,60,120]
 property bool lockscreenBlurWallpaper:true
 property bool lockscreenShowClock:true
 property bool lockscreenShowDate:true
 property bool lockscreenShowUsername:true
 property bool lockscreenShowWeather:false
 property bool lockscreenShowBattery:true
 property bool lockscreenShowNetwork:false
 property bool lockscreenShowPower:true
 property bool lockscreenShowMedia:true
 property bool lockscreenMediaShowPaused:true
 property bool lockscreenMediaShowArt:false
 property bool weatherEnabled:true
 property string osdMonitorPolicy:"focused"
 property int osdTimeout:500
 property int launcherWidth:600
 property int launcherTopMargin:56
 property int launcherMaxResults:10
 property int launcherListMaxHeight:400
 property int audioWidth:420
 property int audioMaxHeight:640
 property string barPosition:"top"
 property real storageWarningFreePercent:10
 property real storageCriticalFreePercent:5
 property var storageExcludedMounts:["/boot","/boot/efi","/efi"]
 property var storageOrder:["/","/home"]
 property var storageLabels:({})
 property int barHeight:38
 property int connectionsWidth:420
 property int connectionsMaxHeight:640
 property int calendarFirstDayOfWeek: 1
 property int calendarDayViewHourHeight: 60
}
''')
    # The visual kit only needs Quickshell's QObject base. Mocking it lets
    # qmltestrunner drive real controls without registering desktop services.
    qs = temp / 'imports/Quickshell'
    qs.mkdir()
    (qs / 'qmldir').write_text('module Quickshell\nSingleton 1.0 Singleton.qml\nScriptModel 1.0 ScriptModel.qml\nsingleton Quickshell 1.0 Quickshell.qml\n')
    (qs / 'ScriptModel.qml').write_text('import QtQml.Models\nListModel {property var values:[];property string objectProp:"";dynamicRoles:true;onValuesChanged:{clear();for(const entry of values) append({modelData:entry})}}\n')
    (qs / 'Singleton.qml').write_text('import QtQml\nQtObject { default property list<QtObject> children }\n')
    (qs / 'Quickshell.qml').write_text('pragma Singleton\nimport QtQml\nQtObject {function env(name) {return "Test User"} function iconPath(name,fallback) {return ""}}\n')
    with (qs / 'qmldir').open('a') as module:
        module.write('ShellScreen 1.0 ShellScreen.qml\n')
    (qs / 'ShellScreen.qml').write_text('import QtQml\nQtObject {property string name:"";property int x:0;property int y:0;property int width:800;property int height:600}\n')
    (qs / 'Quickshell.qml').write_text('pragma Singleton\nimport QtQml\nQtObject {property string shellDir:"/tmp";property var screens:[];function env(name) {return "Test User"} function iconPath(name,fallback) {return ""}}\n')
    for module_name, types in {
        'Io': {'Process':'import QtQml\nQtObject {property bool running:false;property var command:[];property QtObject stdout:null;signal exited(int exitCode)}', 'StdioCollector':'import QtQml\nQtObject {property string text:"";signal streamFinished()}', 'IpcHandler':'import QtQml\nQtObject {property string target:""}'},
        'Hyprland': {'GlobalShortcut':'import QtQml\nQtObject {property string name:"";property string description:"";signal pressed()}', 'Hyprland':'pragma Singleton\nimport QtQml\nQtObject {property QtObject focusedMonitor:null;property QtObject focusedWorkspace:QtObject {property int id:1};property var toplevels:({values:[]})}'}
    }.items():
        module_dir = qs / module_name
        module_dir.mkdir()
        (module_dir / 'qmldir').write_text(f'module Quickshell.{module_name}\n' + ''.join(('singleton ' if name == 'Hyprland' else '') + f'{name} 1.0 {name}.qml\n' for name in types))
        for name, body in types.items():
            (module_dir / f'{name}.qml').write_text(body + '\n')
    (temp / 'TestPanelState.qml').write_text((ROOT / 'src/core/services/GlobalStates.qml').read_text().replace('pragma Singleton\n','').replace('import qs.src.core.config', 'import qs.src.core.services\nimport qs.src.core.config'))
    pipewire = qs / 'Services/Pipewire'
    pipewire.mkdir(parents=True)
    (pipewire / 'qmldir').write_text('module Quickshell.Services.Pipewire\nsingleton Pipewire 1.0 Pipewire.qml\nPwObjectTracker 1.0 PwObjectTracker.qml\n')
    (pipewire / 'Pipewire.qml').write_text('pragma Singleton\nimport QtQml\nQtObject {property QtObject defaultAudioSink:QtObject {property QtObject audio:QtObject {property real volume:0.5;property bool muted:false}}}\n')
    (pipewire / 'PwObjectTracker.qml').write_text('import QtQml\nQtObject {property var objects:[]}\n')
    lock = tree / 'src/features/lockscreen'
    lock.mkdir(parents=True)
    shutil.copy2(ROOT / 'src/features/lockscreen/LockContent.qml',lock / 'LockContent.qml')
    (lock / 'qmldir').write_text('module qs.src.features.lockscreen\nLockContent 1.0 LockContent.qml\n')
    bar = tree / 'src/features/statusbar'
    bar.mkdir(parents=True)
    bar_types = ['BarLayout','BarWidgetLoader','ActiveWindowWidget','WorkspaceWidget','NotificationWidget','NetworkWidget','LayoutWidget','BatteryWidget','ClockWidget','WeatherWidget','MPRISWidget','VolumeWidget','TrayWidget','TrayIcon','TrayModel']
    (bar / 'qmldir').write_text('module qs.src.features.statusbar\n' + ''.join(f'{name} 1.0 {name}.qml\n' for name in bar_types))
    for name in bar_types:
        shutil.copy2(ROOT / f'src/features/statusbar/{name}.qml',bar / f'{name}.qml')
    shutil.copy2(ROOT / 'src/features/statusbar/BarLayoutPolicy.js', bar / 'BarLayoutPolicy.js')
    (temp / 'TestBarOverflow.qml').write_text((ROOT / 'src/features/popouts/BarOverflow.qml').read_text())
    (temp / 'TestIpcData.qml').write_text((ROOT / 'src/features/cheatsheet/components/IpcReferenceData.qml').read_text().replace('pragma Singleton\n',''))
    dock = tree / 'src/features/dock'
    dock.mkdir(parents=True)
    # qmltestrunner does not install Quickshell's icon image provider.
    (dock / 'DockIcon.qml').write_text((ROOT / 'src/features/dock/DockIcon.qml').read_text().replace('"image://icon/application-x-executable"', '""'))
    shutil.copy2(ROOT / 'src/features/dock/DockTooltip.qml', dock / 'DockTooltip.qml')
    (dock / 'qmldir').write_text('module qs.src.features.dock\nDockIcon 1.0 DockIcon.qml\nDockTooltip 1.0 DockTooltip.qml\n')
    # Deterministic preview content; the real native coordinator probe still uses
    # Quickshell's own Wayland module after the Qt-only mocks are removed.
    wayland_mock=qs / 'Wayland'
    wayland_mock.mkdir()
    (wayland_mock / 'qmldir').write_text('module Quickshell.Wayland\nScreencopyView 1.0 ScreencopyView.qml\n')
    (wayland_mock / 'ScreencopyView.qml').write_text('import QtQuick\nItem {property QtObject captureSource:null;property bool live:false;property bool hasContent:true;property size constraintSize:Qt.size(280,180);implicitWidth:Math.min(280,constraintSize.width);implicitHeight:constraintSize.height}\n')
    for name in ['DockPreview','DockContextMenu']:
        (dock / (name+'.qml')).write_text((ROOT / ('src/features/dock/'+name+'.qml')).read_text().replace('"image://icon/application-x-executable"', '""'))
        with (dock / 'qmldir').open('a') as module:module.write(name+' 1.0 '+name+'.qml\n')
    launcher = tree / 'src/features/launcher/components'
    launcher.mkdir(parents=True)
    shutil.copy2(ROOT / 'src/features/launcher/components/AppListItem.qml', launcher / 'AppListItem.qml')
    (launcher / 'qmldir').write_text('module qs.src.features.launcher.components\nAppListItem 1.0 AppListItem.qml\n')
    shutil.copy2(ROOT / 'src/features/launcher/LauncherContent.qml', launcher.parent / 'LauncherContent.qml')
    (launcher.parent / 'qmldir').write_text('module qs.src.features.launcher\nLauncherContent 1.0 LauncherContent.qml\n')
    osd = tree / 'src/features/osd'
    shutil.copytree(ROOT / 'src/features/osd', osd)
    provider_module = tree / 'src/core/services/launcher'
    shutil.copytree(ROOT / 'src/core/services/launcher', provider_module)
    (provider_module / 'ApplicationProvider.qml').write_text('''import QtQuick
import qs.src.core.services
BaseProvider {
 name:"Applications";priority:50
 function search(query) {
  if(query==="none") return []
  const result=[]
  for(let i=0;i<12;i++) result.push(makeResult(query || "Editor",i))
  return result
 }
 function makeResult(name,index) {return {id:"app:"+name+":"+index,type:"application",text:name+" "+index,description:"Open editor",icon:"",action:()=>GlobalStates.handleClickAction("app:"+name+":"+index)}}
 function defaultResults() {return search("")}
}
''')
    qalculate = temp / 'imports/Qalculate'
    qalculate.mkdir()
    (qalculate / 'qmldir').write_text('module Qalculate\nsingleton QalculateWrapper 1.0 QalculateWrapper.qml\n')
    (qalculate / 'QalculateWrapper.qml').write_text('pragma Singleton\nimport QtQml\nQtObject {property string lastExpression:"";signal evaluated(string expression,string result);function evalAsync(expression,units) {lastExpression=expression}}\n')
    dashboard = tree / 'src/features/dashboard'
    (dashboard / 'tabs').mkdir(parents=True)
    shutil.copy2(ROOT / 'src/features/dashboard/DashboardContent.qml', dashboard / 'DashboardContent.qml')
    (dashboard / 'qmldir').write_text('module qs.src.features.dashboard\nDashboardContent 1.0 DashboardContent.qml\n')
    shutil.copytree(ROOT / 'src/features/dashboard/components/maintab_elements', dashboard / 'components/maintab_elements')
    names = ['QuickTab', 'WeatherTab', 'CalendarTab']
    (dashboard / 'tabs/qmldir').write_text('module qs.src.features.dashboard.tabs\n' +
        ''.join(f'{name} 1.0 {name}.qml\n' for name in names))
    shutil.copy2(ROOT / 'src/features/dashboard/tabs/QuickTab.qml', dashboard / 'tabs/QuickTab.qml')
    shutil.copytree(ROOT / 'src/features/dashboard/components/weathertab_elements', dashboard / 'components/weathertab_elements')
    shutil.copy2(ROOT / 'src/features/dashboard/tabs/CalendarTab.qml', dashboard / 'tabs/CalendarTab.qml')
    shutil.copy2(ROOT / 'src/features/dashboard/tabs/WeatherTab.qml', dashboard / 'tabs/WeatherTab.qml')
    connections = tree / 'src/features/connections'
    connections.mkdir(parents=True)
    for name in ['ConnectionsContent', 'ConnectionHeader', 'ConnectionRow', 'BluetoothPairingDialog', 'NetworkAuthenticationDialog']:
        shutil.copy2(ROOT / f'src/features/connections/{name}.qml', connections / f'{name}.qml')
    (connections / 'qmldir').write_text('module qs.src.features.connections\nConnectionsContent 1.0 ConnectionsContent.qml\nConnectionHeader 1.0 ConnectionHeader.qml\nConnectionRow 1.0 ConnectionRow.qml\nBluetoothPairingDialog 1.0 BluetoothPairingDialog.qml\nNetworkAuthenticationDialog 1.0 NetworkAuthenticationDialog.qml\n')
    (dashboard / 'components/qmldir').write_text('module qs.src.features.dashboard.components\n')
    networking = temp / 'imports/Quickshell/Networking'
    networking.mkdir()
    (networking / 'qmldir').write_text('module Quickshell.Networking\nWifiSecurityType 1.0 WifiSecurityType.qml\nWifiNetwork 1.0 WifiNetwork.qml\n')
    (networking / 'WifiSecurityType.qml').write_text('import QtQml\nQtObject {enum Security {Open, Wpa2Psk, Sae, WpaPsk, StaticWep, Owe, Wpa2Eap}}\n')
    (networking / 'WifiNetwork.qml').write_text('import QtQml\nQtObject {property string name:"Test Wi-Fi";property bool connected:false;property bool known:false;property int security:1;property bool stateChanging:false;property real signalStrength:0.8}\n')
    shutil.copy2(ROOT / 'src/features/dashboard/tabs/CalendarTab.qml', temp / 'TestCalendar.qml')
    shutil.copy2(ROOT / 'src/features/dashboard/components/EventDialog.qml', temp / 'TestEventDialog.qml')
    shutil.copy2(ROOT / 'src/features/dashboard/components/RecurrenceEditChoice.qml', dashboard / 'components/RecurrenceEditChoice.qml')
    with (dashboard / 'components/qmldir').open('a') as module:
        module.write('EventDialog 1.0 EventDialog.qml\nRecurrenceEditChoice 1.0 RecurrenceEditChoice.qml\n')
    (dashboard / 'components/EventDialog.qml').write_text('''import QtQuick
import qs.src.ui.feedback
import qs.src.ui.base
Dialog {
 property bool isEditMode:false
 property var eventData:null
 signal eventSaved(var fields)
 signal eventDeleted(string uid,bool isRecurring)
 function requestClose() {close()}
 function openDialog(edit,event,date,fields) {isEditMode=edit;eventData=event;open()}
 MaterialButton {text:"Close test editor";onClicked:close()}
}
''')
    calendar = temp / 'imports/Calendar'
    calendar.mkdir()
    (calendar / 'qmldir').write_text('module Calendar\nsingleton CalendarBackend 1.0 CalendarBackend.qml\n')
    (calendar / 'CalendarBackend.qml').write_text('''pragma Singleton
import QtQml
QtObject {
 property var calendars:[{name:"Test"}]
 property var dayEvents:[]
 property var eventsByDate:({})
 function loadEventsForDate(date) {}
 function loadEventsForRange(start,end) {}
 function addEvent(fields) {}
 function editEvent(uid,fields,scope,start,id) {}
 function deleteEvent(uid,scope,start,id) {}
}
''')
    audio_module = tree / 'src/features/audio'
    audio_module.mkdir(parents=True)
    audio_types = ['AudioContent','AudioLevel','AudioStreamRow','AudioDevicePicker']
    (audio_module / 'qmldir').write_text('module qs.src.features.audio\n' + ''.join(f'{name} 1.0 {name}.qml\n' for name in audio_types))
    for name in audio_types:
        shutil.copy2(ROOT / f'src/features/audio/{name}.qml',audio_module / f'{name}.qml')
    shutil.copy2(ROOT / 'src/features/popouts/TrayOverflow.qml',temp / 'TestTrayOverflow.qml')
    (pipewire / 'qmldir').write_text((pipewire / 'qmldir').read_text()+'PwNode 1.0 PwNode.qml\n')
    (pipewire / 'PwNode.qml').write_text('import QtQml\nQtObject {property int id:1;property string name:"Speakers";property string description:name;property var properties:({});property QtObject audio:QtObject {property real volume:0.5;property bool muted:false}}\n')
    tray = qs / 'Services/SystemTray'
    tray.mkdir()
    (tray / 'qmldir').write_text('module Quickshell.Services.SystemTray\nsingleton SystemTray 1.0 SystemTray.qml\nSystemTrayItem 1.0 SystemTrayItem.qml\nStatus 1.0 Status.qml\n')
    (tray / 'Status.qml').write_text('import QtQml\nQtObject {enum Enum {Passive,Active,NeedsAttention}}\n')
    (tray / 'SystemTray.qml').write_text('pragma Singleton\nimport QtQml\nQtObject {property var items:({values:[]})}\n')
    (tray / 'SystemTrayItem.qml').write_text('''import QtQml
QtObject {
 property string id:"app"
 property string title:id
 property string tooltipTitle:""
 property string icon:""
 property int status:1
 property bool onlyMenu:false
 property bool hasMenu:true
 property QtObject menu:QtObject {}
 property int activations:0
 property int secondaryActivations:0
 property int scrollSteps:0
 function activate() {activations++}
 function secondaryActivate() {secondaryActivations++}
 function scroll(steps,horizontal) {scrollSteps+=steps}
}
''')
    services = tree / 'src/core/services'
    services.mkdir(exist_ok=True)
    mocks = {
        'GlobalStates': 'property int dashboardOpenIndex:0; property bool dashboardOpen:true; property bool launcherOpen:false; function closePanel(name) {}',
        'Weather': 'property string location:"Helsinki"; property string errorString:""; property real tempC:8; property real feelsLikeC:6; property int humidity:70; property real pressure:1009; property real windSpeed:12; property string windUnit:"km/h"; property string tempUnit:"°C"; property string icon:"cloud"; property string weatherDesc:"Cloudy"; property var dailySunrise:["2026-10-25T08:15"]; property var dailySunset:["2026-10-25T17:40"]; property var dailyTime:["2026-10-25","2026-10-26","2026-10-27","2026-10-28","2026-10-29","2026-10-30","2026-10-31"]; property var dailyTempMax:[8,9,7,8,6,5,7]; property var dailyTempMin:[2,3,1,2,1,-2,-1]; property var dailyWeatherCode:[0,0,0,0,0,0,0]; property var dailyPrecipProbMax:[0,10,30,10,0,10,0]',
        'WeatherIcons': 'property var codeToName:({0:"sunny"})',
        'DateTime': 'property QtObject clock:QtObject {property date date:new Date(2026,9,25,14,30)}',
        'AudioService': 'property bool masterMuted:false; property real masterVolume:0.45; property QtObject defaultSink:QtObject {}; function setMasterVolume(value) {masterVolume=value}; function toggleMasterMute() {masterMuted=!masterMuted}',
        'BrightnessService': 'property bool available:true; property real brightness:0.7; function setBrightness(value) {}',
        'NetworkService': 'property bool wifiEnabled:true; property string icon:"wifi"; function toggleWifi() {wifiEnabled=!wifiEnabled}',
        'BluetoothService': 'property bool enabled:true; property string icon:"bluetooth"; function toggle() {enabled=!enabled}',
        'VPNService': 'property bool connected:false; property string icon:"vpn_lock"; function toggle() {}',
        'IdleInhibitorService': 'property bool inhibit:false;property bool temporary:false;property string statusText:"";property real expiresAt:0;property int lastDuration:0;function toggleInhibit() {inhibit=!inhibit} function setForMinutes(minutes) {lastDuration=minutes;return true}',
        'NightLightService': 'property bool enabled:false; function toggle() {}',
        'NotificationService': 'property int unreadCount:0;property bool doNotDisturb:false; function toggleDoNotDisturb() {}',
        'GamingModeService': 'property bool gamingModeActive:false; function toggleGamingMode() {}',
        'ScreenshotService': 'function takeScreenshotSwappy() {}',
        'SystemMonitorService': 'property real cpuUsage:12; property real gpuUsage:7; property real ramUsage:38; property real diskUsage:42; property bool hasCpuTemp:true; property bool hasGpuStats:true; property int cpuTemp:49; property int gpuTemp:45; property string ramUsed:"6.2"; property string diskUsed:"84G"; property var cpuHistory:[]; property var gpuHistory:[]; property var ramHistory:[]; property string cpuModel:"CPU"; property string gpuModel:"GPU"; property string ramTotal:"16"; property string diskTotal:"200G"',
        'MprisController': 'property QtObject activePlayer:QtObject {}; property var activeTrack:({title:"Focus session",artist:"Instrumental",artUrl:""}); property var availablePlayers:[]; property real length:240; property bool lengthSupported:true; property bool positionSupported:true; property real position:50; property bool canTogglePlaying:true; property bool canGoNext:true; property bool canGoPrevious:true; property bool canSeek:true; property bool loopEnabled:false; property bool loopSupported:true; property bool loopingTrack:false; property bool shuffle:false; property bool shuffleSupported:true; property real volume:0.5; property bool volumeSupported:true; property bool isPlaying:false; property string identity:"Player"; signal trackChanged(); function togglePlaying() {toggles++;isPlaying=!isPlaying}; function next() {}; function previous() {}; function setPosition(value) {}; function setVolume(value) {}; function toggleLoop() {}; function toggleShuffle() {}; function switchToPlayer(value) {}'
    }
    mocks['SystemMonitorService'] += ';property bool hasGpuTemp:true;property var cpuTempHistory:[0.4,0.6,0.5];property var gpuTempHistory:[0.4,0.6,0.5];property real loadAvg1:1.2;property real loadAvg5:0.8;property real loadAvg15:0.5;property real cpuFreqGHz:4.2;property bool hasDiskIo:true;property string diskReadFormatted:"12 KiB/s";property string diskWriteFormatted:"6 KiB/s"'
    mocks['SystemMonitorService'] += ';property bool storageAvailable:true;property var storageVolumes:[];property var storageDrives:[];property var storageSummary:({available:true,name:"System",availableFormatted:"100 GiB",severity:0});property int storageSeverity:storageSummary.severity ?? 0;property string storageFreeText:(storageSummary.availableFormatted ?? "—")+" free";property string storageAlertText:storageSeverity>0 ? "Low space · Games: 2 GiB free" : ""'
    mocks['DockService'] = 'signal appLaunched(string key);function launch(app) {} function activateOrCycle(app) {} function isPinned(value) {return false} function pin(value) {} function unpin(value) {} function closeApp(value) {}'
    mocks['SessionMonitor'] = 'signal lockRequested(); signal unlockRequested()'
    mocks['HyprlandDispatch'] = 'function exitCompositor() {}'
    mocks['GlobalStates'] += '; property bool audioOpen:true; property Item audioSource:null; function openAudio(source) {audioOpen=true;lastAction="audio";actionCount++} function toggleAudio(source) {audioOpen=!audioOpen;lastAction="audio";actionCount++}'
    mocks['PopoutsState'] = 'property bool open:false; property string name:""; property QtObject data:null;property Item sourceItem:null;property int epoch:0; function openPopout(name,data,source) {this.name=name;this.data=data;sourceItem=source;open=true;epoch++} function closePopout() {open=false;name="";data=null;epoch++}'
    mocks['AudioService'] += '; property real micVolume:0.5;property bool micMuted:false;function setMicVolume(value) {micVolume=value} function toggleMicMute() {micMuted=!micMuted} function setStreamVolume(node,value) {node.audio.volume=value} function toggleStreamMute(node) {node.audio.muted=!node.audio.muted}'
    mocks['Weather'] += '; property var data:({current:{temperature_2m:8}});property bool isFresh:true;property date lastSuccessAt:new Date(2026,9,25,12)'
    mocks['NightLightService'] += '; property bool available:true'
    mocks['MprisController'] += '; property int toggles:0'
    mocks['GlobalStates'] += '; property string lastAction:""; property int actionCount:0; function handleClickAction(action) {actionCount++;lastAction=action}'
    mocks['GlobalStates'] += '; property bool connectionsOpen:true; property string connectionsSection:"bluetooth"; function openConnections(section,source) {connectionsSection=section}'
    mocks['NetworkService'] += '; property bool wifiAvailable:true; property bool wifiHardwareEnabled:true; property bool deviceReady:true; readonly property bool wifiReady:wifiAvailable && wifiHardwareEnabled && wifiEnabled && deviceReady; property bool connectionPending:false; property bool newConnectionBusy:false; property string errorMessage:""; function clearError() {errorMessage=""} function openSettings() {} function forgetNetwork(network) {}'
    mocks['BluetoothService'] += '; property bool pairingPending:false; function cancelPairing() {} property QtObject adapter:QtObject {}; property string errorMessage:""; function openSettings() {} function forgetDevice(device) {}'
    mocks['BluetoothService'] += '; property string pairingToken:""; property string pairingKind:""; property string pairingName:""; property string pairingAddress:""; property string pairingCode:""; property string pairingUuid:""; property string pairingError:""; property int pairingEntered:0; function answerPairing(token,value) {pairingToken=""} function rejectPairing(token) {pairingToken=""}'
    mocks['VPNService'] += '; property bool enabled:true'
    mocks['AudioService'] += '; property var sinkNodes:[]; property var sourceNodes:[]; property var defaultSource:null; property var streamNodes:[]; function getAppIcon(node) {return \"\"} function formatVolume(value) {return \"0\"} function setDefaultSink(node) {defaultSink=node} function setDefaultSource(node) {defaultSource=node}'
    mocks['NetworkService'] += '; property string currentNetwork:""; property var networks:[]; readonly property var displayNetworks:networks; property bool scanning:false; function stopScan() {scanning=false} function startScan() {scanning=true} function securityText(value) {return "Open"} function signalIcon(value) {return "wifi"} property int disconnections:0; function disconnectNetwork(value) {disconnections++} function connectToNetwork(value) {connections++} property int connections:0; property QtObject passwordTarget:null; function connectToNewNetwork(network,password) {passwordTarget=network;connections++;return true}'
    mocks['BluetoothService'] += '; property int connectedDeviceCount:0; property var pairedDevices:[]; property var discoveredDevices:[]; property string busyDeviceAddress:""; property int connections:0; property int pairs:0; function connectDevice(device) {connections++} function disconnectDevice(device) {connections++} function pairDevice(device) {pairs++} function stopScan() {scanning=false} function startScan() {scanning=true} property bool scanning:false'
    mocks['VPNService'] += '; property var profiles:[];property bool ready:true;property string errorMessage:"";property bool busy:false;property string busyVPN:"";property string activeVPN:"";property int connections:0;property string lastUuid:"";function connect(uuid) {lastUuid=uuid;connections++} function disconnect(uuid) {lastUuid=uuid;connections++}'
    mocks['NetworkAuthService'] = 'property bool busy:false;property string requestToken:"";property string connectionName:"";property string message:"";property var fields:[];property bool requestNew:false;property string validationError:"";function submit(token,answers) {requestToken="";return true} function reject(token) {requestToken="";return true}'
    mocks['EthernetService'] = 'property string icon:"lan"; property bool connected:false; property string interfaceName:""; property var ipv4Addresses:[];property var ipv6Addresses:[];property string ipv4Gateway:"";property string ipv6Gateway:""'
    mocks['SystemMonitorService'] += '; property bool hasNet:false; property string netRxFormatted:""; property string netTxFormatted:""; property var netRxHistory:[]; property var netTxHistory:[]'
    mocks['ActiveWindowService'] = 'property string windowTitle:"A very long editor window title";property string windowClass:"editor"'
    mocks['IconCategoryResolver'] = 'function getAppCategoryIcon(value,fallback) {return "window"} function appIconSource(value) {return ""}'
    mocks['WallpaperManager'] = 'function getWallpaper(name) {return ""} function getFillMode(name) {return 0}'
    mocks['NetworkService'] += '; property bool wiredConnected:false'
    mocks['KeyboardLayoutService'] = 'property var layoutCodes:["en","ru"];property string currentLayoutCode:"en";property bool capsLockEnabled:false;property bool numLockEnabled:false;function addLockStateWatcher() {} function removeLockStateWatcher() {} function switchLayout() {currentLayoutCode=currentLayoutCode==="en" ? "ru" : "en"}'
    mocks['HyprlandDispatch'] += ';property int lastWorkspace:0;function focusWorkspace(id) {lastWorkspace=id} function focusWindow(address) {}'
    mocks['NetworkService'] += ';property string connectionLabel:"A long wireless network name";property string connectionIcon:"wifi"'
    mocks['GlobalStates'] += ';property QtObject activePanelScreen:null;function closeAllPanels() {dashboardOpen=false}'
    mocks['NotificationDND'] = 'property bool enabled:false;property bool temporary:false;property string statusText:"";property real expiresAt:0;property int lastDuration:0;function toggle() {enabled=!enabled} function setForMinutes(minutes) {lastDuration=minutes;return true}'
    mocks['AudioService'] += ';signal volumeChanged(real volume,bool muted)'
    mocks['BrightnessService'] += ';signal brightnessAdjusted(real value)'
    mocks['ToastService'] = 'readonly property int levelInfo:0;readonly property int levelSuccess:1;readonly property int levelWarning:2;readonly property int levelError:3;signal toastRequested(string message,string icon,int level,int duration)'
    mocks['LauncherService'] = ''
    mocks['ClipboardService'] = 'property bool debug:false;property int _thumbnailVersion:0;property int refreshes:0;signal entriesChanged();function refresh() {refreshes++} function fuzzySearch(query,limit) {return []} function requestThumbnail(entry) {} function thumbnailFor(entry) {return ""}'
    mocks['GlobalStates'] = mocks['GlobalStates'].replace('function closePanel(name) {}','function closePanel(name) {if(name==="launcher") launcherOpen=false}')
    mocks['GlobalStates'] += '; signal panelOpened(string name);property bool lockscreenActive:false;property QtObject testScreen:null;function focusedScreen() {return testScreen} function openPanel(name) {lastAction=name;actionCount++} function openDashboardTab(index) {dashboardOpenIndex=index;lastAction="dashboard";actionCount++} function lockSession() {lastAction="lock";actionCount++}'
    (services / 'qmldir').write_text('module qs.src.core.services\n' +
        ''.join(f'singleton {name} 1.0 {name}.qml\n' for name in mocks)+'NetworkInfo 1.0 NetworkInfo.qml\n')
    for name, body in mocks.items():
        (services / f'{name}.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject {'+body.replace('};', '}')+'}\n')
    shutil.copy2(ROOT / 'src/core/services/NetworkInfo.qml', services / 'NetworkInfo.qml')
    (services / 'connectivity').mkdir()
    (services / 'connectivity/NativeNetworkInfo.qml').write_text('import QtQml\nQtObject {property string interfaceName:"";property bool ready:true;property var ipv4Addresses:[];property var ipv6Addresses:[];property string ipv4Gateway:"";property string ipv6Gateway:"";function refresh() {}}\n')
    upower = qs / 'Services/UPower'
    upower.mkdir()
    (upower / 'qmldir').write_text('module Quickshell.Services.UPower\nsingleton UPower 1.0 UPower.qml\nUPowerDeviceState 1.0 UPowerDeviceState.qml\n')
    (upower / 'UPower.qml').write_text('pragma Singleton\nimport QtQml\nQtObject {property QtObject displayDevice:QtObject {property bool ready:true;property bool isLaptopBattery:true;property real percentage:0.8;property int state:0}}\n')
    (upower / 'UPowerDeviceState.qml').write_text('import QtQml\nQtObject {enum Kind {Discharging,Charging,PendingCharge}}\n')
    test = temp / 'tst_controls.qml'
    for name, body in {
        'QsMenuHandle': 'QtObject {property var entries:[]}',
        'QsMenuEntry': 'QsMenuHandle {property string text:"";property bool enabled:true;property bool isSeparator:false;property bool hasChildren:false;property int buttonType:0;property int checkState:Qt.Unchecked;property string icon:"";property int triggers:0;function triggered(){triggers++}}',
        'QsMenuButtonType': 'QtObject {enum Kind {None,CheckBox,RadioButton}}',
        'QsMenuOpener': 'QtObject {id:opener;property QsMenuHandle menu:null;property ListModel children:ListModel {dynamicRoles:true;property var values:opener.menu?.entries ?? [];onValuesChanged:{clear();for(const entry of values) append({modelData:entry})}}}'
    }.items():
        (qs / (name+'.qml')).write_text('import QtQuick\n'+body+'\n')
        with (qs / 'qmldir').open('a') as module:
            module.write(name+' 1.0 '+name+'.qml\n')
    (services / 'LauncherService.qml').write_text((ROOT / 'src/core/services/LauncherService.qml').read_text())
    # Exercise the real history facade with deterministic native snapshots.
    monitor = temp / 'imports/SystemMonitor'
    monitor.mkdir()
    (monitor / 'qmldir').write_text('module SystemMonitor\nsingleton SystemMonitor 1.0 SystemMonitor.qml\n')
    source=(ROOT / 'src/core/services/SystemMonitorService.qml').read_text()
    import re
    fields=[]
    for kind,name,source_name in re.findall(r'readonly property (\w+) (\w+): SystemMonitor\.(\w+)',source):
        default='""' if kind=='string' else 'false' if kind=='bool' else '0'
        fields.append(f'property {kind} {source_name}:{default}')
    (monitor / 'SystemMonitor.qml').write_text('pragma Singleton\nimport QtQml\nQtObject {'+';'.join(fields)+';signal statsUpdated();signal errorOccurred(string message);function setUpdateInterval(value) {} function refresh() {}}\n')
    (temp / 'TestStatsService.qml').write_text(source.replace('pragma Singleton\n',''))
    (temp / 'TestTrayMenu.qml').write_text((ROOT / 'src/features/popouts/TrayMenu.qml').read_text())
    manager_source=(ROOT / 'src/ui/feedback/TooltipManager.qml').read_text()
    # The real authentication adapter is exercised with inert PAM/process transports.
    pam = temp / 'imports/TestPam'
    pam.mkdir()
    (pam / 'qmldir').write_text('module TestPam\nPamContext 1.0 PamContext.qml\nPamResult 1.0 PamResult.qml\nsingleton PamProbe 1.0 PamProbe.qml\n')
    (pam / 'PamResult.qml').write_text('import QtQml\nQtObject {enum Result {Success,MaxTries,Error}}\n')
    (pam / 'PamProbe.qml').write_text('pragma Singleton\nimport QtQml\nQtObject {property QtObject context:null;property int starts:0;property int responses:0;property string lastResponse:"";property int aborts:0}\n')
    (pam / 'PamContext.qml').write_text('''import QtQml
QtObject {
 property string config:""
 property bool active:false
 property bool responseRequired:false
 signal completed(int result)
 function start() {PamProbe.context=this;PamProbe.starts++;active=true;return true}
 function respond(value) {PamProbe.responses++;PamProbe.lastResponse=value;responseRequired=false}
 function abort() {PamProbe.aborts++;active=false}
 function finish(result) {active=false;responseRequired=false;completed(result)}
}
''')
    io = temp / 'imports/TestIo'
    io.mkdir()
    (io / 'qmldir').write_text('module TestIo\nProcess 1.0 Process.qml\nSplitParser 1.0 SplitParser.qml\nsingleton PowerProbe 1.0 PowerProbe.qml\n')
    (io / 'PowerProbe.qml').write_text('pragma Singleton\nimport QtQml\nQtObject {property QtObject process:null;property var command:[];property int starts:0}\n')
    (io / 'SplitParser.qml').write_text('import QtQml\nQtObject {signal read(string line)}\n')
    (io / 'Process.qml').write_text('''import QtQml
QtObject {
 property QtObject stderr:null
 property var command:[]
 property bool running:false
 signal exited(int exitCode)
 onRunningChanged: if(running) {PowerProbe.process=this;PowerProbe.command=command;PowerProbe.starts++}
 function finish(code) {running=false;exited(code)}
}
''')
    surface = (ROOT / 'src/features/lockscreen/LockSurface.qml').read_text().replace('import Quickshell.Services.Pam','import TestPam').replace('import Quickshell.Io','import TestIo')
    surface = surface.replace('required property ShellScreen screen','property QtObject screen:null')
    surface = re.sub(r'property bool formActive:.*', 'property bool formActive: true', surface)
    surface = surface.replace('import qs.src.ui.containers','import qs.src.features.lockscreen\nimport qs.src.ui.containers')
    (temp / 'TestLockSurface.qml').write_text(surface)
    manager_source=manager_source[:manager_source.index('    LazyLoader {')]+'}\n'
    manager_source=manager_source.replace('Scope {','Item {',1).replace('import Quickshell\n','import qs.src.ui.feedback\n')
    (temp / 'TestTooltipManager.qml').write_text(manager_source)
    test.write_text('''import TestPam
import TestIo
import QtQuick
import "imports/qs/src/features/statusbar/BarLayoutPolicy.js" as BarPolicy
import SystemMonitor 1.0 as NativeStats
import Qalculate 1.0
import qs.src.features.lockscreen
import qs.src.features.dock
import qs.src.features.launcher
import qs.src.features.osd
import qs.src.features.dashboard.components.maintab_elements
import QtQuick.Controls
import Quickshell
import QtQuick.Layouts
import QtTest
import Quickshell.Networking
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Calendar
import qs.src.core.config
import qs.src.ui.base
import qs.src.ui.inputs
import qs.src.ui.containers
import qs.src.ui.feedback
import qs.src.features.dashboard
import qs.src.features.statusbar
import qs.src.features.dashboard.components
import qs.src.features.connections
import qs.src.features.audio
import qs.src.features.launcher.components
import qs.src.core.services

Item {
 id: scene
 width: 760; height: 520
 property int selected: 0
 property int tileClicks: 0
 property int acceptedEdits: 0
 property int downPresses: 0
 Rectangle { anchors.fill: parent; color: Theme.surfaceContainer }
 ColumnLayout {
  id: controls
  anchors.fill: parent
  anchors.margins: Tokens.panelPadding
  spacing: Tokens.spacing.medium
  MaterialText {text: "Controls / " + AppConfig.designSystem; textStyle:"headlineSmall"}
  MaterialTabs {
   id: tabs
   Layout.fillWidth:true
   labels:["Quick","Weather","Calendar","Audio","Network"]
   currentIndex:scene.selected
   onActivated:index => scene.selected=index
  }
  ToggleTile {id:tile;label:"Do not disturb";iconName:"do_not_disturb_on";active:true;onClicked:scene.tileClicks++}
  MaterialButton {id:action;text:"Continue"}
  MaterialTextField {id:field;placeholderText:"Search apps";leadingIcon:"search";onAccepted:scene.acceptedEdits++;Keys.onDownPressed:scene.downPresses++}
  MaterialComboBox {id:combo;model:["First","Second","Third"];label:"Output"}
  MaterialButton {id:after;text:"After controls"}
  Item {Layout.fillHeight:true}
 }
 Dialog {
  id:dialog
  dialogWidth:400;dialogHeight:240
  ColumnLayout {
   anchors.fill:parent;anchors.margins:Tokens.spacing.large
   MaterialTextField {id:modalField;placeholderText:"Name";Layout.fillWidth:true}
   MaterialButton {id:modalLast;text:"Close";onClicked:dialog.close()}
  }
  Dialog {
   id:innerDialog;dialogWidth:300;dialogHeight:180
   ColumnLayout {anchors.fill:parent;MaterialButton{id:innerFirst;text:"First"} MaterialButton{id:innerLast;text:"Last"}}
  }
 }
 Component {id:lockSurfaceFixture; TestLockSurface {width:760;height:900;property int unlocks:0;onUnlocked:unlocks++}}
 Component {id:lockFixture; LockContent {width:760;height:900;username:"User";layoutCode:"en";multipleLayouts:true;mediaAvailable:true;playing:true;trackTitle:"A long track name";trackArtist:"Artist";canToggle:true;canNext:true;canPrevious:true;property int submissions:0;property string requestedPower:"";property int mediaClicks:0;onSubmitted:submissions++;onPowerRequested:action=>requestedPower=action;onTogglePlaying:mediaClicks++}}
 Component {id:barFixture;BarLayout {
  height:BarMetrics.height;width:1000
  leftWidgets:[{type:"workspaces",settings:{count:6,showWindows:false}},{type:"activewindow",settings:{maxWidth:300}}]
  centerWidgets:[{type:"clock",settings:{showDate:true}}]
  rightWidgets:[{type:"media",settings:{compact:false,maxWidth:200}},{type:"weather"},{type:"volume"},{type:"network",settings:{showLabel:true}},{type:"notifications"},{type:"layout"},{type:"tray"}]
 }}
 Component {id:barOverflowFixture;TestBarOverflow {width:320;height:implicitHeight}}
 Component {id:fakeBarModel;QtObject {property var overflowWidgets:[];property Item overflowAnchor:null}}
 Component {id:dockPreviewFixture;DockPreview {}}
 Component {id:dockContextFixture;DockContextMenu {}}
 Component {id:dockWindowFixture;QtObject {property bool activated:false;property string title:"<b>Literal window title</b>";function activate() {} function close() {}}}
 Component {id:dockTooltipFixture;DockTooltip {}}
 Component {id:dockTooltipHost;Item {width:700;height:360;property Item anchor:Item {x:180;y:290;width:340;height:60}}}
 Component {id:dockSignalSpy;SignalSpy {}}
 Component {id:dockHostFixture;Item {width:80;height:80}}
 Component {id:dockIconFixture;DockIcon {index:0;app:QtObject {property string key:"test-dock";property bool pinned:true;property QtObject entry:null;property var windows:[window];property QtObject window:QtObject {property bool urgent:true;property bool activated:false}}}}
 Component {id:clockFixture;ClockWidget {height:40}}
 Component {id:mediaFixture;MPRISWidget {height:40}}
 Component {id:weatherFixture;WeatherWidget {height:40}}
 Component {id:volumeFixture;VolumeWidget {height:40}}
 Component {id:launcherLoaderFixture;Loader {active:GlobalStates.launcherOpen;sourceComponent:LauncherContent {width:600;height:400}}}
 Component {id:launcherFixture;LauncherContent {width:600;height:Math.min(implicitHeight,500)}}
 Component {id:snackbarFixture;Snackbar {width:360;property int activations:0;message:"200 notifications cleared";actionText:"Undo";onActionClicked:activations++}}
 Component {id:meterFixture;OsdMeterContent {width:300;height:implicitHeight;title:"Brightness";iconName:"brightness_high";progress:0.75}}
 Component {id:ipcFixture;TestIpcData {}}
 Component {id:dashboardFieldFixture;MaterialTextField {width:240}}
 Component {id:dashboardSliderFixture;MaterialSlider {width:240}}
 Component {id:eventFormFixture;TestEventDialog {}}
 Component {id:eventFormHost;Item {width:600;height:420}}
 Component {id:testButtonFixture;MaterialButton {text:"Test action";checkable:true}}
 Component {id:controlledComboFixture;Item {width:260;height:64;property int selection:0;property alias control:control;MaterialComboBox {id:control;width:240;model:["One","Two","Three"];controlled:true;currentIndex:parent.selection;onActivated:index=>parent.selection=index}}}
 Component {id:comboFixture;MaterialComboBox {width:240}}
 Component {id:statsServiceFixture;TestStatsService {}}
 Component {id:storageFixture;StorageSection {width:600}}
 Component {id:statsViewFixture;SystemMonitoringElement {width:600}}
 Component {id:hintFixture;MaterialTooltip {}}
 Component {id:tooltipFixture;TooltipItem {}}
 Component {id:tooltipManagerFixture;TestTooltipManager {bar:QtObject {property int height:32;property int width:760;property QtObject screen:QtObject {property int height:600;property int width:760}}}}
 Component {id:menuEntryFixture;QsMenuEntry {}}
 Component {id:trayMenuFixture;TestTrayMenu {width:300;maximumHeight:180}}
 Component {id:audioFixture;AudioContent {width:420;height:Math.min(implicitHeight,500)}}
 Component {id:audioNode;PwNode {}}
 Component {id:trayNode;SystemTrayItem {}}
 Component {id:trayIconFixture;TrayIcon {}}
 Component {id:trayFixture;TrayWidget {height:40}}
 Component {id:overflowFixture;TestTrayOverflow {width:320;height:400}}
 Component {id:panelState;TestPanelState {}}
 Component {id:collapsibleFixture;CollapsibleContent {width:300;sourceComponent:Component {Item {implicitHeight:160}}}}
 Component {id:mediaRowFixture;QuickMediaRow {width:600;visible:true}}
 Component {id:connectionsPanel;ConnectionsContent {width:420;height:Math.min(implicitHeight,500)}}
 Component {
  id:pairingFixture
  BluetoothPairingDialog {
   width:420;height:500
   property int answers:0
   property int rejections:0
   property string value:""
   onAnswered:(token,input)=>{answers++;value=input;requestToken=""}
   onRejected:token=>{rejections++;requestToken=""}
  }
 }
 Component {
  id:networkAuthFixture
  NetworkAuthenticationDialog {
   width:420;height:500
   property int answers:0
   property int rejections:0
   property string submittedToken:""
   property string submittedValue:""
   onAnswered:(token,values)=>{answers++;submittedToken=token;submittedValue=values.psk ?? values.password ?? "";requestToken=""}
   onRejected:token=>{rejections++;requestToken=""}
  }
 }
 Component {id:wifiNode;WifiNetwork {}}
 Component {id:btNode;QtObject {property string name:"Headphones";property string address:"AA";property bool connected:true}}
 Component {id:testCalendar;TestCalendar {width:900;height:600}}
 Component {id:devicePicker;AudioDevicePicker {width:600;height:400}}
 Component {id:basicRow;ListItem {width:300;headline:"A device";supportingText:"Connected"}}
 Component {id:resultDelegate;AppListItem {index:0}}
 DashboardContent {id:dashboard;anchors.fill:parent;visible:false}
 TestCase {
  name:"ShellControls"
  when:windowShown
  function initTestCase() {
   scene.Window.window.requestActivate()
   tryCompare(scene.Window.window,"active",true)
  }
  function test_dock_tooltip_snapshot_data() {
   const rows=[]
   for(const pack of ["minimal","md3"])for(const side of ["top","bottom","left","right"])rows.push({tag:pack+"-"+side,pack:pack,side:side})
   return rows
  }
  function test_dock_tooltip_snapshot(data) {
   AppConfig.designSystem=data.pack;AppConfig.reduceMotion=false
   const host=createTemporaryObject(dockTooltipHost,scene)
   const tip=createTemporaryObject(dockTooltipFixture,host,{anchorItem:host.anchor,position:data.side,center:350,hintText:"Application with a long name",showing:true})
   tryCompare(tip,"opacity",1)
   const rect=Qt.rect(tip.x,tip.y,tip.width,tip.height)
   const text=tip.text
   tip.showing=false;tip.hintText="";tip.center=0
   host.anchor.x=0;host.anchor.y=0;host.width=500;host.height=260
   verify(tip.visible);verify(tip.opacity>0)
   compare(tip.text,text);compare(tip.x,rect.x);compare(tip.y,rect.y)
   compare(tip.width,rect.width);compare(tip.height,rect.height)
   tryCompare(tip,"opacity",0);verify(!tip.visible)
   tip.hintText="Another application";tip.center=240;tip.showing=true
   tryCompare(tip,"opacity",1);compare(tip.text,"Another application")
   verify(tip.x!==rect.x || tip.y!==rect.y)
   // A new owner may replace a closing hint before the fade completes.
   tip.showing=false;tip.hintText="Replacement";tip.showing=true
   tryCompare(tip,"opacity",1);compare(tip.text,"Replacement")
   // Empty content is also a dismissal, even if the producer's show flag lags.
   tip.hintText="";tryCompare(tip,"opacity",0);verify(!tip.visible)
   AppConfig.reduceMotion=true
   tip.hintText="Immediate";tip.showing=true;compare(tip.opacity,1)
   tip.showing=false;compare(tip.opacity,0);verify(!tip.visible)
  }
  function test_dock_popup_bounds_data() {
   const rows=[]
   for(const pack of ["minimal","md3"])for(const side of ["top","bottom","left","right"])for(const scale of [1,2])for(const width of [220,320])rows.push({tag:pack+"-"+side+"-"+scale+"-"+width,pack:pack,side:side,scale:scale,width:width})
   return rows
  }
  function test_dock_popup_bounds(data) {
   controls.visible=false;AppConfig.designSystem=data.pack;AppConfig.fontScale=data.scale;AppConfig.reduceMotion=true
   const host=createTemporaryObject(dockTooltipHost,scene,{width:data.width,height:260})
   const vertical=data.side==="left" || data.side==="right"
   host.anchor.x=vertical ? (data.side==="left" ? 8 : host.width-80) : 40
   host.anchor.y=vertical ? 40 : (data.side==="top" ? 8 : 180)
   host.anchor.width=vertical ? 72 : host.width-80
   host.anchor.height=vertical ? 180 : 72
   const a=createTemporaryObject(dockWindowFixture,scene)
   const b=createTemporaryObject(dockWindowFixture,scene)
   const c=createTemporaryObject(dockWindowFixture,scene)
   const preview=createTemporaryObject(dockPreviewFixture,host,{anchorItem:host.anchor,position:data.side,center:0,model:[a,b,c],showing:true})
   wait(10)
   function checkBounds(item) {
    verify(item.width>=0 && item.height>=0)
    verify(item.x>=0 && item.y>=0)
    verify(item.x+item.width<=host.width+1)
    verify(item.y+item.height<=host.height+1)
   }
   checkBounds(preview)
   if(data.side==="top")verify(preview.y>=host.anchor.y+host.anchor.height+Tokens.spacing.extraSmall-1)
   if(data.side==="bottom")verify(preview.y+preview.height<=host.anchor.y-Tokens.spacing.extraSmall+1)
   if(data.side==="left")verify(preview.x>=host.anchor.x+host.anchor.width+Tokens.spacing.extraSmall-1)
   if(data.side==="right")verify(preview.x+preview.width<=host.anchor.x-Tokens.spacing.extraSmall+1)
   const title=byProperty(preview,"objectName","dockPreviewTitle")
   verify(title!==null);compare(title.textFormat,Text.PlainText)
   verify(title.width<=preview.width-Tokens.spacing.medium*2)
   if(!vertical) {
    const p=title.mapToItem(preview,0,0)
    verify(p.y+title.height<=preview.height-Tokens.spacing.medium+1,"title fits below adapted thumbnail")
   }
   preview.center=host.width+host.height;checkBounds(preview)
   preview.showing=false
   const menu=createTemporaryObject(dockContextFixture,host,{anchorItem:host.anchor,position:data.side,availableWidth:vertical ? host.width-110 : host.width-20,availableHeight:vertical ? 240 : 150})
   menu.openFor({appId:"test",entry:{},windows:[{}]},Qt.rect(0,0,30,30));wait(10)
   checkBounds(menu.menuItem)
   verify(menu.menuItem.width<=menu.availableWidth)
   verify(menu.menuItem.height<=menu.availableHeight)
   menu.close()
   AppConfig.fontScale=1.3
  }
  function test_dock_preview_clamps_during_motion() {
   controls.visible=false;AppConfig.reduceMotion=false
   const host=createTemporaryObject(dockTooltipHost,scene,{width:320,height:260})
   host.anchor.x=40;host.anchor.y=180;host.anchor.width=240;host.anchor.height=72
   const window=createTemporaryObject(dockWindowFixture,scene)
   const preview=createTemporaryObject(dockPreviewFixture,host,{anchorItem:host.anchor,position:"bottom",center:280,model:[window],showing:true})
   preview.center=20
   host.width=200
   for(let i=0;i<5;i++) {
    wait(20)
    verify(preview.x>=0 && preview.x+preview.width<=host.width+1,"position remains clamped on every animation frame")
   }
   AppConfig.reduceMotion=true
  }
  function test_dock_hover_signals_use_app_key() {
   controls.visible=false
   const host=createTemporaryObject(dockHostFixture,scene,{z:100})
   const icon=createTemporaryObject(dockIconFixture,host)
   const enter=createTemporaryObject(dockSignalSpy,scene,{target:icon,signalName:"requestPreview"})
   const leave=createTemporaryObject(dockSignalSpy,scene,{target:icon,signalName:"hoverEnded"})
   mouseMove(scene,500,500);wait(1);enter.clear();leave.clear()
   mouseMove(icon,icon.width/2,icon.height/2)
   tryCompare(enter,"count",1)
   compare(enter.signalArguments[0][0],"test-dock")
   icon.index=9
   mouseMove(scene,500,500)
   tryCompare(leave,"count",1)
   compare(leave.signalArguments[0][0],"test-dock")
  }
  function test_dock_motion_data() {return [{tag:"minimal",pack:"minimal"},{tag:"md3",pack:"md3"}]}
  function test_dock_motion(data) {
   AppConfig.designSystem=data.pack;AppConfig.reduceMotion=false;Tokens.motionFrozen=false
   const host=createTemporaryObject(dockHostFixture,scene)
   const icon=createTemporaryObject(dockIconFixture,host)
   const urgency=findChild(icon,"dockUrgencyMotion")
   const launch=findChild(icon,"dockLaunchMotion")
   const image=findChild(icon,"dockAppImage")
   const indicator=findChild(icon,"dockUrgencyIndicator")
   verify(urgency.running)
   DockService.appLaunched("test-dock");verify(launch.running)
   tryVerify(()=>image.scale>1.01)
   // Auto-hide stops both loops immediately, before the bar's fade finishes.
   icon.motionEnabled=false
   verify(!urgency.running);verify(!launch.running);compare(image.scale,1)
   compare(indicator.opacity,Tokens.stateLayer.pressedOpacity)
   icon.motionEnabled=true;verify(urgency.running);verify(launch.running)
   // Effective ancestor visibility also suspends animation.
   host.visible=false;verify(!urgency.running);verify(!launch.running)
   host.visible=true;verify(urgency.running)
   AppConfig.reduceMotion=true
   verify(!urgency.running);verify(!launch.running);compare(image.scale,1)
   verify(indicator.visible);compare(indicator.opacity,Tokens.stateLayer.pressedOpacity)
   // Urgency clears while motion is suppressed; launch completion still tracks windows.
   icon.app.window.urgent=false;verify(!indicator.visible)
   icon.app.windows=[icon.app.window,icon.app.window]
   verify(!icon._launching)
   AppConfig.reduceMotion=false
   verify(!urgency.running);verify(!launch.running);compare(image.scale,1)
   icon.app.window.urgent=true;verify(urgency.running)
   Tokens.motionFrozen=true;verify(!urgency.running)
   Tokens.motionFrozen=false;tryVerify(()=>urgency.running)
   AppConfig.motionScale=0.00001
   verify(!urgency.running);verify(!launch.running)
   AppConfig.motionScale=1;tryVerify(()=>urgency.running)
   icon.app.window.urgent=false
   AppConfig.reduceMotion=true
  }
  function test_lock_authentication_and_power_transport() {
   PamProbe.starts=0;PamProbe.responses=0;PamProbe.lastResponse="";PowerProbe.starts=0
   const surface=createTemporaryObject(lockSurfaceFixture,scene)
   const field=findChild(surface,"lockPassword")
   verify(PamProbe.starts>0)
   field.text="secret";field.inputItem.forceActiveFocus();keyClick(Qt.Key_Return)
   compare(PamProbe.responses,0)
   PamProbe.context.responseRequired=true
   compare(PamProbe.responses,1);compare(PamProbe.lastResponse,"secret")
   compare(field.text,"")
   PamProbe.context.finish(PamResult.MaxTries)
   compare(surface.unlocks,0)
   compare(findChild(surface,"lockAuthError").text,"Too many attempts")
   PamProbe.context.responseRequired=true
   field.text="correct";field.inputItem.forceActiveFocus();keyClick(Qt.Key_Return)
   compare(PamProbe.lastResponse,"correct")
   PamProbe.context.finish(PamResult.Success)
   compare(surface.unlocks,1)
   findChild(surface,"lockPower").clicked();wait(1)
   findChild(surface,"lockShutdown").clicked()
   compare(PowerProbe.starts,0)
   findChild(surface,"lockConfirmPower").clicked()
   compare(PowerProbe.starts,1);compare(PowerProbe.command.join(" "),"systemctl poweroff")
   const starts=PamProbe.starts
   verify(!PamProbe.context.active)
   PowerProbe.process.stderr.read("Operation blocked by a running application")
   PowerProbe.process.finish(1)
   verify(PamProbe.starts>starts)
   const panel=findChild(surface,"lockPowerPanel")
   verify(panel.visible)
   verify(PamProbe.context.active)
   surface.formActive=false
   verify(!PamProbe.context.active)
  }
  function test_lock_visibility_and_media() {
   const view=createTemporaryObject(lockFixture,scene)
   verify(view.mediaShown)
   view.playing=false
   verify(view.mediaShown)
   AppConfig.lockscreenMediaShowPaused=false
   verify(!view.mediaShown)
   AppConfig.lockscreenMediaShowPaused=true
   AppConfig.lockscreenShowMedia=false
   verify(!view.mediaShown)
   AppConfig.lockscreenShowMedia=true
   view.formActive=false
   verify(!view.mediaShown)
   view.formActive=true
   AppConfig.lockscreenShowClock=false
   AppConfig.lockscreenShowDate=true
   verify(!findChild(view,"lockClock").visible)
   verify(findChild(view,"lockDate").visible)
   AppConfig.lockscreenShowClock=true
   const play=findChild(view,"lockPlay")
   play.forceActiveFocus();keyClick(Qt.Key_Return)
   compare(view.mediaClicks,1)
  }
  function test_lock_power_keyboard_and_password() {
   const view=createTemporaryObject(lockFixture,scene)
   view.password="test"
   view.focusPassword();keyClick(Qt.Key_Return)
   compare(view.submissions,1)
   view.openPower();wait(1)
   verify(findChild(view,"lockCancelPower").activeFocus)
   keyClick(Qt.Key_Return)
   verify(!view.powerOpen);compare(view.password,"test")
   view.openPower();wait(1)
   findChild(view,"lockReboot").forceActiveFocus();keyClick(Qt.Key_Return)
   compare(view.confirming,"reboot");compare(view.requestedPower,"")
   verify(findChild(view,"lockCancelPower").activeFocus)
   keyClick(Qt.Key_Tab)
   verify(findChild(view,"lockConfirmPower").activeFocus)
   keyClick(Qt.Key_Return)
   compare(view.requestedPower,"reboot");compare(view.password,"")
   keyClick(Qt.Key_Escape)
   verify(!view.powerOpen)
   view.password="private";view.formActive=false
   compare(view.password,"")
  }
  function test_lock_layout_data() {
   const rows=[]
   for(const pack of ["minimal","md3"]) for(const scale of [1,2]) for(const size of [[320,480],[1920,1080]]) rows.push({tag:pack+"-"+size[0]+"-"+scale,pack:pack,scale:scale,w:size[0],h:size[1]})
   return rows
  }
  function test_lock_layout(data) {
   AppConfig.designSystem=data.pack;AppConfig.fontScale=data.scale
   const view=createTemporaryObject(lockFixture,scene,{width:data.w,height:data.h})
   wait(20)
   const field=findChild(view,"lockPassword")
   verify(field.width>0 && field.width<=data.w)
   verify(findChild(view,"lockAuthError").height>=findChild(view,"lockAuthError").implicitHeight)
  }
  function test_lock_responsive_and_error() {
   const view=createTemporaryObject(lockFixture,scene,{width:320,height:480})
   view.errorMessage="Authentication failed"
   wait(1)
   const field=findChild(view,"lockPassword")
   verify(field.width>0 && field.width<320)
   const layout=findChild(view,"lockLayout")
   const submit=findChild(view,"lockSubmit")
   const layoutTop=layout.mapToItem(field,0,0).y
   const submitTop=submit.mapToItem(field,0,0).y
   verify(layoutTop>=0 && layoutTop+layout.height<=field.height+1)
   verify(submitTop>=0 && submitTop+submit.height<=field.height+1)
   verify(field.inputItem.width>0)
   view.focusPassword();wait(20)
   const scroll=findChild(view,"lockScroll")
   const top=field.mapToItem(scroll,0,0).y
   verify(top>=0 && top+field.height<=scroll.height+1)
   const error=findChild(view,"lockAuthError")
   verify(error.height>=error.implicitHeight)
   view.mediaAvailable=false
   verify(!view.mediaShown)
  }
  function init() {
   AppConfig.designSystem="minimal";AppConfig.fontScale=1.3;AppConfig.reduceMotion=true
   AppConfig.disabledModules=[]
   AppConfig.temporaryModeDurations=[15,30,60,120];IdleInhibitorService.statusText="";NotificationDND.statusText="";NotificationDND.enabled=false;NotificationDND.temporary=false
   GlobalStates.launcherOpen=false;LauncherService.search("")
   AppConfig.weatherEnabled=true
   Weather.data=({current:{temperature_2m:8}});Weather.isFresh=true;Weather.errorString=""
   CalendarBackend.dayEvents=[]
   SystemMonitorService.storageVolumes=[];SystemMonitorService.storageDrives=[];SystemMonitorService.storageSummary=({available:true,name:"System",availableFormatted:"100 GiB",severity:0})
   SystemMonitorService.hasCpuTemp=true;SystemMonitorService.hasGpuTemp=true;SystemMonitorService.hasGpuStats=true
   MprisController.availablePlayers=[]
   GlobalStates.actionCount=0;GlobalStates.lastAction="";MprisController.toggles=0;NightLightService.available=true;VPNService.enabled=true
   dashboard.visible=false;controls.visible=true;GlobalStates.dashboardOpenIndex=0
   GlobalStates.audioOpen=true;PopoutsState.closePopout();SystemTray.items=({values:[]})
   AudioService.streamNodes=[];AudioService.defaultSink=Pipewire.defaultAudioSink;AudioService.defaultSource=null;AudioService.masterVolume=0.45;AudioService.masterMuted=false;AudioService.micVolume=0.5;AudioService.micMuted=false
   GlobalStates.connectionsOpen=true;GlobalStates.connectionsSection=""
   NetworkService.wifiEnabled=true;NetworkService.deviceReady=true;NetworkService.errorMessage="";NetworkService.connectionPending=false;BluetoothService.enabled=true
   VPNService.profiles=[];VPNService.errorMessage="";VPNService.lastUuid="";VPNService.connections=0
   NetworkService.networks=[];NetworkService.scanning=false;NetworkService.connections=0;NetworkService.disconnections=0
   BluetoothService.pairedDevices=[];BluetoothService.discoveredDevices=[];BluetoothService.scanning=false;BluetoothService.connections=0;BluetoothService.pairs=0
   scene.width=760;scene.height=520
   scene.selected=0;scene.tileClicks=0;scene.acceptedEdits=0;scene.downPresses=0;combo.currentIndex=0;combo.open=false
   if(innerDialog.visible) {innerDialog.close();wait(30)}
   if(dialog.visible) {dialog.close();wait(30)}
   wait(30)
  }
  function test_bar_policy_priority_and_sections() {
   const entries=[
    {key:"title",section:"left",order:0,priority:10,compactPriority:10,minimum:100,preferred:300,compactMinimum:40,compactPreferred:40},
    {key:"time",section:"center",order:1,priority:100,compactPriority:20,minimum:120,preferred:120,compactMinimum:80,compactPreferred:80},
    {key:"volume",section:"right",order:2,priority:80,compactPriority:30,minimum:100,preferred:100,compactMinimum:40,compactPreferred:40}]
   const wide=BarPolicy.plan(entries,700,8,40,true)
   compare(wide.hidden.length,0);compare(wide.compact.length,0)
   const medium=BarPolicy.plan(entries,250,8,40,true)
   verify(medium.compact.includes("title"));compare(medium.hidden.length,0)
   const narrow=BarPolicy.plan(entries,170,8,40,true)
   verify(narrow.hidden.includes("title"));verify(!narrow.hidden.includes("time"))
   const noPopup=BarPolicy.plan(entries,100,8,40,false)
   compare(noPopup.hidden.length,0);verify(noPopup.scroll)
   const pinned=BarPolicy.plan(entries.map(entry=>Object.assign({},entry,{priority:entry.key==="title" ? 100 : 0})),170,8,40,true)
   verify(!pinned.hidden.includes("title"))
  }
  function test_bar_responsive_geometry_data() {return [{tag:"minimal",pack:"minimal"},{tag:"md3",pack:"md3"}]}
  function test_bar_responsive_geometry(data) {
   controls.visible=false;AppConfig.designSystem=data.pack
   for(const scale of [1,1.3,2]) {
    AppConfig.fontScale=scale
    const bar=createTemporaryObject(barFixture,scene)
    verify(bar!==null);wait(60)
    for(const width of [1600,1000,768,480,320,240,768,1600]) {
     bar.width=width;wait(50)
     let visible=[]
     for(const entry of bar.entries) if(!bar.plan.hidden.includes(entry.key)) {
      const item=entry.widget
      const pos=item.mapToItem(bar,0,0)
      verify(item.width+1>=item.Layout.minimumWidth,"allocated minimum: "+item.widgetType)
      verify(pos.x>=-1 && pos.x+item.width<=width+1,"bar bounds: "+item.widgetType+" at "+width+" scale="+scale+" x="+pos.x+" w="+item.width+" plan="+JSON.stringify(bar.plan.zones))
      visible.push({x:pos.x,right:pos.x+item.width})
     }
     visible.sort((a,b)=>a.x-b.x)
     for(let i=1;i<visible.length;i++) verify(visible[i].x+1>=visible[i-1].right,"widgets do not overlap")
     if(width===1600) compare(bar.plan.hidden.length,0,"all configured widgets return")
    }
    if(scale===1.3) {scene.width=1000;scene.height=bar.height;bar.width=1000;wait(30);grabImage(scene).save("RENDERS/bar-"+data.pack+".png")}
    bar.destroy()
   }
  }
  function test_workspace_metrics_independent_of_compaction() {
   controls.visible=false
   const nodes=[]
   for(let i=0;i<12;i++) nodes.push({address:String(i),workspace:{id:1},lastIpcObject:{class:"editor"}})
   Hyprland.toplevels=({values:nodes})
   const bar=createTemporaryObject(barFixture,scene,{leftWidgets:[{type:"workspaces",settings:{count:6,maxWindowsPerWorkspace:8}}],centerWidgets:[],rightWidgets:[]})
   verify(bar!==null);wait(100)
   const workspace=bar.entries[0].widget.item
   const full=workspace.preferredWidth
   verify(full>workspace.compactWidth)
   workspace.compactPresentation=true;wait(30)
   compare(workspace.preferredWidth,full,"normal measurement stays independent")
   Hyprland.toplevels=({values:[]})
  }
  function test_bar_monitor_filter_and_no_popouts() {
   controls.visible=false
   AppConfig.disabledModules=["popouts"]
   const bar=createTemporaryObject(barFixture,scene,{width:280,screenName:"B",leftWidgets:[{type:"activewindow",monitors:["A"]}],centerWidgets:[{type:"clock",settings:{showDate:true}}]})
   verify(bar!==null);wait(50)
   verify(bar.entries.every(entry=>entry.widget.widgetType!=="activewindow"))
   compare(bar.plan.hidden.length,0)
   verify(bar.plan.scroll,"controls stay reachable with scroll fallback")
  }
  function test_bar_overflow_actions() {
   controls.visible=false
   const bar=createTemporaryObject(barFixture,scene,{width:240})
   verify(bar!==null);wait(60)
   const popup=createTemporaryObject(barOverflowFixture,scene,{barModel:bar})
   verify(popup!==null);wait(30)
   const audio=byProperty(popup,"headline","Audio")
   if(audio) {audio.forceActiveFocus();keyClick(Qt.Key_Return);compare(GlobalStates.lastAction,"audio")}
   const media=byProperty(popup,"Accessible.name","Play")
   const play=byProperty(popup,"iconName",MprisController.isPlaying ? "pause" : "play_arrow")
   if(play) {mouseClick(play,play.width/2,play.height/2);compare(MprisController.toggles,1)}
  }
  function test_storage_warning_and_disclosure() {
   controls.visible=false
   const volume={id:"xfs:/dev/test",name:"Games",mountPoint:"/mnt/games",mountPoints:["/mnt/games"],device:"/dev/test",fileSystem:"xfs",readOnly:false,available:true,availableFormatted:"2 GiB",totalFormatted:"100 GiB",usedFraction:0.98,severity:2}
   SystemMonitorService.storageVolumes=[volume]
   SystemMonitorService.storageSummary=({available:true,name:"Games",availableFormatted:"2 GiB",severity:2,hasIo:true,readFormatted:"10 MiB/s",writeFormatted:"2 MiB/s"})
   const view=createTemporaryObject(storageFixture,scene)
   verify(view!==null);wait(30)
   compare(byProperty(view,"headline","Games"),null,"details stay lazy")
   const header=byProperty(view,"headline","Storage")
   compare(header.leadingIcon,"warning");compare(header.headlineColor,Theme.error)
   header.forceActiveFocus();keyClick(Qt.Key_Return);wait(30)
   const row=byProperty(view,"headline","Games")
   verify(row!==null);compare(row.supportingText,"2 GiB free / 100 GiB")
   compare(row.supportingTextFormat,Text.PlainText)
   row.forceActiveFocus();keyClick(Qt.Key_Return);wait(30)
   const details=byProperty(view,"text","/mnt/games\nxfs · /dev/test")
   verify(details!==null && details.visible,"filesystem is in expanded details")
   SystemMonitorService.storageVolumes=[];wait(30)
   compare(byProperty(view,"headline","Games"),null,"unmount removes row")
  }
  function test_storage_alert_without_statistics_view() {
   controls.visible=false;dashboard.visible=true;GlobalStates.dashboardOpenIndex=0;wait(50)
   SystemMonitorService.storageSummary=({available:true,name:"Games",availableFormatted:"2 GiB",severity:2})
   const header=byProperty(dashboard,"headline","System statistics")
   verify(header!==null);compare(header.leadingIcon,"warning")
   verify(header.supportingText.indexOf("Low space")>=0)
   compare(byProperty(dashboard,"headline","Storage"),null,"statistics remain collapsed")
  }
  function test_storage_layout_data() {return [{tag:"minimal",pack:"minimal"},{tag:"md3",pack:"md3"}]}
  function test_storage_layout(data) {
   controls.visible=false;AppConfig.designSystem=data.pack
   SystemMonitorService.storageVolumes=[
    {id:"root",name:"System",mountPoints:["/","/home","/.snapshots"],device:"/dev/nvme1n1p2",fileSystem:"btrfs",available:true,availableFormatted:"460 GiB",totalFormatted:"930 GiB",usedFraction:0.5,severity:0},
    {id:"games",name:"Games",mountPoints:["/mnt/games"],device:"/dev/nvme0n1p1",fileSystem:"xfs",available:true,availableFormatted:"9 GiB",totalFormatted:"1.8 TiB",usedFraction:0.995,severity:2}]
   SystemMonitorService.storageDrives=[{id:"nvme0n1",name:"NVMe drive",device:"/dev/nvme0n1",hasTemperature:true,temperature:44,hasIo:true,readFormatted:"10 MiB/s",writeFormatted:"2 MiB/s"}]
   for(const width of [280,600]) for(const scale of [1,1.3,2]) {
    AppConfig.fontScale=scale
    const view=createTemporaryObject(storageFixture,scene,{width:width,expanded:true})
    verify(view!==null);wait(30)
    verify(view.implicitHeight>0)
    for(const name of ["System","Games","NVMe drive"]) {
     const row=byProperty(view,"headline",name);verify(row!==null)
     verify(row.width<=width,"row fits viewport")
    }
    if(width===600 && scale===1.3) {scene.width=600;scene.height=view.implicitHeight;grabImage(scene).save("RENDERS/storage-"+data.pack+".png")}
    view.destroy()
   }
  }
  function test_statistics_history_while_hidden() {
   controls.visible=false
   const service=createTemporaryObject(statsServiceFixture,scene)
   verify(service!==null);service.init()
   NativeStats.SystemMonitor.cpuUsage=10;NativeStats.SystemMonitor.cpuTemp=40;NativeStats.SystemMonitor.hasCpuTemp=true
   NativeStats.SystemMonitor.gpuUsage=20;NativeStats.SystemMonitor.gpuTemp=50;NativeStats.SystemMonitor.hasGpuStats=true
   NativeStats.SystemMonitor.statsUpdated()
   NativeStats.SystemMonitor.cpuUsage=95;NativeStats.SystemMonitor.cpuTemp=80
   NativeStats.SystemMonitor.statsUpdated()
   NativeStats.SystemMonitor.cpuUsage=5;NativeStats.SystemMonitor.statsUpdated()
   compare(service.cpuHistory.length,3);compare(service.cpuHistory[1],0.95)
   compare(service.cpuTempHistory[1],80/120)
   verify(NativeStats.SystemMonitor.isMonitoring)
   let snapshot=service.cpuHistory
   for(let i=0;i<130;i++) NativeStats.SystemMonitor.statsUpdated()
   compare(service.cpuHistory.length,120);compare(snapshot.length,3)
   NativeStats.SystemMonitor.hasCpuTemp=false;NativeStats.SystemMonitor.gpuTemp=0;NativeStats.SystemMonitor.statsUpdated()
   compare(service.cpuTempHistory.length,0);compare(service.gpuTempHistory.length,0)
  }
  function test_statistics_missing_sensors() {
   controls.visible=false
   SystemMonitorService.hasCpuTemp=false;SystemMonitorService.hasGpuTemp=false;SystemMonitorService.hasGpuStats=false
   const view=createTemporaryObject(statsViewFixture,scene)
   verify(view!==null);wait(30)
   const message=byProperty(view,"text","Temperature unavailable")
   verify(message!==null && message.visible,"missing sensor is explicit")
   const gpu=byProperty(view,"title","GPU")
   verify(gpu!==null && !gpu.visible,"unsupported GPU is hidden")
  }
  function test_statistics_readings_and_layout_data() {return [{tag:"minimal",pack:"minimal"},{tag:"md3",pack:"md3"}]}
  function test_statistics_readings_and_layout(data) {
   controls.visible=false;AppConfig.designSystem=data.pack
   SystemMonitorService.cpuHistory=[0.1,0.95,0.05];SystemMonitorService.gpuHistory=[0.2,0.4,0.3];SystemMonitorService.ramHistory=[0.3,0.38,0.4]
   for(const width of [280,600]) for(const scale of [1,1.3,2]) {
    AppConfig.fontScale=scale
    const view=createTemporaryObject(statsViewFixture,scene,{width:width})
    verify(view!==null);wait(30)
    verify(byProperty(view,"text","12%")!==null,"CPU load is visible")
    verify(byProperty(view,"text","Temperature · 49 °C")!==null,"temperature value is visible")
    verify(byProperty(view,"text","Load average · 1 / 5 / 15 min\n1.20 / 0.80 / 0.50")!==null)
    verify(view.implicitHeight>0)
    const graph=byProperty(view,"values",SystemMonitorService.cpuHistory)
    verify(graph!==null);compare(graph.values[1],0.95)
    if(width===600 && scale===1.3) {scene.width=600;scene.height=view.implicitHeight;grabImage(scene).save("RENDERS/statistics-"+data.pack+".png")}
    view.destroy()
   }
  }
  function test_combo_long_list_scroll() {
   controls.visible=false
   let entries=[]
   for(let i=0;i<40;i++) entries.push("Choice "+i)
   const combo=createTemporaryObject(comboFixture,scene,{model:entries,y:scene.height-80})
   verify(combo!==null);combo.forceActiveFocus();keyClick(Qt.Key_Return);wait(30)
   verify(combo.open);keyClick(Qt.Key_End);wait(30)
   compare(combo.currentIndex,39)
   const popup=Array.from(combo.data).find(item=>item.closePolicy===(Popup.CloseOnEscape | Popup.CloseOnPressOutside))
   verify(popup!==undefined)
   verify(popup.height<=scene.height,"menu fits window")
   const viewport=byProperty(popup.contentItem,"boundsBehavior",Flickable.StopAtBounds)
   verify(viewport!==null);verify(viewport.contentY>0,"keyboard selection scrolls")
   verify(viewport.contentY+viewport.height>=viewport.contentHeight-Tokens.spacing.extraSmall-1,"last choice revealed")
   keyClick(Qt.Key_Escape);compare(combo.open,false)
  }
  function test_tray_menu_rebuild() {
   controls.visible=false
   const child=createTemporaryObject(menuEntryFixture,scene,{text:"Old child"})
   const entry=menuEntryFixture.createObject(scene,{text:"More",hasChildren:true,entries:[child]})
   const handle=createTemporaryObject(menuEntryFixture,scene,{entries:[entry]})
   const menu=createTemporaryObject(trayMenuFixture,scene,{trayItem:handle})
   verify(menu!==null);wait(30);menu.focusInitial();keyClick(Qt.Key_Right);wait(30)
   compare(menu.depth,2)
   const newChild=createTemporaryObject(menuEntryFixture,scene,{text:"New child"})
   const replacement=createTemporaryObject(menuEntryFixture,scene,{text:"More",hasChildren:true,entries:[newChild]})
   handle.entries=[replacement];entry.destroy();wait(50)
   compare(menu.depth,2)
   verify(byProperty(menu,"headline","New child")!==null,"submenu follows replacement handle")
  }
  function test_tray_menu_density_data() {return [{tag:"minimal",pack:"minimal"},{tag:"md3",pack:"md3"}]}
  function test_tray_menu_density(data) {
   controls.visible=false;AppConfig.designSystem=data.pack
   const first=createTemporaryObject(menuEntryFixture,scene,{text:"First action"})
   const separator=createTemporaryObject(menuEntryFixture,scene,{isSeparator:true})
   const toggle=createTemporaryObject(menuEntryFixture,scene,{text:"Enabled",buttonType:QsMenuButtonType.CheckBox,checkState:Qt.Checked})
   const last=createTemporaryObject(menuEntryFixture,scene,{text:"Last action"})
   const handle=createTemporaryObject(menuEntryFixture,scene,{entries:[first,separator,toggle,last]})
   const menu=createTemporaryObject(trayMenuFixture,scene,{trayItem:handle,maximumHeight:scene.height})
   verify(menu!==null);wait(30)
   const row=byProperty(menu,"headline","First action")
   const divider=byProperty(menu,"separator",true)
   verify(row!==null && divider!==null)
   for(const scale of [1,1.3,2]) {
    AppConfig.fontScale=scale;wait(20)
    compare(divider.height,Tokens.spacing.small*2+Tokens.size.outline)
    verify(row.height>=Tokens.touchTarget.minimum)
    if(scale===1)verify(row.height<Tokens.size.listItem,"menu row is denser than an ordinary list row")
    const sum=row.height+divider.height+byProperty(menu,"headline","Enabled").height+byProperty(menu,"headline","Last action").height
    verify(Math.abs(menu.implicitHeight-sum)<=1,"menu has no extra inter-item space")
   }
   AppConfig.fontScale=1.3;wait(20)
   grabImage(menu).save("RENDERS/tray-menu-density-"+data.pack+".png")
   menu.focusInitial();keyClick(Qt.Key_Down);wait(10)
   verify(byProperty(menu,"headline","Enabled").activeFocus,"navigation skips the compact separator")
  }
  function test_tray_menu_long_scroll_data() {return [{tag:"minimal",pack:"minimal"},{tag:"md3",pack:"md3"}]}
  function test_tray_menu_long_scroll(data) {
   controls.visible=false;AppConfig.designSystem=data.pack
   let entries=[]
   for(let i=0;i<30;i++) entries.push(createTemporaryObject(menuEntryFixture,scene,{text:"Action "+i}))
   const handle=createTemporaryObject(menuEntryFixture,scene,{entries:entries})
   const menu=createTemporaryObject(trayMenuFixture,scene,{trayItem:handle})
   verify(menu!==null);wait(30);menu.focusInitial();keyClick(Qt.Key_End);wait(40)
   const last=byProperty(menu,"headline","Action 29")
   verify(last.activeFocus)
   const pos=last.mapToItem(menu,0,0)
   verify(pos.y>=0 && pos.y+last.height<=menu.height+1,"last action scrolls into the viewport")
  }
  function test_tooltip_geometry_data() {return [{tag:"minimal",pack:"minimal"},{tag:"md3",pack:"md3"}]}
  function test_tooltip_geometry(data) {
   controls.visible=false;AppConfig.designSystem=data.pack
   for(const scale of [1,1.3,2]) {
    AppConfig.fontScale=scale
    const tip=createTemporaryObject(hintFixture,scene,{text:"<b>Literal name</b> "+"A long network name ".repeat(20),maximumWidth:240})
    verify(tip!==null);wait(30)
    compare(tip.width,240)
    verify(tip.height>Tokens.typography.bodySmall.size*3,"wrapped height includes all lines")
    const label=byProperty(tip,"textStyle","bodySmall")
    compare(label.textFormat,Text.PlainText)
    verify(label.y+label.height<=tip.height,"text fits the surface")
   }
  }
  function test_tooltip_switch_and_hide() {
   controls.visible=false;AppConfig.reduceMotion=false
   const manager=createTemporaryObject(tooltipManagerFixture,scene)
   verify(manager!==null);manager.container=scene
   const a=createTemporaryObject(tooltipFixture,scene,{tooltip:manager,owner:scene,text:"First"})
   const b=createTemporaryObject(tooltipFixture,scene,{tooltip:manager,owner:scene,text:"Second "+"long ".repeat(40)})
   a.show=true
   compare(manager.shownItem,null)
   tryCompare(manager,"shownItem",a)
   tryCompare(a,"opacity",1)
   a.show=false;b.show=true
   tryCompare(manager,"shownItem",b)
   compare(a.visible,false)
   tryCompare(b,"opacity",1)
   verify(b.height>a.height)
   b.show=false;wait(30);b.show=true
   wait(200);compare(manager.shownItem,b);compare(b.targetVisible,true)
   manager.suspended=true;compare(manager.shownItem,null);compare(b.visible,false)
   manager.suspended=false;tryCompare(manager,"shownItem",b);tryCompare(b,"opacity",1)
   b.show=false;tryCompare(manager,"shownItem",null)
   compare(b.visible,false)
   a.show=true;a.show=false;wait(400);compare(manager.shownItem,null)
   AppConfig.reduceMotion=true
  }
  function test_tray_menu_keyboard_and_checks() {
   controls.visible=false
   const first=createTemporaryObject(menuEntryFixture,scene,{text:"Disabled",enabled:false})
   const separator=createTemporaryObject(menuEntryFixture,scene,{isSeparator:true})
   const toggle=createTemporaryObject(menuEntryFixture,scene,{text:"Enabled",buttonType:QsMenuButtonType.CheckBox,checkState:Qt.Checked})
   const child=createTemporaryObject(menuEntryFixture,scene,{text:"Child"})
   const submenu=createTemporaryObject(menuEntryFixture,scene,{text:"More",hasChildren:true,entries:[child]})
   const handle=createTemporaryObject(menuEntryFixture,scene,{entries:[first,separator,toggle,submenu]})
   const menu=createTemporaryObject(trayMenuFixture,scene,{trayItem:handle})
   verify(menu!==null);wait(50);menu.focusInitial();wait(30)
   const toggleRow=byProperty(menu,"headline","Enabled")
   verify(toggleRow.activeFocus,"disabled entries and separators skipped")
   compare(toggleRow.leadingIcon,"check_box")
   keyClick(Qt.Key_End);wait(20)
   const more=byProperty(menu,"headline","More");verify(more.activeFocus)
   keyClick(Qt.Key_Right);wait(50);compare(menu.depth,2)
   verify(byProperty(menu,"headline","Child").activeFocus)
   keyClick(Qt.Key_Escape);wait(50);compare(menu.depth,1)
   verify(more.activeFocus,"parent selection restored")
   keyClick(Qt.Key_Up);keyClick(Qt.Key_Return);compare(toggle.triggers,1)
   verify(menu.implicitHeight<=menu.maximumHeight)
  }
  function test_bar_stable_hover_and_clicks() {
   controls.visible=false
   const clock=createTemporaryObject(clockFixture,scene,{widgetConfig:{settings:{showDate:false}}})
   verify(clock!==null);wait(30)
   const width=clock.width
   mouseMove(clock,1,1);wait(80);compare(clock.width,width,"clock must not expand on hover")
   mouseClick(clock,1,1);compare(GlobalStates.lastAction,"dashboard-calendar")
   clock.widgetConfig={clickAction:"dashboard-quick",settings:{showDate:true}}
   mouseClick(clock,1,1);compare(GlobalStates.lastAction,"dashboard-quick","explicit config action wins")
   const volume=createTemporaryObject(volumeFixture,scene,{y:80})
   verify(volume!==null);wait(20)
   mouseClick(volume,1,1);compare(GlobalStates.lastAction,"audio")
   const muted=AudioService.masterMuted
   mouseClick(volume,1,1,Qt.RightButton);compare(AudioService.masterMuted,!muted)
   const weather=createTemporaryObject(weatherFixture,scene,{y:160})
   verify(weather!==null);wait(20);mouseClick(weather,1,1)
   compare(GlobalStates.lastAction,"dashboard-weather")
  }
  function test_volume_unavailable_and_service_commands() {
   controls.visible=false
   AudioService.defaultSink=null
   const volume=createTemporaryObject(volumeFixture,scene)
   verify(volume!==null);wait(20)
   verify(byProperty(volume,"text","--%")!==null,"missing output is not zero volume")
   const event={angleDelta:{y:120},accepted:true}
   volume.wheelHandler(event);verify(!event.accepted)
   mouseClick(volume,1,1,Qt.RightButton);verify(!AudioService.masterMuted)
   mouseClick(volume,1,1);compare(GlobalStates.lastAction,"audio","device selection remains reachable")
   const sink=createTemporaryObject(audioNode,scene)
   AudioService.defaultSink=sink;AudioService.masterVolume=0.45;wait(20)
   volume.wheelHandler(event);verify(event.accepted);fuzzyCompare(AudioService.masterVolume,0.49,0.0001)
   mouseClick(volume,1,1,Qt.RightButton);verify(AudioService.masterMuted)
   AudioService.masterVolume=0.73;wait(20);verify(byProperty(volume,"text","73%")!==null)
   volume.scrollable=false;event.accepted=true;volume.wheelHandler(event);verify(!event.accepted)
  }
  function test_audio_initial_focus_waits_for_audio_interface() {
   controls.visible=false
   const pending=createTemporaryObject(audioNode,scene)
   pending.audio=null;AudioService.defaultSink=pending;AudioService.defaultSource=null
   const panel=createTemporaryObject(audioFixture,scene)
   verify(panel!==null);wait(20)
   const output=byProperty(panel,"title","Output")
   verify(!output.available)
   panel.focusInitial();verify(byProperty(panel,"iconName","close").activeFocus)
   const microphone=createTemporaryObject(audioNode,scene)
   AudioService.defaultSource=microphone;wait(20);panel.focusInitial()
   const input=byProperty(panel,"title","Microphone")
   verify(input.available);keyClick(Qt.Key_Space);verify(AudioService.micMuted,"initial focus activates microphone mute")
  }
  function test_media_button_owns_click() {
   controls.visible=false
   const media=createTemporaryObject(mediaFixture,scene,{compact:true})
   verify(media!==null);wait(30)
   const width=media.width
   mouseMove(media,1,1);wait(80);compare(media.width,width,"compact media width")
   const play=byProperty(media,"iconName",MprisController.isPlaying ? "pause" : "play_arrow")
   verify(play!==null);mouseClick(play,play.width/2,play.height/2)
   compare(MprisController.toggles,1);compare(GlobalStates.actionCount,0,"child button must not open dashboard")
   mouseClick(media,1,1);compare(GlobalStates.lastAction,"dashboard-quick")
   media.compact=false;wait(30)
   const expandedWidth=media.width
   mouseMove(scene,700,500);wait(80);compare(media.width,expandedWidth,"full media width")
  }
  function test_quick_action_semantics() {
   controls.visible=false;dashboard.visible=true;GlobalStates.dashboardOpenIndex=0;wait(30)
   const wifi=byProperty(dashboard,"label","Wi-Fi")
   const dnd=byProperty(dashboard,"label","Do not disturb")
   const screenshot=byProperty(dashboard,"label","Screenshot")
   verify(wifi!==null && dnd!==null && screenshot!==null)
   verify(!wifi.showStateIndicator);compare(wifi.trailingIcon,"chevron_right")
   verify(dnd.showStateIndicator)
   verify(!screenshot.showStateIndicator);compare(screenshot.trailingIcon,"")
   wifi.forceActiveFocus();keyClick(Qt.Key_Return);compare(GlobalStates.connectionsSection,"wifi")
   AppConfig.disabledModules=["screenshot"];wait(20);verify(!screenshot.visible)
   VPNService.enabled=false;NightLightService.available=false;wait(30)
   verify(byProperty(dashboard,"label","VPN")===null)
   verify(!byProperty(dashboard,"label","Night light").visible)
  }
  function test_ipc_live_signatures_parser() {
   const data=createTemporaryObject(ipcFixture,scene)
   verify(data!==null)
   const surface=data.parseSurface("target globalstates\n  function openConnections(section: string): void\n  function futureCommand(value: int): bool\ntarget config\n  function validate(): string\n")
   compare(surface.length,2);compare(surface[0].name,"config")
   const functions=surface[1].functions
   compare(functions.length,2);compare(functions[0].name,"futureCommand")
   compare(functions[0].params,"value: int");compare(functions[0].returns,"bool")
   compare(functions[1].name,"openConnections");verify(functions[1].description.includes("wifi"))
   compare(data.parseSurface("target config\n  function validate(): string\n")[0].functions.length,1,"metadata must not add absent commands")
  }
  function test_audio_controls_and_picker() {
   controls.visible=false
   const sink=createTemporaryObject(audioNode,scene,{id:10,name:"Speakers"})
   const mic=createTemporaryObject(audioNode,scene,{id:11,name:"Microphone"})
   const headphones=createTemporaryObject(audioNode,scene,{id:12,name:"Headphones"})
   AudioService.defaultSink=sink;AudioService.defaultSource=mic
   AudioService.sinkNodes=[sink,headphones];AudioService.sourceNodes=[mic]
   const panel=createTemporaryObject(audioFixture,scene)
   verify(panel!==null);wait(30)
   const output=byProperty(panel,"title","Output")
   const input=byProperty(panel,"title","Microphone")
   verify(output!==null && input!==null)
   output.focusInitial();keyClick(Qt.Key_Space);verify(AudioService.masterMuted)
   input.focusInitial();keyClick(Qt.Key_Space);verify(AudioService.micMuted)
   input.volumeRequested(0.25);compare(AudioService.micVolume,0.25)
   output.volumeRequested(0.6);compare(AudioService.masterVolume,0.6)
   const deviceRow=byProperty(output,"headline","Output")
   deviceRow.forceActiveFocus();keyClick(Qt.Key_Return);wait(20);verify(panel.modalOpen)
   const choice=byProperty(panel,"headline","Headphones")
   choice.forceActiveFocus();keyClick(Qt.Key_Return);wait(30)
   verify(!panel.modalOpen);compare(AudioService.defaultSink.id,12);verify(deviceRow.activeFocus)
  }
  function test_audio_mixer_lifecycle() {
   controls.visible=false
   const node=createTemporaryObject(audioNode,scene,{id:20,name:"Player"})
   AudioService.streamNodes=[node]
   const panel=createTemporaryObject(audioFixture,scene)
   verify(panel!==null);wait(20)
   verify(byProperty(panel,"appName","Player")===null,"mixer is lazy")
   const row=byProperty(panel,"headline","Applications")
   row.forceActiveFocus();keyClick(Qt.Key_Return);wait(20)
   const stream=byProperty(panel,"appName","Player")
   verify(stream!==null);verify(panel.mixerExpanded)
   GlobalStates.audioOpen=false;wait(20)
   verify(!panel.mixerExpanded);verify(byProperty(panel,"appName","Player")===null)
   GlobalStates.audioOpen=true;AudioService.streamNodes=[];node.destroy();wait(20)
   panel.mixerExpanded=true;wait(20);verify(panel.implicitHeight>0)
  }
  function test_audio_density_data() {
   return [{tag:"minimal",pack:"minimal"},{tag:"md3",pack:"md3"}]
  }
  function test_audio_density(data) {
   controls.visible=false;AppConfig.designSystem=data.pack
   const sink=createTemporaryObject(audioNode,scene,{id:10,name:"Speakers with a long device description"})
   const mic=createTemporaryObject(audioNode,scene,{id:11,name:"USB microphone"})
   AudioService.defaultSink=sink;AudioService.defaultSource=mic
   const panel=createTemporaryObject(audioFixture,scene)
   verify(panel!==null)
   for(const scale of [1,1.3,2]) {
    AppConfig.fontScale=scale;wait(30)
    verify(panel.implicitHeight>0)
    const output=byProperty(panel,"title","Output")
    verify(output.x+output.width<=output.parent.width)
   }
   AppConfig.fontScale=1.3;wait(30);grabImage(panel).save("RENDERS/audio-"+data.tag+".png")
   AudioService.defaultSink=null;AudioService.defaultSource=null;wait(30)
   const emptyHeight=panel.implicitHeight
   verify(emptyHeight>0)
   AudioService.defaultSink=sink;wait(30);verify(panel.implicitHeight>emptyHeight,"unavailable device hides its controls")
  }
  function test_tray_icon_actions() {
   controls.visible=false
   const item=createTemporaryObject(trayNode,scene)
   const icon=createTemporaryObject(trayIconFixture,scene,{trayItem:item})
   verify(icon!==null);wait(20)
   mouseClick(icon,icon.width/2,icon.height/2);compare(item.activations,1)
   item.onlyMenu=true;mouseClick(icon,icon.width/2,icon.height/2);compare(item.activations,1);compare(PopoutsState.name,"traymenu")
   mouseClick(icon,icon.width/2,icon.height/2,Qt.MiddleButton);compare(item.secondaryActivations,1)
   mouseWheel(icon,icon.width/2,icon.height/2,0,60)
   mouseWheel(icon,icon.width/2,icon.height/2,0,60);compare(item.scrollSteps,1)
  }
  function test_tray_limit_and_attention() {
   controls.visible=false
   const nodes=[]
   for(let i=0;i<7;i++) nodes.push(createTemporaryObject(trayNode,scene,{id:"app"+i}))
   SystemTray.items=({values:nodes})
   const widget=createTemporaryObject(trayFixture,scene,{widgetConfig:{settings:{maxVisible:2,pinnedIds:["app6"]}}})
   verify(widget!==null);wait(30)
   compare(widget.trayModel.visibleItems.length,2);compare(widget.trayModel.visibleItems[0].id,"app6")
   compare(widget.trayModel.hiddenItems.length,5)
   const width=widget.width
   nodes.push(createTemporaryObject(trayNode,scene,{id:"another"}));SystemTray.items=({values:nodes});wait(20)
   compare(widget.width,width,"new tray apps must not grow the bar")
   nodes[3].status=Status.NeedsAttention;wait(20);compare(widget.trayModel.hiddenAttentionCount,1)
   AppConfig.disabledModules=["popouts"];wait(20);compare(widget.trayModel.hiddenItems.length,0)
   AppConfig.disabledModules=[]
   SystemMonitorService.storageVolumes=[];SystemMonitorService.storageDrives=[];SystemMonitorService.storageSummary=({available:true,name:"System",availableFormatted:"100 GiB",severity:0})
   SystemMonitorService.hasCpuTemp=true;SystemMonitorService.hasGpuTemp=true;SystemMonitorService.hasGpuStats=true
  }
  function test_tray_overflow_context_transition() {
   controls.visible=false
   const first=createTemporaryObject(trayNode,scene,{id:"first"})
   const second=createTemporaryObject(trayNode,scene,{id:"second"})
   SystemTray.items=({values:[first,second]})
   const widget=createTemporaryObject(trayFixture,scene,{widgetConfig:{settings:{maxVisible:0}}})
   verify(widget!==null);wait(20)
   PopoutsState.openPopout("trayoverflow",widget.trayModel,widget)
   const overflow=createTemporaryObject(overflowFixture,scene,{trayModel:widget.trayModel})
   verify(overflow!==null);wait(20)
   const row=byProperty(overflow,"headline","first")
   verify(row!==null);row.forceActiveFocus();keyClick(Qt.Key_Menu);wait(20)
   compare(PopoutsState.name,"traymenu");verify(PopoutsState.open)
   compare(PopoutsState.sourceItem,widget,"submenu uses a surviving bar anchor")
   overflow.trayModel=null;wait(20);compare(PopoutsState.name,"traymenu","old overflow must not close replacement menu")
  }
  function test_connection_panel_state() {
   const state=createTemporaryObject(panelState,scene)
   verify(state!==null)
   state.openDashboardTab(4);verify(state.connectionsOpen);verify(!state.dashboardOpen);compare(state.connectionsSection,"wifi")
   state.openDashboardTab(3);verify(state.audioOpen);verify(!state.connectionsOpen)
   state.openDashboardTab(2);verify(state.dashboardOpen);verify(!state.audioOpen);compare(state.dashboardOpenIndex,2)
   state.handleClickAction("dashboard-network");verify(state.connectionsOpen)
   state.handleClickAction("dashboard-network");verify(!state.connectionsOpen)
   state.openConnections("bluetooth",null);compare(state.connectionsSection,"bluetooth")
   state.closeAllPanels();state.lockscreenActive=true
   state.openConnections("wifi",null);verify(!state.connectionsOpen)
   state.lockscreenActive=false;AppConfig.disabledModules=["connections"]
   state.openConnections("wifi",null);verify(!state.connectionsOpen)
   AppConfig.disabledModules=[]
   SystemMonitorService.storageVolumes=[];SystemMonitorService.storageDrives=[];SystemMonitorService.storageSummary=({available:true,name:"System",availableFormatted:"100 GiB",severity:0})
   SystemMonitorService.hasCpuTemp=true;SystemMonitorService.hasGpuTemp=true;SystemMonitorService.hasGpuStats=true
  }
  function test_connections_accordion_and_scan() {
   controls.visible=false
   const panel=createTemporaryObject(connectionsPanel,scene)
   verify(panel!==null);wait(20)
   const wifi=byProperty(panel,"headline","Wi-Fi")
   const bt=byProperty(panel,"headline","Bluetooth")
   wifi.forceActiveFocus();keyClick(Qt.Key_Return);wait(20)
   compare(panel.section,"wifi");verify(NetworkService.scanning)
   bt.forceActiveFocus();keyClick(Qt.Key_Return);wait(20)
   compare(panel.section,"bluetooth");verify(!NetworkService.scanning);verify(!BluetoothService.scanning)
   const pair=byProperty(panel,"text","Pair new device…")
   verify(pair!==null);pair.forceActiveFocus();keyClick(Qt.Key_Space);wait(20)
   verify(BluetoothService.scanning)
   keyClick(Qt.Key_Escape);wait(20);verify(!BluetoothService.scanning);verify(!panel.findingBluetooth)
   GlobalStates.connectionsOpen=false;wait(20);verify(!NetworkService.scanning && !BluetoothService.scanning)
  }
  function test_connections_radio_collapse_data() {
   return [{tag:"wifi-minimal",section:"wifi",pack:"minimal"},
    {tag:"wifi-md3",section:"wifi",pack:"md3"},
    {tag:"bluetooth-minimal",section:"bluetooth",pack:"minimal"},
    {tag:"bluetooth-md3",section:"bluetooth",pack:"md3"}]
  }
  function test_connections_radio_collapse(data) {
   controls.visible=false;AppConfig.designSystem=data.pack
   const node=createTemporaryObject(wifiNode,scene)
   NetworkService.networks=[node]
   BluetoothService.pairedDevices=[{name:"Headphones",address:"AA",device:null,connected:false,battery:-1}]
   GlobalStates.connectionsSection=data.section
   const panel=createTemporaryObject(connectionsPanel,scene)
   verify(panel!==null);wait(30)
   const header=byProperty(panel,"headline",data.section==="wifi" ? "Wi-Fi" : "Bluetooth")
   const toggle=byProperty(header,"showCheckIcon",false)
   verify(toggle!==null)
   const expanded=panel.implicitHeight
   toggle.forceActiveFocus();keyClick(Qt.Key_Space);wait(30)
   const disabled=panel.implicitHeight
   verify(disabled<expanded,"disabling the radio shrinks the panel")
   GlobalStates.connectionsSection="";wait(30)
   compare(disabled,panel.implicitHeight,"disabled section leaves no list space")
   GlobalStates.connectionsSection=data.section;wait(30)
   compare(panel.implicitHeight,disabled,"opening a disabled radio leaves no empty list")
   toggle.forceActiveFocus();keyClick(Qt.Key_Space);wait(30)
   compare(panel.implicitHeight,expanded,"enabling the radio restores list height")
  }
  function test_connections_radio_recovery_without_reopen() {
   controls.visible=false
   GlobalStates.connectionsSection="wifi"
   const panel=createTemporaryObject(connectionsPanel,scene)
   verify(panel!==null);wait(20);verify(NetworkService.scanning)
   NetworkService.wifiEnabled=false;NetworkService.deviceReady=false;wait(10)
   verify(!NetworkService.scanning)
   NetworkService.wifiEnabled=true;wait(10);verify(!NetworkService.scanning)
   NetworkService.deviceReady=true;wait(20)
   verify(NetworkService.scanning,"discovery restarts when the native adapter becomes ready")
   NetworkService.deviceReady=false;wait(10)
   NetworkService.deviceReady=true;wait(20)
   verify(NetworkService.scanning,"adapter recovery does not require reopening Connections")
  }
  function test_connections_password_and_menu() {
   controls.visible=false
   const node=createTemporaryObject(wifiNode,scene)
   NetworkService.networks=[node]
   GlobalStates.connectionsSection="wifi"
   const panel=createTemporaryObject(connectionsPanel,scene)
   verify(panel!==null);wait(30)
   const row=byProperty(panel,"headline","Test Wi-Fi")
   verify(row!==null);row.forceActiveFocus();keyClick(Qt.Key_Return);wait(30)
   const input=byProperty(panel,"placeholderText","Password")
   verify(input!==null);verify(input.inputItem.activeFocus)
   input.text="test-secret";keyClick(Qt.Key_Return);wait(30)
   compare(NetworkService.connections,1);compare(NetworkService.passwordTarget.name,"Test Wi-Fi");compare(input.text,"");verify(!panel.modalOpen);verify(row.activeFocus)
   node.connected=true;row.forceActiveFocus();keyClick(Qt.Key_Return);wait(30)
   compare(NetworkService.disconnections,0);verify(panel.modalOpen)
   keyClick(Qt.Key_Down);keyClick(Qt.Key_Return);wait(30)
   verify(panel.modalOpen,"details replaced menu")
   keyClick(Qt.Key_Escape);wait(30);verify(!panel.modalOpen);verify(row.activeFocus,"details restores initiating row")
  }
  function test_connections_ipv6_details_data() {return [{tag:"minimal",pack:"minimal"},{tag:"md3",pack:"md3"}]}
  function test_connections_ipv6_details(data) {
   controls.visible=false;AppConfig.designSystem=data.pack
   EthernetService.connected=true;EthernetService.interfaceName="eth0"
   EthernetService.ipv4Addresses=[];EthernetService.ipv6Addresses=["2001:db8::10/64","fe80::10/64"]
   EthernetService.ipv4Gateway="";EthernetService.ipv6Gateway="fe80::1"
   const panel=createTemporaryObject(connectionsPanel,scene)
   wait(20)
   const row=byProperty(panel,"headline","Ethernet")
   verify(row!==null && row.visible)
   row.forceActiveFocus();keyClick(Qt.Key_Return);wait(20)
   const action=byProperty(panel,"text","Connection details")
   verify(action!==null)
   keyClick(Qt.Key_Return);wait(20)
   verify(panel.detailLines.includes("IPv4: Not assigned"))
   verify(panel.detailLines.includes("IPv6: 2001:db8::10/64, fe80::10/64"))
   verify(panel.detailLines.includes("IPv6 gateway: fe80::1"))
   EthernetService.ipv4Addresses=["192.0.2.10/24"];EthernetService.ipv6Addresses=[];EthernetService.ipv6Gateway=""
   wait(10)
   verify(panel.detailLines.includes("IPv4: 192.0.2.10/24"))
   verify(panel.detailLines.includes("IPv6: Not assigned"))
   verify(panel.detailLines.includes("IPv6 gateway: None"))
   keyClick(Qt.Key_Escape);wait(20)
   EthernetService.connected=false;EthernetService.interfaceName="";EthernetService.ipv4Addresses=[]
  }
  function test_connections_vpn_uuid_and_rename() {
   controls.visible=false;GlobalStates.connectionsSection="vpn"
   VPNService.profiles=[{uuid:"first",name:"Same: VPN",connected:false,busy:false,state:0},{uuid:"second",name:"Same: VPN",connected:true,busy:false,state:2}]
   const panel=createTemporaryObject(connectionsPanel,scene)
   wait(20)
   const row=byProperty(panel,"supportingText", "Connected")
   verify(row!==null);row.forceActiveFocus();keyClick(Qt.Key_Return);wait(20);keyClick(Qt.Key_Return);wait(20)
   compare(VPNService.lastUuid,"second")
   VPNService.profiles=[{uuid:"first",name:"Renamed: VPN",connected:false,busy:false,state:0}]
   wait(20)
   const renamed=byProperty(panel,"headline","Renamed: VPN")
   verify(renamed!==null);renamed.forceActiveFocus();keyClick(Qt.Key_Return)
   compare(VPNService.lastUuid,"first")
  }
  function test_connections_legacy_wep_uses_editor() {
   controls.visible=false
   const node=createTemporaryObject(wifiNode,scene,{security:WifiSecurityType.StaticWep})
   NetworkService.networks=[node];GlobalStates.connectionsSection="wifi"
   const panel=createTemporaryObject(connectionsPanel,scene);wait(20)
   const row=byProperty(panel,"headline","Test Wi-Fi")
   row.forceActiveFocus();keyClick(Qt.Key_Return);wait(20)
   verify(panel.modalOpen);compare(NetworkService.connections,0)
   verify(byProperty(panel,"text","This network needs advanced authentication")!==null)
  }
  function test_connections_disappearing_network() {
   controls.visible=false
   const node=createTemporaryObject(wifiNode,scene)
   NetworkService.networks=[node];GlobalStates.connectionsSection="wifi"
   const panel=createTemporaryObject(connectionsPanel,scene)
   verify(panel!==null);wait(20)
   const row=byProperty(panel,"headline","Test Wi-Fi")
   row.forceActiveFocus();keyClick(Qt.Key_Return);wait(20);verify(panel.modalOpen)
   NetworkService.networks=[];node.destroy();wait(20)
   compare(panel.targetNetwork,null)
   keyClick(Qt.Key_Escape);wait(20);verify(!panel.modalOpen)
   keyClick(Qt.Key_Escape);wait(20);compare(panel.section,"")
  }
  function test_auth_button_native_activation_data() {
   const rows=[]
   for(const pack of ["minimal","md3"])for(const kind of ["network","pairing"])for(const cancel of [false,true])for(const key of [Qt.Key_Return,Qt.Key_Enter,Qt.Key_Space])rows.push({tag:pack+"-"+kind+"-"+cancel+"-"+key,pack:pack,kind:kind,cancel:cancel,key:key})
   return rows
  }
  function test_auth_button_native_activation(data) {
   controls.visible=false;dashboard.visible=false;AppConfig.designSystem=data.pack
   const network=data.kind==="network"
   const view=network
    ? createTemporaryObject(networkAuthFixture,scene,{fields:[{key:"password",label:"Password",secret:true}],requestToken:"test"})
    : createTemporaryObject(pairingFixture,scene,{requestKind:"confirm",code:"123456",requestToken:"test"})
   tryVerify(()=>view.visible)
   if(network) {
    tryVerify(()=>findChild(view,"networkCredential_password")?.inputItem.activeFocus ?? false)
    findChild(view,"networkCredential_password").text="fixture-password"
   } else tryVerify(()=>findChild(view,"pairingCancel")?.activeFocus ?? false)
   // The prompt schedules its initial editor focus after opening.
   wait(10)
   const name=network ? (data.cancel ? "networkAuthCancel" : "networkAuthenticate") : (data.cancel ? "pairingCancel" : "pairingConfirm")
   const button=findChild(view,name)
   verify(button!==null && button.enabled)
   const pressed=createTemporaryObject(dockSignalSpy,scene,{target:button,signalName:"pressed"})
   const released=createTemporaryObject(dockSignalSpy,scene,{target:button,signalName:"released"})
   const clicked=createTemporaryObject(dockSignalSpy,scene,{target:button,signalName:"clicked"})
   button.forceActiveFocus();keyClick(data.key)
   compare(pressed.count,1,"pressed");compare(released.count,1,"released");compare(clicked.count,1,"clicked")
   compare(view.answers,data.cancel ? 0 : 1);compare(view.rejections,data.cancel ? 1 : 0)
  }
  function test_network_auth_input_replacement_and_cancel() {
   controls.visible=false
   const fields=[{key:"psk",label:"Wi-Fi password",secret:true}]
   const view=createTemporaryObject(networkAuthFixture,scene,{connectionName:"Network <b>plain</b>",fields:fields,requestToken:"first"})
   verify(view)
   tryVerify(()=>findChild(view,"networkCredential_psk")!==null)
   const editor=findChild(view,"networkCredential_psk")
   tryVerify(()=>editor.inputItem.activeFocus)
   editor.text="wrong-password"
   view.requestToken="second"
   compare(editor.text,"")
   tryCompare(view,"_shownToken","second")
   const replacement=findChild(view,"networkCredential_psk")
   replacement.text="new-password";replacement.forceActiveFocus()
   keyClick(Qt.Key_Return)
   compare(view.answers,1);compare(view.submittedToken,"second");compare(view.submittedValue,"new-password")
   compare(replacement.text,"")
   view.requestToken="third"
   tryCompare(view,"_shownToken","third")
   tryVerify(()=>findChild(view,"networkCredential_psk").inputItem.activeFocus)
   keyClick(Qt.Key_Escape);compare(view.rejections,1)
   tryVerify(()=>!view.visible)
  }
  function test_network_auth_multiple_fields_data() {return [{tag:"minimal",pack:"minimal"},{tag:"md3",pack:"md3"}]}
  function test_network_auth_multiple_fields(data) {
   controls.visible=false;AppConfig.designSystem=data.pack
   const view=createTemporaryObject(networkAuthFixture,scene,{connectionName:"VPN",fields:[{key:"password",label:"Password",secret:true},{key:"otp",label:"One-time code",secret:false}],requestToken:"vpn"})
   tryVerify(()=>view.visible)
   const password=findChild(view,"networkCredential_password")
   const otp=findChild(view,"networkCredential_otp")
   tryVerify(()=>password.inputItem.activeFocus)
   password.text="vpn-password";keyClick(Qt.Key_Return);compare(view.answers,0)
   password.forceActiveFocus();keyClick(Qt.Key_Tab)
   if (!otp.inputItem.activeFocus) keyClick(Qt.Key_Tab)
   tryVerify(()=>otp.inputItem.activeFocus)
   verify(!otp.password)
   otp.text="012345";keyClick(Qt.Key_Return)
   compare(view.answers,1);compare(view.submittedValue,"vpn-password")
   compare(password.text,"");compare(otp.text,"")
  }
  function test_pairing_confirmation_requires_choice() {
   controls.visible=false
   const view=createTemporaryObject(pairingFixture,scene,{requestKind:"confirm",deviceName:"Keyboard <b>plain</b>",deviceAddress:"AA:BB:CC:DD:EE:FF",code:"012345",requestToken:"one"})
   verify(view);tryVerify(()=>view.visible)
   const cancel=findChild(view,"pairingCancel")
   tryVerify(()=>cancel.activeFocus)
   keyClick(Qt.Key_Return);compare(view.answers,0);compare(view.rejections,1)
   tryVerify(()=>!view.visible)
  }
  function test_pairing_input_and_replacement() {
   controls.visible=false
   const view=createTemporaryObject(pairingFixture,scene,{requestKind:"passkey",deviceName:"Keyboard",requestToken:"one"})
   const field=findChild(view,"pairingInput")
   tryVerify(()=>field.inputItem.activeFocus)
   verify(!findChild(view,"pairingConfirm").enabled)
   keyClick(Qt.Key_0);keyClick(Qt.Key_0);keyClick(Qt.Key_1);keyClick(Qt.Key_2)
   compare(field.text,"0012")
   keyClick(Qt.Key_Return);compare(view.answers,1);compare(view.value,"0012")
   wait(1);compare(field.text,"")
   view.requestKind="confirm";view.code="111111";view.requestToken="two"
   tryVerify(()=>findChild(view,"pairingCancel").activeFocus)
   keyClick(Qt.Key_Tab);tryVerify(()=>findChild(view,"pairingConfirm").activeFocus)
   keyClick(Qt.Key_Return);compare(view.answers,2)
   wait(30);verify(!view.visible)
  }
  function test_pairing_layout_data() {return [{tag:"minimal",pack:"minimal"},{tag:"md3",pack:"md3"}]}
  function test_pairing_layout(data) {
   controls.visible=false;AppConfig.designSystem=data.pack
   scene.width=360;scene.height=400
   const view=createTemporaryObject(pairingFixture,scene,{requestKind:"display-passkey",deviceName:"A device with a long Bluetooth name that wraps across several lines",code:"000123",requestToken:"one"})
   tryVerify(()=>view.visible)
   for(const scale of [1,1.3,1.8]) {
    AppConfig.fontScale=scale;wait(20)
    compare(view._code,"000123")
    verify(!findChild(view,"pairingConfirm").visible)
    view.entered=4;wait(1);compare(view._shownToken,"one")
    const cancel=findChild(view,"pairingCancel")
    cancel.forceActiveFocus();wait(20)
    const point=cancel.mapToItem(view,0,0)
    verify(point.y>=0 && point.y+cancel.height<=view.height)
   }
   grabImage(view).save("RENDERS/bluetooth-pairing-"+data.pack+".png")
   keyClick(Qt.Key_Escape);compare(view.rejections,1)
  }
  function test_connections_bluetooth_actions() {
   controls.visible=false
   const node=createTemporaryObject(btNode,scene)
   BluetoothService.pairedDevices=[{name:"Headphones",address:"AA",device:node,connected:true,battery:0.74}]
   GlobalStates.connectionsSection="bluetooth"
   const panel=createTemporaryObject(connectionsPanel,scene)
   verify(panel!==null);wait(30)
   const row=byProperty(panel,"headline","Headphones")
   row.forceActiveFocus();keyClick(Qt.Key_Return);wait(30)
   verify(panel.modalOpen);compare(BluetoothService.connections,0)
   keyClick(Qt.Key_Return);wait(30);compare(BluetoothService.connections,1)
  }
  function test_connections_layout_data() {
   return [{tag:"minimal",pack:"minimal"},{tag:"md3",pack:"md3"}]
  }
  function test_connections_layout(data) {
   controls.visible=false;AppConfig.designSystem=data.pack
   const panel=createTemporaryObject(connectionsPanel,scene)
   verify(panel!==null)
   for(const width of [320,420]) {
    panel.width=width
    for(const scale of [1,1.3,2]) {
     AppConfig.fontScale=scale;wait(30)
     for(const title of ["Wi-Fi","Bluetooth"]) {
      const header=byProperty(panel,"headline",title)
      verify(header.width>0 && header.x+header.width<=header.parent.width)
     }
    }
   }
   AppConfig.fontScale=1.3;panel.width=420;wait(30)
   grabImage(panel).save("RENDERS/connections-"+data.tag+".png")
   const home=createTemporaryObject(wifiNode,scene,{name:"Home network",connected:true,known:true})
   const office=createTemporaryObject(wifiNode,scene,{name:"Office",known:true})
   const nearby=createTemporaryObject(wifiNode,scene,{name:"A nearby network with a long name"})
   NetworkService.networks=[home,office,nearby];GlobalStates.connectionsSection="wifi";wait(30)
   grabImage(panel).save("RENDERS/connections-wifi-"+data.tag+".png")
   const headset=createTemporaryObject(btNode,scene)
   BluetoothService.pairedDevices=[{name:"Headphones",address:"AA",device:headset,connected:true,battery:0.74},{name:"Keyboard",address:"BB",device:null,connected:false,battery:-1}]
   GlobalStates.connectionsSection="bluetooth";wait(30)
   grabImage(panel).save("RENDERS/connections-bluetooth-"+data.tag+".png")

  }
  function test_event_form_keyboard_scroll_data() {
   const rows=[]
   for(const pack of ["minimal","md3"])for(const scale of [1,2])for(const height of [320,600])rows.push({tag:pack+"-"+scale+"-"+height,pack:pack,scale:scale,height:height})
   return rows
  }
  function test_event_form_keyboard_scroll(data) {
   controls.visible=false;dashboard.visible=false;AppConfig.designSystem=data.pack;AppConfig.fontScale=data.scale;AppConfig.reduceMotion=true
   CalendarBackend.calendars=["Test"]
   const host=createTemporaryObject(eventFormHost,scene,{height:data.height})
   const form=createTemporaryObject(eventFormFixture,host)
   form.openDialog(false,null,new Date(2026,9,25));wait(20)
   const scroll=findChild(form,"eventFormScroll")
   verify(scroll!==null)
   const description=byProperty(form,"placeholderText","Add description")
   const categories=byProperty(form,"placeholderText","work, personal, ...")
   let reached=false,reachedDescription=false
   for(let i=0;i<25;i++) {
    const focused=scene.Window.window.activeFocusItem
    if(focused===description.inputItem)reachedDescription=true
    const p=focused.mapToItem(scroll,0,0)
    verify(p.y>=-1 && p.y+focused.height<=scroll.height+1,"Tab reveals focused field: "+focused+" y="+p.y)
    if(focused===categories.inputItem) {reached=true;break}
    keyClick(Qt.Key_Tab);wait(10)
   }
   verify(reached,"categories reached through real Tab traversal")
   verify(reachedDescription,"description participates in the Tab chain")
   keyClick(Qt.Key_A);wait(10)
   compare(categories.text,"a")
   description.inputItem.forceActiveFocus();wait(10)
   description.text=("Line"+String.fromCharCode(10)).repeat(50);description.inputItem.cursorPosition=description.text.length;wait(20)
   function caretVisible() {
    const rect=description.inputItem.cursorRectangle
    const p=description.inputItem.mapToItem(scroll,rect.x,rect.y)
    verify(p.y>=-1 && p.y+rect.height<=scroll.height+1,"caret visible: y="+p.y+" height="+rect.height+" viewport="+scroll.height)
   }
   caretVisible()
   description.inputItem.cursorPosition=0;wait(20);caretVisible()
   keyClick(Qt.Key_A);wait(10);caretVisible()
   description.inputItem.cursorPosition=description.text.length;wait(20);caretVisible()
   keyClick(Qt.Key_Return);keyClick(Qt.Key_B);wait(20);caretVisible()
   const descriptionBefore=description.text
   keyClick(Qt.Key_Tab,Qt.ShiftModifier);wait(10)
   compare(description.text,descriptionBefore)
   const previous=scene.Window.window.activeFocusItem
   const p=previous.mapToItem(scroll,0,0)
   verify(p.y>=-1 && p.y+previous.height<=scroll.height+1,"Shift+Tab reveals previous field: "+previous+" y="+p.y+" height="+previous.height+" viewport="+scroll.height)
   form.close();AppConfig.fontScale=1.3;CalendarBackend.calendars=["Test"]
  }
  function test_calendar_add_event_keyboard_data() {
   const rows=[]
   for(const pack of ["minimal","md3"])for(const key of [Qt.Key_Return,Qt.Key_Enter,Qt.Key_Space])rows.push({tag:pack+"-"+key,pack:pack,key:key})
   return rows
  }
  function test_calendar_add_event_keyboard(data) {
   controls.visible=false;dashboard.visible=false;AppConfig.designSystem=data.pack
   CalendarBackend.calendars=[{name:"Test"}]
   const cal=createTemporaryObject(testCalendar,scene)
   wait(20)
   const add=byProperty(cal,"text","Add Event")
   verify(add!==null && add.enabled)
   add.forceActiveFocus();verify(add.activeFocus)
   keyClick(data.key);wait(10)
   verify(cal.modalOpen,"focused Add Event opens editor")
   cal.closeTopModal();wait(20)
   verify(!cal.modalOpen);verify(add.activeFocus,"editor restores button focus")
  }
  function test_material_button_enter_once() {
   controls.visible=false;dashboard.visible=false
   const button=createTemporaryObject(testButtonFixture,scene)
   const spy=createTemporaryObject(dockSignalSpy,scene,{target:button,signalName:"clicked"})
   button.forceActiveFocus()
   keyClick(Qt.Key_Return);compare(spy.count,1);verify(button.checked)
   keyClick(Qt.Key_Enter);compare(spy.count,2);verify(!button.checked)
   keyClick(Qt.Key_Space);compare(spy.count,3);verify(button.checked)
   button.enabled=false
   keyClick(Qt.Key_Return);compare(spy.count,3)
  }
  function test_calendar_focus_and_events() {
   controls.visible=false;scene.width=900;scene.height=600
   CalendarBackend.dayEvents=[{uid:"one",title:"All day",allDay:true},{uid:"two",title:"Late meeting",start:new Date(2026,9,25,22),end:new Date(2026,9,25,23),allDay:false}]
   const cal=createTemporaryObject(testCalendar,scene,{selectedDate:DateTime.clock.date})
   verify(cal!==null);wait(40)
   const selected=byProperty(cal,"isFocused",true)
   verify(selected!==null)
   selected.forceActiveFocus();const before=cal.focusedCellIndex
   keyClick(Qt.Key_Left);compare(cal.focusedCellIndex,before-1)
   const moved=byProperty(cal,"isFocused",true)
   verify(moved.activeFocus,"arrows move actual focus")
   keyClick(Qt.Key_Return)
   compare(cal.selectedDate.getDate(),moved.model.date.getDate())
   keyClick(Qt.Key_Tab)
   verify(!moved.activeFocus,"grid is one Tab stop")
   const event=eventByTitle(cal,"Late meeting")
   verify(event!==null,"event card found")
   event.forceActiveFocus();wait(20)
   grabImage(scene).save("RENDERS/calendar.png")
   const flick=event.parent.parent.parent
   verify(flick.contentY>0,"focused event is revealed")
   keyClick(Qt.Key_Return);wait(30);verify(cal.modalOpen,"event dialog open")
   cal.closeTopModal();wait(30);verify(!cal.modalOpen,"event dialog closed");verify(event.activeFocus,"event focus restored")
  }
  function test_calendar_responsive_data() {return [{tag:"minimal",pack:"minimal"},{tag:"md3",pack:"md3"}]}
  function test_calendar_responsive(data) {
   controls.visible=false;AppConfig.designSystem=data.pack
   for(const width of [320,480,900]) for(const scale of [1,1.3,2]) {
    AppConfig.fontScale=scale;scene.width=width;scene.height=600
    const cal=createTemporaryObject(testCalendar,scene,{width:width,selectedDate:DateTime.clock.date})
    verify(cal!==null);wait(30)
    const selected=byProperty(cal,"isFocused",true)
    verify(selected!==null)
    verify(selected.parent.width<=width,"month grid fits")
    for(const cell of selected.parent.children) if(cell.model?.day!==undefined) {
     verify(cell.x>=0 && cell.x+cell.width<=selected.parent.width+1,"day cell fits grid")
     const number=byProperty(cell,"text",String(cell.model.day))
     verify(number===null || number.implicitWidth<=cell.width+1,"date remains readable: width="+width+" scale="+scale+" cell="+cell.width+" text="+number?.implicitWidth)
    }
    const empty=byProperty(cal,"headline","No events")
    verify(empty!==null && empty.visible,"empty day has a simple summary")
    const add=byProperty(cal,"text","Add Event")
    const monthPos=selected.parent.mapToItem(cal,0,0)
    const dayPos=empty.mapToItem(cal,0,0)
    if(cal.stacked) verify(dayPos.y>monthPos.y+selected.parent.height,"day view follows month")
    else verify(dayPos.x>monthPos.x,"day view is beside month")
    add.forceActiveFocus();wait(20)
    const addPos=add.mapToItem(cal,0,0)
    verify(addPos.y>=0 && addPos.y+add.height<=cal.height+1,"keyboard focus reveals day actions")
    cal.goToNextMonth();verify(!cal.todayIsSelected)
    const today=byProperty(cal,"text","Today")
    today.forceActiveFocus();keyClick(Qt.Key_Space);wait(20)
    verify(cal.todayIsSelected,"Today returns to the current date")
    if(width===480 && scale===1.3) grabImage(scene).save("RENDERS/calendar-"+data.pack+".png")
    cal.destroy()
   }
  }
  function test_weather_availability_and_details() {
   controls.visible=false;dashboard.visible=true;GlobalStates.dashboardOpenIndex=1;wait(40)
   const tab=byProperty(dashboard,"detailsExpanded",false)
   verify(tab!==null)
   compare(byProperty(tab,"label","Pressure"),null,"details stay unloaded")
   const details=byProperty(tab,"headline","Weather details")
   details.forceActiveFocus();keyClick(Qt.Key_Return);wait(30)
   verify(tab.detailsExpanded);verify(byProperty(tab,"label","Pressure")!==null)
   keyClick(Qt.Key_Return);wait(30);verify(!tab.detailsExpanded)
   Weather.data=null;Weather.errorString="Network unavailable";wait(30)
   compare(tab.hasConditions,false)
   verify(byProperty(tab,"headline","Weather unavailable").visible)
   verify(!details.visible,"unavailable values cannot be expanded")
   AppConfig.weatherEnabled=false;wait(20)
   verify(byProperty(tab,"headline","Weather disabled").visible)
   AppConfig.weatherEnabled=true
   Weather.data=({current:{temperature_2m:8}});Weather.isFresh=false;wait(30)
   verify(byProperty(tab,"headline","Showing last available weather").visible)
   verify(tab.hasConditions,"last successful values remain usable")
  }
  function test_device_picker_keyboard() {
   controls.visible=false
   AudioService.sinkNodes=[{id:1,name:"Speakers"},{id:2,name:"Headphones"}]
   const picker=createTemporaryObject(devicePicker,scene)
   verify(picker!==null)
   picker.openDialog("Output","output");wait(30)
   const row=byProperty(picker,"headline","Speakers")
   verify(row!==null);verify(row.activeFocus,"row is first focus stop")
   keyClick(Qt.Key_Tab)
   const second=byProperty(picker,"headline","Headphones")
   verify(second.activeFocus,"radio must not duplicate row's Tab stop")
   keyClick(Qt.Key_Up);verify(row.activeFocus)
   keyClick(Qt.Key_End);verify(second.activeFocus)
   keyClick(Qt.Key_Return);wait(30);verify(!picker.visible)
  }
  function test_list_row_density() {
   const row=createTemporaryObject(basicRow,scene)
   verify(row!==null)
   for(const pack of ["minimal","md3"]) {
    AppConfig.designSystem=pack
    for(const scale of [1,1.3,2]) {
     AppConfig.fontScale=scale;wait(20)
     verify(row.implicitHeight>=Tokens.typography.bodyLarge.size+Tokens.typography.bodyMedium.size+Tokens.spacing.small*2)
    }
   }
  }
  function test_tile_keyboard() {
   tile.forceActiveFocus();keyClick(Qt.Key_Space);compare(scene.tileClicks,1)
   keyClick(Qt.Key_Return);compare(scene.tileClicks,2)
   tile.enabled=false;keyClick(Qt.Key_Space);compare(scene.tileClicks,2);tile.enabled=true
  }
  function test_editor_key_forwarding() {
   field.inputItem.forceActiveFocus()
   keyClick(Qt.Key_Return);compare(scene.acceptedEdits,1)
   keyClick(Qt.Key_Down);compare(scene.downPresses,1)
  }
  function test_field_focus_chain() {
   field.inputItem.forceActiveFocus();keyClick(Qt.Key_Tab);verify(combo.activeFocus)
   keyClick(Qt.Key_Tab,Qt.ShiftModifier);verify(field.inputItem.activeFocus)
   keyClick(Qt.Key_Tab,Qt.ShiftModifier);verify(action.activeFocus)
  }
  function test_external_tab_selection() {
   action.forceActiveFocus();keyClick(Qt.Key_Tab,Qt.ShiftModifier);keyClick(Qt.Key_Tab,Qt.ShiftModifier)
   scene.selected=3;wait(20);verify(tabs.activeFocus)
   keyClick(Qt.Key_Tab);verify(tile.activeFocus)
  }
  function test_dashboard_media_initial_and_hidden_geometry() {
   const previousMotion=AppConfig.reduceMotion
   AppConfig.reduceMotion=false
   const previousOpen=GlobalStates.dashboardOpen
   GlobalStates.dashboardOpen=true
   const row=createTemporaryObject(mediaRowFixture,scene,{expanded:true})
   verify(row!==null);compare(row.morph,1,"initial expanded content starts at its final geometry")
   GlobalStates.dashboardOpen=false
   row.expanded=false;compare(row.morph,0,"hidden expansion does not keep moving")
   row.expanded=true;compare(row.morph,1)
   GlobalStates.dashboardOpen=previousOpen
   AppConfig.reduceMotion=previousMotion
  }
  function test_dashboard_media_collapse_keeps_content_extent() {
   controls.visible=false;AppConfig.reduceMotion=false;GlobalStates.dashboardOpen=true
   const row=createTemporaryObject(mediaRowFixture,scene,{expanded:true})
   const openHeight=row.implicitHeight
   verify(openHeight>row.rowHeight)
   row.expanded=false
   compare(row.implicitHeight,openHeight,"collapsing cannot clip the player before its controls move")
   wait(60)
   verify(row.implicitHeight>row.rowHeight && row.implicitHeight<openHeight)
   const partial=row.implicitHeight
   row.expanded=true
   compare(row.implicitHeight,partial,"reversal starts at the current player size")
   tryCompare(row,"morph",1)
   row.expanded=false
   tryCompare(row,"morph",0)
   compare(row.implicitHeight,row.rowHeight)
   row.expanded=true;wait(50);GlobalStates.dashboardOpen=false
   compare(row.morph,1,"closing the dashboard settles retained motion")
   AppConfig.reduceMotion=true
  }
  function test_dashboard_source_list_collapse_keeps_extent() {
   controls.visible=false;AppConfig.reduceMotion=false;GlobalStates.dashboardOpen=true
   MprisController.availablePlayers=[{identity:"One",trackTitle:"First"},{identity:"Two",trackTitle:"Second"}]
   const row=createTemporaryObject(mediaRowFixture,scene,{expanded:true})
   const base=row.implicitHeight
   row.sourceListOpen=true;tryCompare(row,"sourceMorph",1)
   const open=row.implicitHeight;verify(open>base)
   row.sourceListOpen=false
   compare(row.implicitHeight,open)
   wait(60);verify(row.implicitHeight>base && row.implicitHeight<open)
   tryCompare(row,"sourceMorph",0);compare(row.implicitHeight,base)
   AppConfig.reduceMotion=true
  }
  function test_collapsible_content_lifetime() {
   controls.visible=false;AppConfig.reduceMotion=false
   const view=createTemporaryObject(collapsibleFixture,scene)
   compare(view.item,null);compare(view.implicitHeight,0)
   view.expanded=true
   tryCompare(view,"progress",1)
   const body=view.item
   verify(body!==null);compare(view.implicitHeight,160)
   view.expanded=false
   compare(view.item,body,"closing retains the painted body")
   wait(60)
   verify(view.implicitHeight>0 && view.implicitHeight<160)
   verify(view.item!==null && !view.item.enabled)
   const partial=view.implicitHeight
   view.expanded=true
   compare(view.implicitHeight,partial,"reversal starts at the current section size")
   compare(view.item,body,"reversing reuses the same body")
   tryCompare(view,"progress",1)
   view.expanded=false
   tryCompare(view,"progress",0)
   compare(view.item,null);compare(view.implicitHeight,0)
   AppConfig.reduceMotion=true
   view.expanded=true;compare(view.progress,1)
   view.expanded=false;compare(view.progress,0);compare(view.item,null)
  }
  function test_dashboard_measurement_handover() {
   controls.visible=false;dashboard.visible=true;GlobalStates.dashboardOpenIndex=0;wait(40)
   verify(dashboard.tabContentHeight>0)
   const previous=dashboard.tabContentHeight
   // Hold one real tab unready to exercise measurement handover explicitly.
   const loader=dashboard._tabLoaders[2]
   const source=loader.sourceComponent
   try {
    loader.sourceComponent=null
    GlobalStates.dashboardOpenIndex=2;wait(20)
    compare(dashboard._rawTabContentHeight,0)
    compare(dashboard.tabContentHeight,previous)
   } finally {loader.sourceComponent=source}
   wait(20);verify(dashboard._rawTabContentHeight>0)
   GlobalStates.dashboardOpenIndex=1;wait(30)
   verify(dashboard.tabContentHeight>0)
   compare(dashboard.tabContentHeight,dashboard._rawTabContentHeight)
  }
  function test_dashboard_keyboard_data() {return [{tag:"minimal",pack:"minimal"},{tag:"md3",pack:"md3"}]}
  function test_dashboard_keyboard(data) {
   AppConfig.designSystem=data.pack;GlobalStates.dashboardOpen=true;GlobalStates.dashboardOpenIndex=0
   dashboard.visible=true;controls.visible=false;wait(30)
   const strip=findChild(dashboard,"dashboardTabs")
   strip.forceActiveFocus();wait(10)
   keyClick(Qt.Key_Right);compare(GlobalStates.dashboardOpenIndex,1)
   keyClick(Qt.Key_Right);compare(GlobalStates.dashboardOpenIndex,2);wait(30)
   const cal=findChild(dashboard,"dashboardCalendar")
   verify(cal!==null)
   const before=cal.focusedCellIndex
   keyClick(Qt.Key_Up);compare(cal.focusedCellIndex,before)
   keyClick(Qt.Key_Down);compare(cal.focusedCellIndex,before)
   verify(strip.activeFocus,"tab selection keeps focus in strip")
   // The grid owns all four arrows and physical vi keys once focus enters it.
   cal.focusedCellIndex=15
   const cell=byProperty(cal,"isFocused",true);verify(cell!==null);cell.forceActiveFocus()
   keyClick(Qt.Key_Left);compare(cal.focusedCellIndex,14);compare(GlobalStates.dashboardOpenIndex,2)
   keyClick(Qt.Key_Right);compare(cal.focusedCellIndex,15)
   keyClick(Qt.Key_Up);compare(cal.focusedCellIndex,8)
   keyClick(Qt.Key_Down);compare(cal.focusedCellIndex,15)
   keyClick(Qt.Key_H);compare(cal.focusedCellIndex,14)
   keyClick(Qt.Key_Tab,Qt.ControlModifier);compare(GlobalStates.dashboardOpenIndex,0);wait(20)
   keyClick(Qt.Key_Backtab,Qt.ControlModifier|Qt.ShiftModifier);compare(GlobalStates.dashboardOpenIndex,2);wait(20)
   // A different focused control still has access to window-level tab cycling.
   const button=byProperty(findChild(dashboard,"dashboardCalendar"),"iconName","chevron_left")
   verify(button!==null);button.forceActiveFocus()
   keyClick(Qt.Key_Tab,Qt.ControlModifier);compare(GlobalStates.dashboardOpenIndex,0);wait(20)
   const slider=createTemporaryObject(dashboardSliderFixture,dashboard,{x:20,y:120})
   slider.forceActiveFocus()
   keyClick(Qt.Key_Backtab,Qt.ControlModifier|Qt.ShiftModifier);compare(GlobalStates.dashboardOpenIndex,2);wait(20)
   keyClick(Qt.Key_Tab,Qt.ControlModifier);compare(GlobalStates.dashboardOpenIndex,0);wait(20)
   const field=createTemporaryObject(dashboardFieldFixture,dashboard,{x:20,y:160})
   field.inputItem.forceActiveFocus()
   const toggles=MprisController.toggles
   keyClick(Qt.Key_H);keyClick(Qt.Key_1);keyClick(Qt.Key_Space)
   compare(GlobalStates.dashboardOpenIndex,0);compare(MprisController.toggles,toggles)
   keyClick(Qt.Key_Backtab,Qt.ControlModifier|Qt.ShiftModifier);compare(GlobalStates.dashboardOpenIndex,2);wait(20)
   const modalCal=findChild(dashboard,"dashboardCalendar")
   modalCal.openNewEvent();wait(20);verify(modalCal.modalOpen)
   keyClick(Qt.Key_Tab,Qt.ControlModifier);compare(GlobalStates.dashboardOpenIndex,2)
   modalCal.closeTopModal();wait(20)
   controls.visible=true;dashboard.visible=false;GlobalStates.dashboardOpenIndex=0
  }
  function lastFocusable(item) {
   let found=item.activeFocusOnTab && item.enabled && item.visible ? item : null
   for(const child of item.children ?? []) {
    const next=lastFocusable(child)
    if(next) found=next
   }
   return found
  }
  function eventByTitle(item,title) {
   if(item.ev?.title===title) return item
   for(const child of item.children ?? []) {
    const found=eventByTitle(child,title)
    if(found) return found
   }
   return null
  }
  function byProperty(item,key,value) {
   if(item[key]===value) return item
   for(const child of item.children ?? []) {
    const found=byProperty(child,key,value)
    if(found) return found
   }
   return null
  }
  function test_weather_layout_data() {
   const cases=[]
   for(const pack of ["minimal","md3"]) for(const width of [320,480,900]) for(const scale of [1.3,2])
    cases.push({tag:pack+"-"+width+"-"+scale,pack:pack,width:width,height:650,scale:scale})
   return cases
  }
  function test_weather_layout(data) {
   AppConfig.designSystem=data.pack;AppConfig.fontScale=data.scale
   scene.width=data.width;scene.height=data.height
   controls.visible=false;dashboard.visible=true;GlobalStates.dashboardOpenIndex=1;wait(60)
   verify(dashboard.tabContentHeight>0)
   const first=byProperty(dashboard,"date","2026-10-25")
   const last=byProperty(dashboard,"date","2026-10-31")
   verify(first!==null && last!==null)
   verify(first.x+first.width<=first.parent.width)
   verify(last.x+last.width<=last.parent.width)
   verify(first.implicitHeight<=first.height+1,"forecast content fits")
   const tab=byProperty(dashboard,"detailsExpanded",false)
   compare(first.y,last.y,"all days stay on one row")
   compare(first.height,last.height,"cards share one height")
   const viewport=byProperty(tab,"flickableDirection",Flickable.HorizontalFlick)
   verify(viewport!==null)
   verify(viewport.width<=tab.width+1,"forecast viewport fits tab")
   verify(first.width>=first.implicitWidth-1,"card keeps its readable width")
   if(data.width===900) verify(!tab.forecastOverflow,"all seven days fit a normal panel")
   if(tab.forecastOverflow) {
    const next=byProperty(tab,"iconName","chevron_right")
    verify(next!==null && next.visible && next.enabled)
    next.forceActiveFocus();keyClick(Qt.Key_Return);wait(30)
    verify(viewport.contentX>0,"keyboard scrolls to later days")
    for(let i=0;i<7;i++) tab.scrollForecast(1)
    wait(30)
    verify(last.x+last.width<=viewport.contentX+viewport.width+1,"last day can be revealed")
    for(let i=0;i<7;i++) tab.scrollForecast(-1)
    compare(viewport.contentX,0)
   }
   const range=byProperty(first,"text","8°")
   verify(range!==null && range.parent.implicitWidth<=first.width+1,"forecast text fits its card")

   const toggle=byProperty(dashboard,"headline","Weather details")
   toggle.forceActiveFocus();keyClick(Qt.Key_Space);wait(30)
   const pressure=byProperty(dashboard,"label","Pressure")
   verify(pressure!==null && pressure.width<=data.width,"expanded details fit: actual="+pressure?.width+" viewport="+data.width)
   toggle.forceActiveFocus();keyClick(Qt.Key_Space);wait(20)
   grabImage(scene).save("RENDERS/weather-"+data.tag+".png")
   controls.visible=true;dashboard.visible=false
  }
  function test_dashboard_layout_data() {
   return [{tag:"compact",width:480,height:420},{tag:"wide",width:900,height:600}]
  }
  function test_dashboard_layout(data) {
   scene.width=data.width;scene.height=data.height
   controls.visible=false;dashboard.visible=true;wait(80)
   const strip=byProperty(dashboard,"accessibleName","Dashboard sections")
   verify(strip!==null)
   verify(strip.width>0 && strip.height>0)
   verify(strip.x>=0 && strip.y>=0 && strip.x+strip.width<=dashboard.width)
   verify(dashboard.tabContentHeight>0)
   verify(dashboard.headerHeight<scene.height)
   grabImage(scene).save("RENDERS/dashboard-"+data.tag+".png")
   if(data.tag==="compact") {
    const quick=byProperty(dashboard,"contentPadding",Tokens.panelPadding)
    verify(quick!==null)
    const scroll=quick.children.find(item=>item.contentItem?.contentY!==undefined)
    verify(scroll!==undefined)
    verify(scroll.contentItem.contentHeight>scroll.contentItem.height)
    const last=lastFocusable(quick)
    verify(last!==null);last.forceActiveFocus(Qt.TabFocusReason);wait(20)
    verify(scroll.contentItem.contentY>0)
    grabImage(scene).save("RENDERS/dashboard-compact-bottom.png")
   }
   controls.visible=true;dashboard.visible=false
  }
  function test_tab_roving_focus() {
   action.forceActiveFocus();keyClick(Qt.Key_Tab,Qt.ShiftModifier);verify(tile.activeFocus)
   keyClick(Qt.Key_Tab,Qt.ShiftModifier);verify(tabs.activeFocus)
   keyClick(Qt.Key_Right);compare(scene.selected,1)
   keyClick(Qt.Key_End);compare(scene.selected,4)
   keyClick(Qt.Key_Right);compare(scene.selected,0)
   keyClick(Qt.Key_Tab);verify(tile.activeFocus,"after tabs: "+scene.Window.window.activeFocusItem)
  }
  function test_combo_controlled_selection_and_literal_text() {
   controls.visible=false;dashboard.visible=false
   const host=createTemporaryObject(controlledComboFixture,scene)
   const combo=host.control
   combo.forceActiveFocus();keyClick(Qt.Key_Down);compare(host.selection,1)
   host.selection=0;compare(combo.currentIndex,0)
   combo.open=true;wait(10)
   const popup=Array.from(combo.data).find(item=>item.closePolicy===(Popup.CloseOnEscape | Popup.CloseOnPressOutside))
   verify(popup!==undefined)
   const second=byProperty(popup.contentItem,"text","Two")
   verify(second!==null);mouseClick(second,second.width/2,second.height/2)
   compare(host.selection,1)
   host.selection=2;compare(combo.currentIndex,2)
   combo.model=["<b>Literal choice</b>"];host.selection=0
   const label=byProperty(combo,"text","<b>Literal choice</b>")
   verify(label!==null);compare(label.textFormat,Text.PlainText)
   combo.open=true;wait(10);combo.enabled=false;verify(!combo.open)
   combo.enabled=true;combo.open=true;wait(10)
   combo.model=[];verify(!combo.open)
   combo.forceActiveFocus();keyClick(Qt.Key_Return);verify(!combo.open)
   const before=host.selection
   keyClick(Qt.Key_Down);keyClick(Qt.Key_End);compare(host.selection,before)
  }
  function test_combo_keyboard() {
   combo.forceActiveFocus();keyClick(Qt.Key_Down);compare(combo.currentIndex,1)
   keyClick(Qt.Key_End);compare(combo.currentIndex,2)
   keyClick(Qt.Key_Space);verify(combo.open)
   keyClick(Qt.Key_Escape);verify(!combo.open)
   keyClick(Qt.Key_Tab);verify(after.activeFocus)
  }
  function test_nested_dialog_focus() {
   action.forceActiveFocus();dialog.open();wait(20)
   modalLast.forceActiveFocus();innerDialog.open();wait(20);verify(innerFirst.activeFocus)
   keyClick(Qt.Key_Tab,Qt.ShiftModifier);verify(innerLast.activeFocus)
   keyClick(Qt.Key_Tab);verify(innerFirst.activeFocus)
   keyClick(Qt.Key_Escape);wait(20);verify(!innerDialog.visible);verify(dialog.visible);verify(modalLast.activeFocus)
   keyClick(Qt.Key_Escape);wait(20);verify(!dialog.visible);verify(action.activeFocus)
  }
  function test_dialog_focus_boundary() {
   action.forceActiveFocus();dialog.open();wait(20);verify(modalField.inputItem.activeFocus)
   keyClick(Qt.Key_Tab,Qt.ShiftModifier);verify(modalLast.activeFocus,"dialog backwards: "+scene.Window.window.activeFocusItem)
   keyClick(Qt.Key_Tab);verify(modalField.inputItem.activeFocus)
   keyClick(Qt.Key_Escape);wait(20);verify(!dialog.visible,"closed");verify(action.activeFocus,"restored: "+scene.Window.window.activeFocusItem)
  }
  function test_snackbar_layout_and_keyboard_data() {return [{tag:"minimal",pack:"minimal"},{tag:"md3",pack:"md3"}]}
  function test_snackbar_layout_and_keyboard(data) {
   controls.visible=false;AppConfig.designSystem=data.pack
   for(const width of [240,360,600]) for(const scale of [1,1.3,2]) {
    AppConfig.fontScale=scale
    const notice=createTemporaryObject(snackbarFixture,scene,{width:width})
    verify(notice!==null);wait(30)
    const label=byProperty(notice,"text","Undo")
    verify(label!==null)
    const action=label.parent
    action.forceActiveFocus();keyClick(Qt.Key_Return);compare(notice.activations,1)
    keyClick(Qt.Key_Space);compare(notice.activations,2)
    const position=action.mapToItem(notice,0,0)
    verify(position.x>=0 && position.x+action.width<=notice.width+1,"undo action fits")
    verify(position.y>=0 && position.y+action.height<=notice.height+1,"undo action fits height")
    if(width===360 && scale===1.3) grabImage(notice).save("RENDERS/snackbar-"+data.pack+".png")
    notice.destroy()
   }
  }
  function test_temporary_actions_and_quick_status() {
   controls.visible=false;GlobalStates.launcherOpen=true
   AppConfig.temporaryModeDurations=[7,45]
   NotificationDND.enabled=true;NotificationDND.temporary=true;NotificationDND.statusText="Until Mon 00:45"
   LauncherService.search(": dnd 45")
   compare(LauncherService.filteredApps.length,1)
   compare(LauncherService.filteredApps[0].resultId,"action:dnd-45m","explicit duration cannot hit the permanent toggle")
   LauncherService.launch(LauncherService.filteredApps[0]);compare(NotificationDND.lastDuration,45)
   LauncherService.search(": caffeine 37")
   compare(LauncherService.filteredApps.length,1,"explicit duration need not be a preset")
   LauncherService.launch(LauncherService.filteredApps[0]);compare(IdleInhibitorService.lastDuration,37)
   for(const query of [": dnd 0",": dnd 1441"]) {LauncherService.search(query);compare(LauncherService.filteredApps.length,0)}
   LauncherService.search(": dnd")
   verify(LauncherService.filteredApps.some(row=>row.resultId==="action:dnd-7m"))
   verify(!LauncherService.filteredApps.some(row=>row.resultId==="action:dnd-15m"),"configured presets replace defaults")
   AppConfig.disabledModules=["notifications"];LauncherService.search(": dnd 30");compare(LauncherService.filteredApps.length,0)
   AppConfig.disabledModules=[];GlobalStates.launcherOpen=false
   IdleInhibitorService.statusText="Until Mon 17:30";NotificationDND.statusText="Until Mon 18:00"
   dashboard.visible=true;GlobalStates.dashboardOpenIndex=0;wait(40)
   const caffeine=byProperty(dashboard,"label","Caffeine")
   const dnd=byProperty(dashboard,"label","Do not disturb")
   compare(caffeine.supportingText,IdleInhibitorService.statusText)
   compare(dnd.supportingText,NotificationDND.statusText)
  }
  function test_launcher_tab_selection_data() {
   return [{tag:"minimal-empty",pack:"minimal",query:""},{tag:"minimal-query",pack:"minimal",query:"edit"},
    {tag:"md3-empty",pack:"md3",query:""},{tag:"md3-query",pack:"md3",query:"edit"}]
  }
  function test_launcher_tab_selection(data) {
   controls.visible=false;GlobalStates.launcherOpen=true;AppConfig.designSystem=data.pack
   const launcher=createTemporaryObject(launcherFixture,scene)
   verify(launcher!==null);wait(30)
   const input=byProperty(launcher,"placeholderText","Search applications")
   const list=byProperty(launcher,"reuseItems",true)
   input.text=data.query;wait(150)
   verify(list.count>2);list.currentIndex=1;input.inputItem.forceActiveFocus()
   keyClick(Qt.Key_Tab);compare(list.currentIndex,2,"Tab selects the next result")
   verify(input.inputItem.activeFocus,"Tab keeps typing focus in the editor")
   keyClick(Qt.Key_Tab,Qt.ShiftModifier);compare(list.currentIndex,1,"Shift+Tab selects the previous result")
   verify(input.inputItem.activeFocus,"Shift+Tab keeps typing focus in the editor")
   keyClick(Qt.Key_Backtab);compare(list.currentIndex,0)
   input.text="changed";keyClick(Qt.Key_Tab)
   compare(LauncherService.searchQuery,"changed","Tab flushes the pending query")
   compare(list.currentIndex,1);verify(input.inputItem.activeFocus)
   input.text="none";wait(150);compare(list.count,0)
   keyClick(Qt.Key_Tab);verify(input.inputItem.activeFocus,"empty results do not focus the clear button")
   keyClick(Qt.Key_Tab,Qt.ShiftModifier);verify(input.inputItem.activeFocus)
   const clear=byProperty(input,"iconName","close")
   verify(clear!==null);mouseClick(clear,clear.width/2,clear.height/2)
   compare(input.text,"");verify(input.inputItem.activeFocus,"clicking clear returns to typing")
  }
  function test_launcher_flush_and_reopen() {
   controls.visible=false;GlobalStates.launcherOpen=true
   const launcher=createTemporaryObject(launcherFixture,scene)
   verify(launcher!==null);wait(30)
   const input=byProperty(launcher,"placeholderText","Search applications")
   compare(LauncherService.filteredApps[0].resultId,"app:Editor:0","provider ranking survives equal scores")
   input.text="changed";input.inputItem.forceActiveFocus();keyClick(Qt.Key_Return)
   compare(LauncherService.filteredApps[0].resultId,"app:changed:0")
   compare(GlobalStates.lastAction,"app:changed:0","Enter uses the new model even before delegates settle")
   compare(GlobalStates.launcherOpen,false)
   GlobalStates.launcherOpen=true;GlobalStates.panelOpened("launcher");wait(30)
   compare(input.text,"");compare(LauncherService.searchQuery,"")
   verify(input.inputItem.activeFocus,"reopen focuses the editor")
   input.text=": audio";keyClick(Qt.Key_Return);wait(20)
   compare(GlobalStates.lastAction,"audio","action opens its destination after closing launcher")
  }
  function test_launcher_action_survives_unload() {
   controls.visible=false;GlobalStates.launcherOpen=true
   const loader=createTemporaryObject(launcherLoaderFixture,scene)
   verify(loader!==null);tryVerify(()=>loader.item!==null)
   const input=byProperty(loader.item,"placeholderText","Search applications")
   input.text=": audio";input.inputItem.forceActiveFocus();keyClick(Qt.Key_Return)
   compare(loader.item,null,"non-retained launcher unloads")
   compare(GlobalStates.lastAction,"audio","service completes the action after UI destruction")
  }
  function test_launcher_modes_and_calculator() {
   controls.visible=false;GlobalStates.launcherOpen=true
   const launcher=createTemporaryObject(launcherFixture,scene)
   verify(launcher!==null);wait(30)
   const input=byProperty(launcher,"placeholderText","Search applications")
   input.text="= 1+1";wait(300)
   verify(LauncherService.busy);compare(LauncherService.filteredApps.length,0)
   QalculateWrapper.evaluated("1+1","2");wait(30)
   compare(LauncherService.filteredApps[0].text,"2")
   input.text="= 2+2";wait(150)
   compare(LauncherService.filteredApps.length,0,"old result is never offered for a new expression")
   input.inputItem.forceActiveFocus();keyClick(Qt.Key_Return)
   verify(GlobalStates.launcherOpen,"pending evaluation cannot close the launcher")
   QalculateWrapper.evaluated("2+2","error: invalid");wait(30)
   compare(LauncherService.filteredApps[0].action,null)
   keyClick(Qt.Key_Return);verify(GlobalStates.launcherOpen,"error is not an action")
   input.text=">";wait(150);compare(launcher.mode,"clipboard")
   verify(byProperty(launcher,"headline","No clipboard entries").visible)
   input.text="none";wait(150)
   verify(byProperty(launcher,"headline","No applications found").visible)
   AppConfig.disabledModules=["audio"];LauncherService.search(": audio")
   compare(LauncherService.filteredApps.length,0,"disabled destinations are excluded")
  }
  function test_launcher_and_osd_layout_data() {return [{tag:"minimal",pack:"minimal"},{tag:"md3",pack:"md3"}]}
  function test_launcher_and_osd_layout(data) {
   controls.visible=false;GlobalStates.launcherOpen=true;AppConfig.designSystem=data.pack
   for(const width of [240,320,600]) for(const scale of [1,1.3,2]) {
    scene.width=width;scene.height=600;AppConfig.fontScale=scale
    const launcher=createTemporaryObject(launcherFixture,scene,{width:width})
    const meter=createTemporaryObject(meterFixture,scene,{width:width})
    verify(launcher!==null && meter!==null);wait(30)
    const input=byProperty(launcher,"placeholderText","Search applications")
    verify(input.width<=width && input.height>0)
    const percent=byProperty(meter,"text","75%")
    verify(percent!==null)
    const point=percent.mapToItem(meter,0,0)
    verify(point.x>=0 && point.x+percent.width<=width+1,"OSD value fits")
    verify(meter.implicitHeight>=percent.height,"OSD scales with its text")
    input.text="none";wait(150)
    const empty=byProperty(launcher,"headline","No applications found")
    verify(empty!==null && empty.width<=width)
    if(width===600 && scale===1.3) {meter.visible=false;grabImage(launcher).save("RENDERS/launcher-"+data.pack+".png");meter.visible=true;grabImage(meter).save("RENDERS/osd-"+data.pack+".png")}
    launcher.destroy();meter.destroy()
   }
  }
  function test_launcher_row_height() {
   const short=createTemporaryObject(resultDelegate,scene,{modelData:{text:"Editor",description:"",icon:""}})
   const long=createTemporaryObject(resultDelegate,scene,{modelData:{text:"Long application name",description:"Description that may be elided",icon:""}})
   verify(short!==null && long!==null)
   for(const pack of ["minimal","md3"]) {
    AppConfig.designSystem=pack
    for(const scale of [1,1.3,2]) {
     AppConfig.fontScale=scale;wait(20)
     compare(short.implicitHeight,long.implicitHeight)
     verify(short.implicitHeight>=Tokens.typography.titleMedium.size+Tokens.typography.bodySmall.size)
    }
   }
  }
  function test_density_data() {
   return [{tag:"minimal",pack:"minimal"},{tag:"md3",pack:"md3"}]
  }
  function test_density(data) {
   AppConfig.designSystem=data.pack
   for(const scale of [1,1.3,2]) {
    AppConfig.fontScale=scale;wait(30)
    verify(action.implicitHeight>=action.contentItem.implicitHeight, "button")
    verify(field.implicitHeight>=field.inputItem.implicitHeight, "field")
    verify(tile.implicitHeight>=tile.contentItem.implicitHeight, "tile")
   }
   AppConfig.fontScale=1.3;wait(50)
   grabImage(scene).save("RENDERS/"+data.pack+".png")
  }
 }
}
'''.replace('RENDERS', str(RENDERS)))
    native = tree / 'shell.qml'
    (tree / 'NativeAudio.qml').write_text((ROOT / 'src/features/audio/AudioContent.qml').read_text().replace('import QtQuick\n','import QtQuick\nimport qs.src.features.audio\n',1))
    (tree / 'NativeIpcData.qml').write_text((ROOT / 'src/features/cheatsheet/components/IpcReferenceData.qml').read_text().replace('pragma Singleton\n',''))
    (tree / 'NativeTrayOverflow.qml').write_text((ROOT / 'src/features/popouts/TrayOverflow.qml').read_text())
    native.write_text('''import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import qs.src.features.statusbar
import qs.src.core.config
import qs.src.core.services
import qs.src.features.connections
import qs.src.features.audio

Window {
 id: root
 visible:true;width:500;height:600
 ConnectionsContent {id:panel;anchors.fill:parent}
 TrayModel {id:nativeTray}
 ScriptModel {values:Array.from(nativeTray.visibleItems)}
 NativeTrayOverflow {trayModel:nativeTray;visible:false}
 NativeIpcData {id:reference}
 IpcHandler {target:"fixture";function echo(value:int):string {return String(value)}}
 NativeAudio {id:audio;anchors.fill:parent;visible:false}
 property Item savedRow:null
 property int step:0
 function row(item,title) {
  if(item.headline===title) return item
  for(const child of item.children ?? []) {
   const result=row(child,title)
   if(result) return result
  }
  return null
 }
 function check(ok,message) {if(!ok) {console.warn("NATIVE FAIL: "+message);Qt.exit(1);throw new Error(message)}}
 Component.onCompleted: {
  GlobalStates.connectionsSection="bluetooth";panel.reset()
  BluetoothService.pairedDevices=[{name:"Headphones",address:"A",device:null,connected:false,battery:-1}]
 }
 Timer {
  interval:60;repeat:true;running:true
  onTriggered: {
   if(root.step===0) {
    root.savedRow=root.row(panel,"Headphones")
    root.check(root.savedRow!==null,"initial row")
    root.savedRow.forceActiveFocus()
    BluetoothService.pairedDevices=[{name:"Renamed",address:"A",device:null,connected:true,battery:0.8}]
   } else if(root.step===1) {
    const updated=root.row(panel,"Renamed")
    root.check(updated===root.savedRow,"keyed row identity")
    root.check(updated.activeFocus,"focus survives snapshot update")
    root.check(updated.supportingText==="Connected","fresh snapshot data")
    BluetoothService.pairedDevices=[{name:"Other",address:"B",device:null,connected:false,battery:-1},{name:"Renamed",address:"A",device:null,connected:true,battery:0.8}]
   } else if(root.step===2) {
    root.check(root.row(panel,"Renamed")===root.savedRow,"identity survives insertion")
    root.check(root.savedRow.activeFocus,"focus survives insertion")
    panel.visible=false;audio.visible=true;AppConfig.fontScale=2
   } else if(root.step===3) {
    root.check(root.row(audio,"Output")!==null,"native audio tab creates device rows")
    root.check(root.row(audio,"Output").height>0,"native audio layout")
    reference.refresh()
   } else if(root.step===4) {
    if(reference.busy) return
    root.check(reference.errorMessage==="","native IPC refresh: "+reference.errorMessage)
    const handler=reference.handlers.find(item=>item.name==="fixture")
    root.check(handler!==undefined,"native IPC target discovered")
    root.check(handler.functions.some(item=>item.name==="echo" && item.params==="value: int"),"native IPC signature")
    reference._query.command=["false"]
    reference.refresh()
   } else if(root.step===5) {
    if(reference.busy) return
    root.check(reference.errorMessage!=="","failed discovery reports an error")
    root.check(reference.handlers.some(item=>item.name==="fixture"),"failed refresh retains last good surface")
    reference._query.command=["qs","-p",Quickshell.shellDir,"ipc","show"]
    reference.refresh()
   } else if(root.step===6) {
    if(reference.busy) return
    root.check(reference.errorMessage==="","discovery recovers after retry")
    reference._query.command=["sleep","10"]
    reference.refresh()
   } else if(root.step===7) {
    if(reference.busy) return
    root.check(reference._timedOut && reference.errorMessage!=="","native IPC deadline cancels and reports failure")
    root.check(!reference._query.running,"timed-out discovery process stops")
    console.warn("NATIVE PASS");Qt.exit(0)
   }
   root.step++
  }
 }
}
''')
    env = {**os.environ, 'QT_QPA_PLATFORM': 'offscreen', 'QSG_RHI_BACKEND': 'software'}
    result = subprocess.run(['/usr/lib/qt6/bin/qmltestrunner', '-input', str(test),
                             '-import', str(temp / 'imports')], env=env,
                            capture_output=True, text=True, timeout=60)
    print(result.stdout + result.stderr)
    if result.returncode or "QWARN" in result.stdout + result.stderr:
        raise SystemExit(1)
    # Use Quickshell's actual built-in module, not the Qt-test stand-in.
    shutil.rmtree(qs)
    native_result = subprocess.run(['qs', '-p', str(native)], env=env,
                                   capture_output=True, text=True, timeout=20)
    native_output = native_result.stdout + native_result.stderr
    print(native_output)
    if native_result.returncode or 'NATIVE PASS' not in native_output or 'NATIVE FAIL' in native_output or 'Unable to assign' in native_output:
        raise SystemExit(1)
    runtime = env.get('XDG_RUNTIME_DIR', f'/run/user/{os.getuid()}')
    display = env.get('WAYLAND_DISPLAY', '')
    if not display or not (Path(runtime) / display).is_socket():
        print('Wayland surface checks skipped: no compositor socket.')
        raise SystemExit(0)
    # Exercise the real dock coordinator and entry pool without mapping its window.
    # Only desktop/compositor input data is replaced; no app or state action is run.
    fixture = temp / 'imports/TestDock'
    fixture.mkdir()
    (fixture / 'qmldir').write_text('module TestDock\nsingleton Hyprland 1.0 Hyprland.qml\nsingleton DesktopEntries 1.0 DesktopEntries.qml\n')
    (fixture / 'Hyprland.qml').write_text('pragma Singleton\nimport QtQml\nQtObject {property var toplevels:({values:[]})}\n')
    (fixture / 'DesktopEntries.qml').write_text('pragma Singleton\nimport QtQml\nQtObject {property QtObject applications:QtObject {property var values:[]};property var stats:({lookups:0});function heuristicLookup(value) {stats.lookups++;return null}}\n')
    dock_source=(ROOT / 'src/core/services/DockService.qml').read_text().replace('import Quickshell.Hyprland', 'import TestDock as Fixture').replace('Hyprland.', 'Fixture.Hyprland.').replace('DesktopEntries.', 'Fixture.DesktopEntries.')
    (services / 'DockService.qml').write_text(dock_source)
    dock_types=['DockIcon','DockTooltip','DockPanel','DockBar','DockContextMenu','DockPreview']
    (dock / 'qmldir').write_text('module qs.src.features.dock\n'+''.join(name+' 1.0 '+name+'.qml\n' for name in dock_types))
    for name in dock_types:
        shutil.copy2(ROOT / ('src/features/dock/'+name+'.qml'),dock / (name+'.qml'))
    dock_probe=tree / 'dock-probe.qml'
    dock_probe.write_text("""import QtQuick
import TestDock as Fixture
import Quickshell
import qs.src.core.config
import qs.src.core.services
import qs.src.features.dock
ShellRoot {
 id:root
 property int step:0
 property int ticks:0
 property var selected:DockService.entryForKey("dock-a")
 property var original:null
 DockPanel {id:dock;visible:false}
 function check(ok,message) {if(!ok) {console.warn("DOCK FAIL: "+message);Qt.exit(1);throw new Error(message)}}
 Component.onCompleted: {
  AppConfig.reduceMotion=true
  AppConfig.dockPinnedApps=["dock-a","dock-b"]
  root.check(DockService.model.length===2,"initial model")
  root.original=DockService.entryForKey("dock-a")
  dock._onPreviewRequest("dock-a",150)
  AppConfig.dockPinnedApps=["dock-b","dock-c","dock-a"]
  root.check(DockService.entryForKey("dock-a")===root.original,"pool preserves entry")
  root.check(dock._hoverApp.appId==="dock-a" && dock._tooltipText==="dock-a","hover follows app through reorder and insertion")
  root.check(dock._pendingPreviewKey==="dock-a","pending identity preserved")
 }
 Timer {
  interval:Tokens.interaction.tooltipDelay+60;repeat:true;running:true
  onTriggered: {
   root.check(++root.ticks<12,"probe deadline")
   if(root.step===0) {
    root.check(dock._previewKey==="dock-a" && dock._previewApp.appId==="dock-a","delayed reveal selects original app")
    AppConfig.dockPinnedApps=["dock-a","dock-b"]
    root.check(dock._previewKey==="dock-a","shown target survives reorder")
    dock._dismissPreview()
    dock._onPreviewRequest("dock-b",180)
    dock._onHoverEnded("dock-a")
    root.check(dock._pendingPreviewKey==="dock-b","old exit does not cancel new enter")
   } else if(root.step===1) {
    root.check(dock._previewKey==="dock-b","replacement deadline completes")
    AppConfig.dockPinnedApps=["dock-a"]
    root.check(dock._previewKey==="" && !dock._previewShowing,"removed shown target cleared")
    dock._onPreviewRequest("dock-a",150)
    AppConfig.dockPinnedApps=[]
    root.check(root.selected===null,"key lookup reacts to deletion")
    root.check(dock._pendingPreviewKey==="" && dock._hoverKey==="","removed pending target clears")
    AppConfig.dockPinnedApps=["dock-a","dock-b"]
   } else if(root.step===2) {
    root.check(dock._previewKey==="","removed then recreated app cannot revive old deadline")
    dock._onPreviewRequest("dock-a",150)
    dock._onHoverEnded("dock-a")
   } else if(root.step===3) {
    root.check(dock._previewKey==="" && dock._pendingPreviewKey==="","leave cancels pending reveal")
    dock._onPreviewRequest("dock-a",150)
    dock._onPreviewRequest("missing",0)
    root.check(dock._hoverKey==="dock-a","stale unknown request ignored")
    dock._onPreviewCancel("dock-b",180)
   } else if(root.step===4) {
    root.check(dock._previewKey==="" && dock._hoverKey==="dock-b","nonrunning hover cancels reveal")
    dock._onPreviewRequest("dock-a",150)
    dock._dismissPreview()
   } else {
    root.check(dock._previewKey==="" && dock._pendingPreviewKey==="","dismiss releases all timers")
    root.check(!dock.visible && !dock.menuGrabReady,"fixture stays invisible without grab")
    AppConfig.dockPinnedApps=["__proto__","constructor","tostring"]
    root.check(DockService.model.length===3,"prototype-like IDs remain distinct apps")
    root.check(DockService.entryForKey("__proto__").appId==="__proto__","prototype app is addressable")
    for(let i=0;i<600;i++)DockService.resolveEntry("fixture-miss-"+i)
    root.check(Object.keys(DockService._entryCache).length<=512,"entry cache stays bounded")
    const lookups=Fixture.DesktopEntries.stats.lookups
    DockService.resolveEntry("fixture-miss-599")
    root.check(Fixture.DesktopEntries.stats.lookups===lookups,"negative result is cached")
    DockService.resolveEntry("fixture-miss-0")
    root.check(Fixture.DesktopEntries.stats.lookups===lookups+1,"old negative result evicts")
    DockService.resolveEntry("fixture-class")
    Fixture.DesktopEntries.applications.values=[{id:"matched.desktop",name:"Fixture",startupClass:"fixture-class"}]
    root.check(DockService.resolveEntry("fixture-class")?.id==="matched.desktop","catalog change invalidates negative cache")
    console.warn("DOCK NATIVE PASS");Qt.quit()
   }
   root.step++
  }
 }
}
""")
    env['QML_IMPORT_PATH']=str(temp / 'imports')+os.pathsep+env.get('QML_IMPORT_PATH','')
    dock_env={**env,'QT_QPA_PLATFORM':'wayland','QT_QUICK_BACKEND':'software'}
    dock_result=subprocess.run(['qs','-p',str(dock_probe)],env=dock_env,capture_output=True,text=True,timeout=10)
    dock_output=dock_result.stdout+dock_result.stderr
    print(dock_output)
    if dock_result.returncode or 'DOCK NATIVE PASS' not in dock_output or any(marker in dock_output for marker in ['DOCK FAIL','ERROR','TypeError','ReferenceError','Binding loop','Unable to assign']):
        raise SystemExit(1)
    # Real Wayland geometry, with no input region or focus grab. The fixtures
    # are compositor-transparent and never intercept the user's session input.
    shutil.copy2(ROOT / 'src/core/services/PopoutsState.qml', services / 'PopoutsState.qml')
    for name in ['TrayMenu','TrayOverflow','BarOverflow']:
        shutil.copy2(ROOT / f'src/features/popouts/{name}.qml', tree / f'{name}.qml')
    def no_grab(source):
        start=source.index('    HyprlandFocusGrab {')
        level=0
        end=start
        for index in range(source.index('{',start),len(source)):
            if source[index]=='{': level+=1
            elif source[index]=='}': level-=1
            if level==0:
                end=index+1
                break
        return source[:start]+source[end:]
    source=no_grab((ROOT / 'src/features/popouts/Popouts.qml').read_text())
    source=source.replace('    color: "transparent"','    mask: Region {}\n    contentItem.opacity: 0\n    color: "transparent"',1)
    source=source.replace('WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None','WlrLayershell.keyboardFocus: WlrKeyboardFocus.None')
    source=source.replace('shell:popouts:global','shell:bar-test:popouts')
    (tree / 'NativePopouts.qml').write_text(source)
    source=no_grab((ROOT / 'src/features/dashboard/Dashboard.qml').read_text())
    source=source.replace('import QtQuick\n','import QtQuick\nimport qs.src.features.dashboard\n')
    source=source.replace('    id: root','    id: root\n    readonly property PanelWindow window: dashboardWindow\n    readonly property Item panel: dashboardLoader',1)
    source=source.replace('mask: Region { item: dashboardLoader }', 'mask: Region {}')
    source=source.replace('        color: "transparent"','        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None\n        contentItem.opacity: 0\n        color: "transparent"',1)
    source=source.replace('quickshell:dashboard','shell:bar-test:dashboard')
    (tree / 'NativeDashboard.qml').write_text(source)
    config_source=(config / 'AppConfig.qml').read_text().replace(' property int barHeight:', ' property int dashboardWidth:600\n property int dashboardHeight:640\n property int barHeight:')
    (config / 'AppConfig.qml').write_text(config_source)
    states=services / 'GlobalStates.qml'
    states.write_text(states.read_text().replace('QtObject {','QtObject {function panelRetained(name) {return false}\n',1).replace('property bool dashboardOpen:true','property bool dashboardOpen:false'))
    # Keep the real popup alive through suspension long enough to inspect its
    # last geometry; a fallback origin during unmap causes a visible left jump.
    source=(ROOT / 'src/ui/feedback/TooltipManager.qml').read_text()
    source=source.replace('import QtQuick\n','import QtQuick\nimport qs.src.ui.feedback\n',1)
    source=source.replace('    id: root','    id: root\n    property QtObject testPopup: null',1)
    source=source.replace('            id: popup','            id: popup\n            contentItem.opacity: 0\n            Component.onCompleted: root.testPopup = popup',1)
    (tree / 'NativeTooltipManager.qml').write_text(source)
    source=(ROOT / 'src/features/osd/OsdSurface.qml').read_text()
    source=source.replace('    id: root','    id: root\n    readonly property var testWindows: Array.from(testVariants.instances)',1)
    source=source.replace('    Variants {','    Variants {\n        id: testVariants',1)
    source=source.replace('            id: osdWindow','            id: osdWindow\n            contentItem.opacity: 0',1)
    (tree / 'OsdSurface.qml').write_text(source)
    for name in ['OsdMeter','OsdMeterContent','SystemOSD','ToastOverlay']:
        shutil.copy2(ROOT / f'src/features/osd/{name}.qml', tree / f'{name}.qml')
    source=no_grab((ROOT / 'src/features/launcher/Launcher.qml').read_text())
    source=source.replace('import QtQuick\n','import QtQuick\nimport qs.src.features.launcher\n',1)
    source=source.replace('Scope {','Scope {\n    readonly property PanelWindow window: launcherWindow\n    readonly property real cardHeight: contentLoader.height',1)
    source=source.replace('        color: "transparent"','        mask: Region {}\n        contentItem.opacity: 0\n        color: "transparent"',1)
    source=source.replace('focusable: true','focusable: false').replace('quickshell:launcher','shell:bar-test:launcher')
    (tree / 'NativeLauncher.qml').write_text(source)
    wayland=tree / 'wayland.qml'
    wayland.write_text('''import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.src.core.config
import qs.src.core.services
import qs.src.features.statusbar
import qs.src.ui.feedback
ShellRoot {
 id:root
 property int step:-2
 property int osdStep:0
 property int ticks:0
 property int settle:0
 property real dashboardSurfaceHeight:0
 property real dashboardEdge:0
 property real dashboardStartHeight:0
 property bool dashboardMoved:false
 property real dashboardFirstSampleHeight:-1
 function findProperty(item,name) {
  if(!item)return null
  if(item[name]!==undefined)return item
  for(const child of item.children ?? []) {const found=findProperty(child,name);if(found)return found}
  return null
 }
 function sampleDashboard(bottom) {
  root.check(dashboard.window.height===root.dashboardSurfaceHeight,"dashboard keeps native height during resizing")
  root.check(Math.abs(dashboard.panel.height-(dashboard.window.targetPanelHeight-Tokens.spacing.small*2))<=1,"card follows the painted extent without a trailing resize")
  const edge=dashboard.panel.y+(bottom ? dashboard.panel.height : 0)
  root.check(Math.abs(edge-root.dashboardEdge)<1,"dashboard card keeps its bar-side edge")
  const target=dashboard.window.targetPanelHeight-Tokens.spacing.small*2
  if(Math.abs(dashboard.panel.height-root.dashboardStartHeight)>1) {
   if(root.dashboardFirstSampleHeight<0)root.dashboardFirstSampleHeight=dashboard.panel.height
   else if(Math.abs(dashboard.panel.height-root.dashboardFirstSampleHeight)>1)root.dashboardMoved=true
  }
 }
 function settledDashboard() {
  const target=dashboard.window.targetPanelHeight-Tokens.spacing.small*2
  root.check(Math.abs(dashboard.panel.height-target)<=1,"dashboard reaches measured card height")
  if(Math.abs(target-root.dashboardStartHeight)>2)root.check(root.dashboardMoved,"dashboard height has intermediate frames step="+root.step+" start="+root.dashboardStartHeight+" target="+target)
 }
 function findRow(item,title) {
  if(!item) return null
  if(item.headline===title) return item
  for(const child of item.children ?? []) {const found=findRow(child,title);if(found) return found}
  return null
 }
 function check(ok,message) {if(!ok) {console.warn("BAR FAIL: "+message);Qt.exit(1);throw new Error(message)}}
 PanelWindow {
  id:bar
  anchors {left:true;top:AppConfig.barPosition!=="bottom";bottom:AppConfig.barPosition==="bottom"}
  implicitWidth:320;implicitHeight:BarMetrics.height
  color:"transparent";exclusiveZone:0
  mask:Region {}
  contentItem.opacity:0
  WlrLayershell.exclusionMode:ExclusionMode.Ignore
  WlrLayershell.namespace:"shell:bar-test"
  BarLayout {
   id:layout;anchors.fill:parent
   leftWidgets:[{type:"activewindow",settings:{maxWidth:300}}]
   centerWidgets:[{type:"clock",settings:{showDate:true}}]
   rightWidgets:[{type:"media",settings:{compact:false}},{type:"weather"},{type:"network",settings:{showLabel:true}},{type:"notifications"},{type:"layout"},{type:"volume",priority:0}]
  }
 }
 NativeTooltipManager {id:hints;bar:bar}
 Item {id:hintOwner;x:200;width:40;height:20;parent:bar.contentItem}
 TooltipItem {id:hint;tooltip:hints;owner:hintOwner;text:"Tooltip suspension regression";show:true}
 SystemOSD {id:systemOsd}
 ToastOverlay {id:toast}
 NativePopouts {id:popoutFixture}
 NativeDashboard {id:dashboard}
 NativeLauncher {id:nativeLauncher}
 Timer {
  interval:60;repeat:true;running:true
  onTriggered: {
   root.check(++root.ticks<170,"Wayland deadline step="+root.step+" entries="+layout.entries.length+" hidden="+layout.overflowWidgets.length+" name="+PopoutsState.name+" popup="+popoutFixture.visible+" size="+popoutFixture.width+","+popoutFixture.height+" screen="+popoutFixture._screen+" rect="+PopoutsState.popoutHeight)
   if(root.step===-2) {
    if(!hints.testPopup || !hints.testPopup.visible || hint.opacity<1) return
    const popup=hints.testPopup
    const rect=popup.anchor.rect
    const width=popup.width,height=popup.height
    root.check(rect.x>Tokens.spacing.medium,"tooltip starts away from screen edge")
    hints.suspended=true
    root.check(!popup.visible,"suspension hides tooltip window")
    root.check(popup.anchor.rect.x===rect.x && popup.anchor.rect.y===rect.y,"tooltip position retained on suspension")
    root.check(popup.width===width && popup.height===height,"tooltip size retained on suspension")
    root.step=-1
   } else if(root.step===-1) {
    if(root.osdStep===0) {
     GlobalStates.testScreen=bar.screen
     AudioService.volumeChanged(0.42,false);root.osdStep=1;return
    }
    if(root.osdStep===1) {
     const windows=systemOsd.testWindows.filter(window=>window.visible)
     if(!windows.length) return
     root.check(windows.length===1 && windows[0].screen.name===bar.screen.name,"OSD selects one focused output")
     root.check(windows[0].width<=bar.screen.width && windows[0].height>0,"OSD fits screen")
     BrightnessService.brightnessAdjusted(0.75)
     root.check(!systemOsd.isVolume && systemOsd.progress===0.75,"brightness replaces volume in the same meter")
     root.osdStep=2;return
    }
    if(root.osdStep===2) {
     AppConfig.osdMonitorPolicy="all";root.osdStep=3;return
    }
    if(root.osdStep===3) {
     root.check(systemOsd.testWindows.filter(window=>window.visible).length===Quickshell.screens.length,"all-output compatibility")
     AppConfig.osdMonitorPolicy="focused"
     ToastService.toastRequested("<b>Literal text</b> "+"Long message ".repeat(60),"info",0,500)
     root.osdStep=4;return
    }
    if(root.osdStep===4) {
     const windows=toast.testWindows.filter(window=>window.visible)
     if(!windows.length) return
     root.check(windows.length===1 && windows[0].width<=bar.screen.width,"long toast is bounded to one output")
     root.check(windows[0].height>Tokens.typography.bodyMedium.lineHeight && windows[0].height<=Tokens.typography.bodyMedium.lineHeight*5+Tokens.spacing.large*2,"toast wraps with bounded height")
     GlobalStates.lockscreenActive=true
     root.check(!systemOsd.shown && !toast.shown && toast._queue.length===0,"lock clears passive overlays")
     GlobalStates.lockscreenActive=false
     root.check(!toast.testWindows.some(window=>window.visible),"unlock does not revive an exiting toast")
     AudioService.volumeChanged(0.5,false)
     root.osdStep=5;root.settle=0;return
    }
    if(root.osdStep===5) {
     if(++root.settle<6) return
     AudioService.volumeChanged(0.6,false);root.osdStep=6;root.settle=0;return
    }
    if(root.osdStep===6) {
     if(++root.settle<6) return
     root.check(systemOsd.shown,"repeated action restarts OSD deadline")
     root.osdStep=7;root.settle=0;return
    }
    if(root.osdStep===7) {
     if(++root.settle<4) return
     root.check(!systemOsd.shown,"OSD hides after the final action")
     root.step=-3;root.settle=0
    }
   } else if(root.step===-3) {
    if(root.settle===0) {GlobalStates.activePanelScreen=bar.screen;GlobalStates.launcherOpen=true}
    if(++root.settle<6) return
    root.check(nativeLauncher.window.visible && nativeLauncher.cardHeight>Tokens.size.field,"native launcher maps with measured content")
    root.check(nativeLauncher.window.width<=bar.screen.width && nativeLauncher.window.height<=bar.screen.height,"native launcher fits")
    GlobalStates.launcherOpen=false;root.step=0
   } else if(root.step===0) {
    if(!layout.overflowWidgets.length) return
    PopoutsState.openPopout("baroverflow",layout,layout.overflowAnchor);root.step=1
   } else if(root.step===1) {
    if(!PopoutsState.popoutHeight) return
    const audio=findRow(popoutFixture.contentItem,"Audio")
    if(!audio) return
    root.check(PopoutsState.popoutX>=0 && PopoutsState.popoutX+PopoutsState.popoutWidth<=bar.screen.width,"native More fits screen")
    audio.clicked()
    root.check(GlobalStates.lastAction==="audio","More action survives popup destruction")
    PopoutsState.closePopout();AppConfig.barPosition="bottom";AppConfig.fontScale=2;root.step=2
   } else if(root.step===2) {
    if(++root.settle<4) return
    root.check(bar.height===BarMetrics.height,"native bar follows font height")
    PopoutsState.openPopout("baroverflow",layout,layout.overflowAnchor);root.step=3
   } else if(root.step===3) {
    if(!PopoutsState.popoutHeight) return
    root.check(PopoutsState.popoutY+PopoutsState.popoutHeight<=bar.screen.height-BarMetrics.height+1,"More above bottom bar")
    PopoutsState.closePopout();AppConfig.fontScale=1;GlobalStates.activePanelScreen=bar.screen;GlobalStates.dashboardOpen=true;root.settle=0;root.step=4
   } else if(root.step===4) {
    if(!dashboard.window.visible || !dashboard.window.height) return
    root.check(dashboard.window.height<=bar.screen.height-BarMetrics.height,"dashboard height bounded")
    root.check(dashboard.window.margins.bottom>=BarMetrics.height && dashboard.window.anchors.bottom,"dashboard bottom margin")
    if(++root.settle<3)return
    root.dashboardSurfaceHeight=dashboard.window.height
    root.dashboardEdge=dashboard.panel.y+dashboard.panel.height
    root.dashboardStartHeight=dashboard.panel.height;root.dashboardMoved=false;root.dashboardFirstSampleHeight=-1
    AppConfig.reduceMotion=false
    findProperty(dashboard.panel,"metricsExpanded").metricsExpanded=true
    root.settle=0;root.step=41
   } else if(root.step===41) {
    root.sampleDashboard(true)
    if(++root.settle<10)return
    root.settledDashboard()
    root.dashboardStartHeight=dashboard.panel.height;root.dashboardMoved=false;root.dashboardFirstSampleHeight=-1
    findProperty(dashboard.panel,"metricsExpanded").metricsExpanded=false
    root.settle=0;root.step=42
   } else if(root.step===42) {
    root.sampleDashboard(true)
    if(++root.settle<10)return
    root.settledDashboard()
    GlobalStates.dashboardOpen=false;AppConfig.barPosition="top";root.settle=0;root.step=5
   } else if(root.step===5) {
    if(++root.settle<4) return
    GlobalStates.dashboardOpen=true;root.step=6;root.settle=0
   } else if(root.step===6) {
    if(++root.settle<4) return
    root.check(dashboard.window.margins.top>=BarMetrics.height && dashboard.window.anchors.top,"dashboard top margin")
    root.dashboardSurfaceHeight=dashboard.window.height
    root.dashboardEdge=dashboard.panel.y
    root.dashboardStartHeight=dashboard.panel.height;root.dashboardMoved=false;root.dashboardFirstSampleHeight=-1
    findProperty(dashboard.panel,"morph").expanded=true
    root.settle=0;root.step=7
   } else if(root.step===7) {
    root.sampleDashboard(false)
    if(++root.settle<10)return
    root.settledDashboard()
    root.dashboardStartHeight=dashboard.panel.height;root.dashboardMoved=false;root.dashboardFirstSampleHeight=-1
    findProperty(dashboard.panel,"morph").expanded=false
    root.settle=0;root.step=71
   } else if(root.step===71) {
    root.sampleDashboard(false)
    if(++root.settle<10)return
    root.settledDashboard()
    GlobalStates.dashboardOpenIndex=1;root.settle=0;root.step=8
   } else if(root.step===8) {
    root.check(dashboard.window.height===root.dashboardSurfaceHeight,"tab handover keeps native surface stable")
    root.check(Math.abs(dashboard.panel.height-(dashboard.window.targetPanelHeight-Tokens.spacing.small*2))<=1,"tab handover has no trailing background")
    if(++root.settle<10)return
    root.check(Math.abs(dashboard.panel.height-(dashboard.window.targetPanelHeight-Tokens.spacing.small*2))<=1,"tab handover reaches its measured height")
    AppConfig.reduceMotion=true;GlobalStates.dashboardOpenIndex=0;root.settle=0;root.step=9
   } else {
    if(++root.settle<2)return
    root.check(Math.abs(dashboard.panel.height-(dashboard.window.targetPanelHeight-Tokens.spacing.small*2))<=1,"reduced motion applies geometry immediately")
    GlobalStates.dashboardOpen=false
    console.warn("BAR WAYLAND PASS");Qt.quit()
   }
  }
 }
}
''')
    env.pop('QSG_RHI_BACKEND',None)
    env.update(QT_QPA_PLATFORM='wayland',QT_QUICK_BACKEND='software')
    wayland_result=subprocess.run(['qs','-p',str(wayland)],env=env,capture_output=True,text=True,timeout=15)
    output=wayland_result.stdout+wayland_result.stderr
    print(output)
    raise SystemExit(wayland_result.returncode or (0 if 'BAR WAYLAND PASS' in output and not any(marker in output for marker in ['BAR FAIL','ERROR','TypeError','ReferenceError','Binding loop','Unable to assign']) else 1))
