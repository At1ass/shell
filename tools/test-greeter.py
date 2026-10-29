#!/usr/bin/env python3
"""Greeter UI/authentication with fake greetd, keyboard, user/session and power data."""
from pathlib import Path
import tempfile, shutil, subprocess, os, json

ROOT = Path(__file__).resolve().parents[1]
GREETER = ROOT / 'src/features/greeter'
# Validate the actual compositor entry point as well as the QML UI. Verification
# does not start a compositor or fire the hyprland.start callback.
if shutil.which('Hyprland') and os.geteuid() != 0:
    with tempfile.TemporaryDirectory(prefix='greeter-hypr-verify-') as runtime:
        checked = subprocess.run(
            ['Hyprland', '--verify-config', '-c', str(ROOT / 'packaging/arch/hyprland-greeter.conf')],
            env={**os.environ, 'XDG_RUNTIME_DIR': runtime},
            capture_output=True, text=True, timeout=15)
        output = checked.stdout + checked.stderr
        if checked.returncode or 'config ok' not in output:
            raise SystemExit('Greeter compositor config validation failed:\n' + output)
        print('PASS: packaged greeter compositor configuration (Hyprland --verify-config)')
else:
    print('SKIP: compositor config verification requires Hyprland and a non-root user')
with tempfile.TemporaryDirectory(prefix='shell-greeter-test-') as temp:
    temp = Path(temp)
    imports = temp / 'imports'
    tree = imports / 'qs'
    shutil.copytree(GREETER, tree)
    config = tree / 'config'
    defaults = json.loads((config / 'default.json').read_text())
    schema = json.loads((config / 'greeter.schema.json').read_text())
    assert all(schema['properties'][key]['default'] == value for key,value in defaults.items())
    # No native config, process, keyboard, greetd or user enumeration is used.
    mocks = {
        'GreeterConfig': 'property string configError:"";property bool ready:true;property string wallpaperPath:"";property bool darkMode:true;property string themeVariant:"vibrant";property string themeColor:"#6200EE";property real themeContrast:0;property string designSystem:"minimal";property real fontScale:1.3;property bool reduceMotion:true;property bool showAvatar:true;property bool showClock:true;property bool showDate:true;property bool showBattery:true;property bool showPower:true;property bool blurWallpaper:false;property string defaultUser:"";property string defaultSession:""',
        'KeyboardLayoutService': 'property string currentLayoutCode:"en";property var layoutCodes:["en","ru"];property bool capsLockEnabled:false;property int watchers:0;function addLockStateWatcher() {watchers++} function removeLockStateWatcher() {watchers--} function switchLayout() {currentLayoutCode=currentLayoutCode==="en" ? "ru" : "en"}'
    }
    for name,body in mocks.items():
        (config / (name+'.qml')).write_text('pragma Singleton\nimport QtQml\nQtObject {\n'+body+'\n}\n')
    # A distinct URI prevents an installed native type from shadowing the fixture.
    for source in tree.rglob('*.qml'):
        source.write_text(source.read_text().replace('import GreeterData', 'import TestGreeterData'))
    backend = imports / 'TestGreeterData'
    backend.mkdir(parents=True)
    (backend/'qmldir').write_text('module TestGreeterData\nAccountProfile 1.0 AccountProfile.qml\nsingleton GreeterDataBackend 1.0 GreeterDataBackend.qml\n')
    (backend/'AccountProfile.qml').write_text('import QtQml\nQtObject {property string username:"";property bool active:true;property url iconSource:""}\n')
    (backend/'GreeterDataBackend.qml').write_text('''pragma Singleton
import QtQml
QtObject {
 property var sessions:[{id:"wayland/hyprland.desktop",name:"Hyprland",exec:"start-hyprland",argv:["start-hyprland"]}]
 property var users:[{username:"alice",displayName:"Alice"}]
 property bool ready:true
 property string errorString:""
 readonly property var sessionNames:sessions.map(item=>item.name)
 readonly property var userNames:users.map(item=>item.displayName)
 function sessionIndex(preferred) {if(!preferred)return -1;let at=sessions.findIndex(item=>item.id===preferred || item.name.toLowerCase()===preferred.toLowerCase());return at>=0?at:sessions.findIndex(item=>item.exec.toLowerCase().includes(preferred.toLowerCase()))}
 function userIndex(username) {return users.findIndex(item=>item.username===username)}
}
''')
    qs = imports / 'Quickshell'
    qs.mkdir()
    (qs/'qmldir').write_text('module Quickshell\nSingleton 1.0 Singleton.qml\n')
    (qs/'Singleton.qml').write_text('import QtQml\nQtObject {default property list<QtObject> children}\n')
    greetd = imports / 'Quickshell/Services/Greetd'
    greetd.mkdir(parents=True)
    (greetd/'qmldir').write_text('module Quickshell.Services.Greetd\nsingleton Greetd 1.0 Greetd.qml\nGreetdState 1.0 GreetdState.qml\n')
    (greetd/'GreetdState.qml').write_text('import QtQml\nQtObject {enum State {Inactive,Authenticating,ReadyToLaunch,Launching,Launched}}\n')
    (greetd/'Greetd.qml').write_text('''pragma Singleton
import QtQml
QtObject {
 property bool available:true
 property int state:0
 property int creates:0
 property int responses:0
 property int cancels:0
 property int launches:0
 property string user:""
 property string response:""
 property var launchedCommand:[]
 signal authMessage(string message,bool error,bool responseRequired,bool echoResponse)
 signal authFailure(string message)
 signal error(string message)
 signal readyToLaunch()
 function createSession(name) {creates++;user=name;state=1}
 function respond(value) {responses++;response=value}
 function cancelSession() {cancels++;state=0}
 function launch(command,environment,quit) {launches++;launchedCommand=command;state=3}
}
''')
    (temp/'tst_greeter.qml').write_text('''import TestGreeterData
import QtQuick
import QtTest
import qs.config
import qs.ui
import qs.components
import Quickshell.Services.Greetd
Item {
 id: scene
 width:800;height:900
 Component {id:authFixture;GreeterAuth {active:true;property int cleared:0;onClearCredentials:cleared++}}
 Component {id:formFixture;LoginForm {width:360;property int submits:0;property string submittedUser:"";onSubmit:(username,password)=>{submits++;submittedUser=username}}}
 Component {id:powerFixture;PowerActions {width:640;height:480;property string request:"";onRequested:action=>request=action}}
 TestCase {
  name:"Greeter";when:windowShown
  function init() {
   Greetd.state=0;Greetd.available=true;Greetd.creates=0;Greetd.responses=0;Greetd.cancels=0;Greetd.launches=0;Greetd.response=""
   GreeterDataBackend.ready=false;SessionModel._defaultApplied=false;SessionModel._selectedId="";SessionModel.selectedIndex=0
   GreeterConfig.defaultSession="";GreeterConfig.showAvatar=true
   GreeterConfig.designSystem="minimal";GreeterConfig.fontScale=1.3;GreeterConfig.ready=true;GreeterConfig.defaultUser=""
   GreeterDataBackend.users=[{username:"alice",displayName:"Alice"}]
   GreeterDataBackend.sessions=[{name:"Hyprland",exec:"start-hyprland",id:"wayland/hyprland.desktop",argv:["start-hyprland"]}];SessionModel.selectedIndex=0;GreeterDataBackend.ready=true
   scene.Window.window.requestActivate();wait(10)
  }
  function test_avatar_visibility_and_identity_fallback() {
   const form=createTemporaryObject(formFixture,scene);wait(1)
   const avatar=findChild(form,"greeterAvatar")
   verify(avatar!==null);verify(avatar.visible);compare(avatar.imageSource,"")
   GreeterConfig.showAvatar=false;verify(!avatar.visible)
   GreeterConfig.showAvatar=true;verify(avatar.visible)
   form.manualUser=true;verify(!avatar.visible)
   const password=findChild(form,"greeterPassword")
   verify(password.visible && password.enabled)
  }
  function test_auth_password_failure_retry() {
   const auth=createTemporaryObject(authFixture,scene)
   auth.submit("alice","wrong",["start-hyprland"])
   compare(Greetd.creates,1);verify(auth.busy);verify(auth.cleared>0)
   auth.submit("alice","duplicate",["start-hyprland"]);compare(Greetd.creates,1)
   Greetd.authMessage("Password:",false,true,false)
   compare(Greetd.response,"wrong");compare(auth._pendingPassword,"")
   Greetd.state=0;Greetd.authFailure("Incorrect password")
   compare(auth.errorMessage,"Incorrect password");verify(!auth.inProgress);compare(Greetd.launches,0)
   auth.submit("alice","correct",["start-hyprland","--safe"])
   Greetd.authMessage("Password:",false,true,false)
   Greetd.state=2;Greetd.readyToLaunch()
   compare(Greetd.launches,1);compare(Greetd.launchedCommand.join("|"),"start-hyprland|--safe")
  }
  function test_auth_additional_prompt_and_recoverable_error() {
   const auth=createTemporaryObject(authFixture,scene)
   auth.submit("alice","secret",["start-hyprland"])
   Greetd.authMessage("Fingerprint unreadable",true,false,false)
   verify(auth.inProgress);compare(auth.errorMessage,"Fingerprint unreadable")
   Greetd.authMessage("Password:",false,true,false);compare(Greetd.responses,1)
   Greetd.authMessage("Verification code:",false,true,false)
   verify(auth.responseRequired);verify(!auth.busy);compare(auth.prompt,"Verification code:")
   auth.submit("alice","123456",[])
   compare(Greetd.creates,1);compare(Greetd.responses,2);compare(Greetd.response,"123456")
   Greetd.authMessage("Visible response:",false,true,true)
   verify(auth.echoResponse);auth.submit("alice","yes",[])
   compare(Greetd.response,"yes")
   auth.cancel();verify(!auth.inProgress);compare(auth._pendingPassword,"");compare(Greetd.cancels,1)
   Greetd.readyToLaunch();compare(Greetd.launches,0)
  }
  function test_first_visible_prompt_does_not_receive_password() {
   const auth=createTemporaryObject(authFixture,scene)
   auth.submit("alice","private",["start-hyprland"])
   Greetd.authMessage("Username:",false,true,true)
   compare(Greetd.responses,0);compare(auth._pendingPassword,"");verify(auth.responseRequired)
   auth.active=false;compare(Greetd.cancels,1)
  }
  function test_session_default_waits_for_config() {
   GreeterConfig.ready=false;GreeterConfig.defaultSession="Two"
   SessionModel._defaultApplied=false
   GreeterDataBackend.sessions=[{id:"one",name:"One",exec:"one",argv:["one"]},{id:"two",name:"Two",exec:"two",argv:["two"]}]
   compare(SessionModel.selectedIndex,0)
   GreeterConfig.ready=true
   compare(SessionModel.selectedIndex,1)
  }
  function test_argv_snapshot_without_reparsing() {
   const auth=createTemporaryObject(authFixture,scene)
   const argv=["/usr/bin/session","two words","","$HOME","literal;command"]
   auth.submit("alice","secret",argv)
   argv[1]="changed"
   Greetd.state=2;Greetd.readyToLaunch()
   compare(Greetd.launchedCommand.join("|"),"/usr/bin/session|two words||$HOME|literal;command")
  }
  function test_session_choice_binding_survives_keyboard_and_reorder() {
   GreeterDataBackend.sessions=[{id:"one",name:"One",exec:"one",argv:["one"]},{id:"two",name:"Two",exec:"two",argv:["two"]}]
   const form=createTemporaryObject(formFixture,scene);wait(1)
   const chooser=findChild(form,"greeterSessionChoice")
   verify(chooser!==null && chooser.visible)
   chooser.forceActiveFocus();keyClick(Qt.Key_Down)
   compare(SessionModel.currentSession.id,"two");compare(chooser.currentText,"Two")
   GreeterDataBackend.sessions=[{id:"two",name:"Two",exec:"two",argv:["two"]},{id:"one",name:"One",exec:"one",argv:["one"]}]
   compare(SessionModel.currentSession.id,"two")
   compare(chooser.currentIndex,SessionModel.selectedIndex)
   compare(chooser.currentText,"Two")
   keyClick(Qt.Key_Down);compare(SessionModel.currentSession.id,"one")
   GreeterDataBackend.sessions=[{id:"two",name:"Two",exec:"two",argv:["two"]}]
   compare(SessionModel.currentSession.id,"two");compare(chooser.currentText,"Two")
  }
  function test_catalog_selection_survives_reorder() {
   GreeterDataBackend.sessions=[{id:"one",name:"One",exec:"one",argv:["one"]},{id:"two",name:"Two",exec:"two",argv:["two"]}]
   SessionModel.selectedIndex=1
   GreeterDataBackend.sessions=[{id:"two",name:"Two",exec:"two",argv:["two"]},{id:"one",name:"One",exec:"one",argv:["one"]}]
   compare(SessionModel.selectedIndex,0)
   compare(SessionModel.currentSession.id,"two")
   GreeterDataBackend.sessions=[{id:"one",name:"One",exec:"one",argv:["one"]}]
   compare(SessionModel.currentSession.id,"one")
  }
  function test_missing_service_or_session() {
   const auth=createTemporaryObject(authFixture,scene)
   Greetd.available=false;auth.submit("alice","secret",["start-hyprland"])
   compare(Greetd.creates,0);verify(auth.errorMessage!=="")
   Greetd.available=true;auth.submit("alice","secret","")
   compare(Greetd.creates,0)
  }
  function test_user_selection_and_other_user() {
   const form=createTemporaryObject(formFixture,scene)
   wait(1);compare(form.username,"alice");verify(!form.manualUser)
   const field=findChild(form,"greeterPassword")
   verify(field.inputItem.activeFocus)
   field.text="secret";keyClick(Qt.Key_Return);compare(form.submits,1)
   findChild(form,"greeterChangeUser").clicked()
   const choice=findChild(form,"greeterUserChoice")
   choice.currentIndex=UserModel.count;wait(1)
   verify(form.manualUser);compare(form.password,"")
   findChild(form,"greeterUsername").text="bob"
   compare(form.username,"bob")
   findChild(form,"greeterChangeUser").clicked();choice.currentIndex=0;wait(1)
   compare(form.username,"alice");verify(!form.manualUser)
  }
  function test_prompt_echo_and_tab() {
   const form=createTemporaryObject(formFixture,scene)
   wait(1)
   const field=findChild(form,"greeterPassword")
   form.identityLocked=true;form.responseRequired=true;form.echoResponse=true;form.prompt="Code"
   form.clearPassword();verify(!field.password)
   form.echoResponse=false;verify(field.password)
   form.identityLocked=false;form.responseRequired=false
   field.text="secret";field.inputItem.forceActiveFocus()
   keyClick(Qt.Key_Tab);verify(!field.inputItem.activeFocus)
   keyClick(Qt.Key_Backtab);verify(field.inputItem.activeFocus)
  }
  function test_sessions_and_layout_data() {
   return [{tag:"minimal",pack:"minimal",scale:1.3,w:360},{tag:"md3",pack:"md3",scale:1.3,w:360},{tag:"small-large",pack:"minimal",scale:2,w:280}]
  }
  function test_sessions_and_layout(data) {
   GreeterConfig.designSystem=data.pack;GreeterConfig.fontScale=data.scale
   const form=createTemporaryObject(formFixture,scene,{width:data.w})
   verify(!findChild(form,"greeterSessionChoice").visible)
   GreeterDataBackend.sessions=[{id:"one",name:"One",exec:"one",argv:["one"]},{id:"two",name:"Two",exec:"two",argv:["two"]}];wait(1)
   const choice=findChild(form,"greeterSessionChoice")
   verify(choice.visible);choice.forceActiveFocus();keyClick(Qt.Key_Down);compare(SessionModel.selectedIndex,1)
   const field=findChild(form,"greeterPassword")
   verify(field.inputItem.width>0);verify(field.height>0)
  }
  function test_power_confirmation_cancel_focus() {
   const power=createTemporaryObject(powerFixture,scene)
   power.show();wait(1)
   const focused=scene.Window.window.activeFocusItem
   compare(focused.text,"Cancel")
   keyClick(Qt.Key_Return);verify(!power.opened)
   power.show();wait(1)
   keyClick(Qt.Key_Tab)
   compare(scene.Window.window.activeFocusItem.text,"Sleep")
   keyClick(Qt.Key_Tab);keyClick(Qt.Key_Return);wait(1)
   compare(power.confirming,"reboot");compare(power.request,"")
   compare(scene.Window.window.activeFocusItem.text,"Cancel")
   keyClick(Qt.Key_Tab);keyClick(Qt.Key_Return)
   compare(power.request,"reboot")
   keyClick(Qt.Key_Escape);verify(!power.opened)
  }
 }
}
''')
    env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QML_IMPORT_PATH=os.pathsep.join(filter(None,[str(imports),os.environ.get('QML_IMPORT_PATH','')])),QT_QUICK_CONTROLS_STYLE='Basic')
    result=subprocess.run(['/usr/lib/qt6/bin/qmltestrunner','-input',str(temp/'tst_greeter.qml'),'-import',str(imports)],env=env,text=True,capture_output=True,timeout=60)
    print(result.stdout+result.stderr)
    if result.returncode:
        raise SystemExit(result.returncode)
    # A native Quickshell render of the actual surface, in an offscreen Window.
    # No session lock, layer-shell window or power/authentication action is used.
    source=(tree/'GreeterSurface.qml').read_text().replace('required property ShellScreen screen','property QtObject screen:null')
    (tree/'GreeterSurface.qml').write_text(source)
    renders=Path('/tmp/shell-greeter-renders');renders.mkdir(exist_ok=True)
    for pack,width,height,scale in [('minimal',1280,900,1.3),('md3',1280,900,1.3),('minimal',320,480,2)]:
        output=str(renders/f'{pack}-{width}.png')
        preview='''import QtQuick
import QtQuick.Window
import qs.config
import qs.ui
import "."
QtObject {
 property Window window:Window {id:win;width:WIDTH;height:HEIGHT;visible:true;GreeterSurface {id:surface;anchors.fill:parent;screen:null;isPrimary:true}}
 property Timer prepare:Timer {interval:100;running:true;onTriggered:{GreeterConfig.designSystem="PACK";GreeterConfig.fontScale=SCALE}}
 property Timer capture:Timer {interval:700;running:true;onTriggered:surface.grabToImage(result=>{result.saveToFile("OUTPUT");console.warn("GREETER RENDER PASS");Qt.quit()})}
}
'''.replace('WIDTH',str(width)).replace('HEIGHT',str(height)).replace('PACK',pack).replace('SCALE',str(scale)).replace('OUTPUT',output)
        (tree/'_preview.qml').write_text(preview)
        render=subprocess.run(['qs','-p',str(tree/'_preview.qml')],env=env,text=True,capture_output=True,timeout=8)
        print(render.stdout+render.stderr)
        assert render.returncode==0 and 'GREETER RENDER PASS' in render.stderr+render.stdout
        assert not any(token in render.stderr+render.stdout for token in ['TypeError','ReferenceError','Unable to assign'])
        assert Path(output).exists()
    print('PASS: native greeter rendering in both profiles and on a small output')
    production=(GREETER/'config/GreeterConfig.qml').read_text().replace('"/etc/greetd/greeter.json"',json.dumps(str(temp/'greeter.json')))
    (config/'RealGreeterConfig.qml').write_text(production)
    (config/'qmldir').write_text((config/'qmldir').read_text()+'singleton RealGreeterConfig 1.0 RealGreeterConfig.qml\n')
    for invalid,data in [(False,{'designSystem':'md3','showClock':False}),(True,{'showPower':'yes'})]:
        (temp/'greeter.json').write_text(json.dumps(data))
        probe='''import QtQuick
import qs.config
QtObject {
 property QtObject config:RealGreeterConfig
 property Timer check:Timer {interval:500;running:true;onTriggered:{
  if(!config.ready || (config.configError!=="")!==INVALID) {console.warn("CONFIG FAIL "+config.configError);Qt.exit(1);return}
  if(!INVALID && (config.designSystem!=="md3" || config.showClock)) {Qt.exit(2);return}
  if(INVALID && (config.designSystem!=="minimal" || !config.showPower)) {Qt.exit(3);return}
  console.warn("GREETER CONFIG PASS");Qt.quit()
 }}
}
'''.replace('INVALID',str(invalid).lower())
        (tree/'_config_probe.qml').write_text(probe)
        checked=subprocess.run(['qs','-p',str(tree/'_config_probe.qml')],env=env,text=True,capture_output=True,timeout=8)
        print(checked.stdout+checked.stderr)
        assert checked.returncode==0 and 'GREETER CONFIG PASS' in checked.stdout+checked.stderr
    print('PASS: production config loading, schema rejection and safe defaults')
