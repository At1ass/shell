#!/usr/bin/env python3
"""Exercise weather recovery with an inert transport; never contact the provider."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='shell-weather-') as directory:
    directory = Path(directory)
    imports = directory / 'imports'

    def write(name, text):
        path = imports / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)

    write('Quickshell/qmldir', 'module Quickshell\nSingleton 1.0 Singleton.qml\n')
    write('Quickshell/Singleton.qml', 'import QtQml\nQtObject {default property list<QtObject> children}\n')
    write('Quickshell/Io/qmldir', 'module Quickshell.Io\nIpcHandler 1.0 IpcHandler.qml\n')
    write('Quickshell/Io/IpcHandler.qml', 'import QtQml\nQtObject {property string target:""}\n')
    write('qs/src/core/config/qmldir', 'module qs.src.core.config\nsingleton AppConfig 1.0 AppConfig.qml\n')
    write('qs/src/core/config/AppConfig.qml', '''pragma Singleton
import QtQml
QtObject {
 property bool ready:false
 property bool weatherEnabled:true
 property bool gmDisableWeather:true
 property string weatherUnits:"metric"
 property string weatherLocation:"Test"
 property real weatherLatitude:50
 property real weatherLongitude:30
 property int weatherRefreshMinutes:30
}
''')
    services = 'qs/src/core/services/'
    write(services+'qmldir', 'module qs.src.core.services\nHttpRequest 1.0 HttpRequest.qml\n'+''.join(
        f'singleton {name} 1.0 {name}.qml\n' for name in ['Weather','GamingModeService','DateTime','WeatherIcons','ToastService']))
    shutil.copy2(ROOT/'src/core/services/Weather.qml', imports/services/'Weather.qml')
    write(services+'GamingModeService.qml', 'pragma Singleton\nimport QtQml\nQtObject {property bool gamingModeActive:false}\n')
    write(services+'DateTime.qml', 'pragma Singleton\nimport QtQml\nQtObject {property QtObject clock:QtObject {property date date:new Date()}}\n')
    write(services+'WeatherIcons.qml', 'pragma Singleton\nimport QtQml\nQtObject {property var codeToName:({})}\n')
    write(services+'ToastService.qml', 'pragma Singleton\nimport QtQml\nQtObject {property int warnings:0;function warning(message) {warnings++}}\n')
    write(services+'HttpRequest.qml', '''import QtQml
QtObject {
 objectName:"weatherTransport"
 property bool running:false
 property int starts:0
 property string url:""
 signal succeeded(string body)
 signal failed(string message,int status)
 function get(value) {url=value;starts++;running=true}
 function cancel() {running=false}
 function complete(body) {running=false;succeeded(body)}
 function reject(message,status) {running=false;failed(message,status)}
}
''')
    test = directory/'tst_weather.qml'
    test.write_text('''import QtQuick
import QtTest
import qs.src.core.config
import qs.src.core.services
TestCase {
 name:"WeatherRecovery";when:windowShown
 property QtObject request:null
 readonly property string sample:JSON.stringify({current:{temperature_2m:12}})
 function init() {
  AppConfig.ready=false;AppConfig.weatherEnabled=true;GamingModeService.gamingModeActive=false
  AppConfig.weatherUnits="metric";AppConfig.weatherLatitude=50;wait(1)
  request=findChild(Weather,"weatherTransport");verify(request!==null)
  request.cancel();request.starts=0
  Weather.data=null;Weather.lastSuccessAt=new Date(0);Weather.errorString="";Weather.errorDetails=""
  Weather._retryMs=0;ToastService.warnings=0
  AppConfig.ready=true;wait(1);verify(Weather.busy)
 }
 function cleanup() {AppConfig.ready=false}
 function test_failure_preserves_sample_and_error_during_retry() {
  request.complete(sample);compare(Weather.tempC,12)
  Weather.fetchIfStale();verify(!Weather.busy,"fresh automatic sample is not fetched")
  Weather.lastAttemptAt=new Date(0);verify(Weather.fetchNow())
  request.reject("HTTP 503",503)
  compare(Weather.tempC,12);verify(Weather.canRetry)
  const message=Weather.errorString
  verify(message.includes("Check your connection"));compare(Weather.errorDetails,"HTTP 503")
  verify(Weather.retry());verify(!Weather.retry(),"single request at a time")
  compare(Weather.errorString,message)
  request.reject("Network error",0);compare(ToastService.warnings,1,"one toast per failure episode")
  verify(Weather.retry());request.complete(sample)
  compare(Weather.errorString,"");compare(Weather.errorDetails,"");verify(!Weather.canRetry)
 }
 function test_invalid_response_never_replaces_last_sample() {
  request.complete(sample);Weather.lastAttemptAt=new Date(0);verify(Weather.fetchNow())
  request.complete("{broken")
  compare(Weather.tempC,12);verify(Weather.errorString.includes("invalid data"))
  verify(Weather.retry());request.complete('{"error":true}')
  compare(Weather.tempC,12);verify(Weather.canRetry)
 }
 function test_pause_cancels_and_resumes_failed_request() {
  request.reject("Network error",0);const starts=request.starts
  GamingModeService.gamingModeActive=true
  verify(!Weather.updatesAllowed);verify(!Weather.canRetry);verify(!Weather.retry())
  verify(Weather.errorString!=="")
  GamingModeService.gamingModeActive=false
  compare(request.starts,starts+1);verify(Weather.busy)
  AppConfig.weatherEnabled=false;verify(!Weather.busy);verify(!Weather.retry())
 }
 function test_config_change_replaces_inflight_request() {
  const starts=request.starts
  AppConfig.weatherLatitude=51;wait(1)
  compare(request.starts,starts+1);verify(request.url.includes("latitude=51"))
  request.complete(sample)
  AppConfig.weatherUnits="imperial";wait(1)
  compare(Weather.data,null,"old units must not be shown with a new unit label")
  verify(request.url.includes("temperature_unit=fahrenheit"));verify(Weather.busy)
 }
 function test_authorization_failure_stays_retryable() {
  request.reject("HTTP 403",403)
  verify(Weather.errorString.includes("refused"));compare(Weather.errorDetails,"HTTP 403")
  verify(Weather.canRetry);verify(Weather.retry())
 }
}
''')
    result = subprocess.run(['/usr/lib/qt6/bin/qmltestrunner','-input',str(test),'-import',str(imports)],
                            env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software'),
                            capture_output=True,text=True,timeout=30)
    output = result.stdout + result.stderr
    print(output)
    raise SystemExit(result.returncode or int(any(marker in output for marker in
        ['QWARN','ReferenceError','TypeError','Unable to assign'])))
