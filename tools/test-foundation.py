#!/usr/bin/env python3
"""Exercise config transactions and HTTP lifecycle in isolated Quickshell engines."""
import http.server
import json
import os
from pathlib import Path
import selectors
import shutil
import subprocess
import sys
import tempfile
import threading
import time

ROOT = Path(__file__).resolve().parents[1]


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/slow':
            time.sleep(0.4)
        if self.path == '/error':
            self.send_response(503)
        else:
            self.send_response(200)
        self.end_headers()
        try:
            self.wfile.write(b'ok')
        except (BrokenPipeError, ConnectionResetError):
            pass

    def log_message(self, *_args):
        pass


def check_compiler_contract():
    with tempfile.TemporaryDirectory(prefix='shell-compile-test-') as temp:
        tree = Path(temp)
        (tree / 'tools').mkdir()
        (tree / 'src/features/greeter').mkdir(parents=True)
        script = tree / 'tools/compile-check.sh'
        shutil.copy2(ROOT / 'tools/compile-check.sh', script)
        valid = 'import QtQuick\nQtObject {}\n'
        (tree / 'src/features/greeter/shell.qml').write_text(valid)
        (tree / 'shell.qml').write_text(valid)
        # Packaging artifacts are not runtime sources and may be unreadable.
        artifact = tree / 'packaging/arch/pkg/broken.qml'
        artifact.parent.mkdir(parents=True)
        artifact.write_text('pragma ComponentBehavior: Bound\n' * 2 + valid)
        env = {**os.environ, 'QT_QPA_PLATFORM': 'offscreen'}
        args = ['bash', str(script), '--count']
        good = subprocess.run(args, env=env, capture_output=True, text=True, timeout=15)
        assert good.returncode == 0 and good.stdout.strip() == '0', good.stdout + good.stderr
        (tree / 'shell.qml').write_text('pragma ComponentBehavior: Bound\n' * 2 + valid)
        bad = subprocess.run(args, env=env, capture_output=True, text=True, timeout=15)
        assert bad.returncode != 0 and int(bad.stdout.strip()) > 0, bad.stdout + bad.stderr
        binaries = tree / 'bin'
        binaries.mkdir()
        fake_engine = binaries / 'qs'
        fake_engine.write_text('#!/bin/sh\nexit 0\n')
        fake_engine.chmod(0o755)
        env['PATH'] = str(binaries) + os.pathsep + os.environ['PATH']
        absent = subprocess.run(args, env=env, capture_output=True, text=True, timeout=15)
        assert absent.returncode != 0 and int(absent.stdout.strip()) > 0, absent.stdout + absent.stderr
        print('PASS: compiler completion marker, invalid root, absent probe output')


def run():
    with tempfile.TemporaryDirectory(prefix='shell-foundation-test-') as temp:
        tree = Path(temp)
        shutil.copytree(ROOT / 'src/core/config', tree / 'src/core/config')
        shutil.copytree(ROOT / 'config', tree / 'config')
        shutil.copy2(ROOT / 'src/core/services/HttpRequest.qml', tree / 'HttpRequest.qml')
        session = (ROOT / 'src/core/services/SessionMonitor.qml').read_text()
        (tree / 'SessionProbe.qml').write_text(session.replace('pragma Singleton\n', '', 1))
        binaries = tree / 'bin'
        binaries.mkdir()
        fake_bus = binaries / 'gdbus'
        fake_bus.write_text('#!' + sys.executable + "\n" + """import sys, time
if 'call' in sys.argv:
    print("(objectpath '/org/freedesktop/login1/session/own',)")
else:
    print('/org/freedesktop/login1/session/other: org.freedesktop.login1.Session.Unlock ()', flush=True)
    print('/org/freedesktop/login1/session/own: org.freedesktop.login1.Session.Lock ()', flush=True)
    print('/org/freedesktop/login1/session/own: org.freedesktop.login1.Session.Unlock ()', flush=True)
    print('/org/freedesktop/login1/session/other: org.freedesktop.login1.Manager.PrepareForSleep (false,)', flush=True)
    print('/org/freedesktop/login1: org.freedesktop.login1.Manager.PrepareForSleep (true,)', flush=True)
    print('/org/freedesktop/login1: org.freedesktop.login1.Manager.PrepareForSleep (false,)', flush=True)
    time.sleep(30)
""")
        fake_bus.chmod(0o755)
        config_home = tree / 'xdg'
        config_dir = config_home / 'quickshell'
        config_dir.mkdir(parents=True)
        config = config_dir / 'config.json'
        config.write_text('{')
        server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        probe = tree / 'probe.qml'
        probe.write_text('''import QtQuick
import Quickshell
import qs.src.core.config
QtObject {
    id: root
    property int locks: 0
    property int unlocks: 0
    property int resumes: 0
    property QtObject session: SessionProbe {
        onLockRequested: root.locks++
        onUnlockRequested: root.unlocks++
        onResumed: root.resumes++
    }
    property int httpStep: 0
    property int successes: 0
    property bool httpDone: false
    property HttpRequest request: HttpRequest {
        timeoutMs: 60
        onFailed: (message, status) => {
            if (root.httpStep === 0 && message === "Request timeout") {
                root.httpStep = 1
                request.get("BASE/error")
            } else if (root.httpStep === 1 && status === 503) {
                root.httpStep = 2
                request.get("BASE/slow")
                request.cancel()
                request.get("BASE/ok")
            } else {
                console.warn("TEST_FAIL HTTP " + message + " " + status)
                Qt.exit(1)
            }
        }
        onSucceeded: body => {
            root.successes++
            if (root.httpStep !== 2 || body !== "ok" || root.successes !== 1) {
                console.warn("TEST_FAIL unexpected HTTP response")
                Qt.exit(1)
            }
            root.httpDone = true
        }
    }
    property Timer timer: Timer {
        interval: 100
        repeat: true
        running: true
        onTriggered: {
            console.warn("TEST_STATE " + JSON.stringify({
                ready: AppConfig.ready, scale: AppConfig.motionScale,
                errors: AppConfig.configErrors, httpDone: root.httpDone,
                successes: root.successes, locks: root.locks, unlocks: root.unlocks, resumes: root.resumes
            }))
        }
    }
    Component.onCompleted: Qt.callLater(() => request.get("BASE/slow"))
}
'''.replace('BASE', f'http://127.0.0.1:{server.server_port}'))
        env = {**os.environ, 'XDG_CONFIG_HOME': str(config_home), 'QT_QPA_PLATFORM': 'offscreen', 'PATH': str(binaries) + os.pathsep + os.environ['PATH']}
        process = subprocess.Popen(['qs', '-p', str(probe)], env=env,
                                   stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        selector = selectors.DefaultSelector()
        selector.register(process.stdout, selectors.EVENT_READ)

        recent = []

        def wait_for(predicate):
            deadline = time.monotonic() + 10
            while time.monotonic() < deadline:
                if process.poll() is not None:
                    raise AssertionError(f'Quickshell exited: {process.returncode}')
                if not selector.select(0.2):
                    continue
                line = process.stdout.readline()
                recent.append(line)
                del recent[:-20]
                if 'TEST_FAIL' in line:
                    raise AssertionError(line.strip())
                if 'TEST_STATE ' not in line:
                    continue
                state = json.loads(line.split('TEST_STATE ', 1)[1])
                if predicate(state):
                    return state
            raise AssertionError('Timed out waiting for engine state\n' + ''.join(recent))

        def replace_config(text):
            pending = config.with_suffix('.tmp')
            pending.write_text(text)
            pending.replace(config)

        try:
            wait_for(lambda s: s['ready'] and s['scale'] == 1 and bool(s['errors']))
            replace_config(json.dumps({'version': 1, 'appearance': {'motionScale': 0.7}}))
            wait_for(lambda s: s['ready'] and s['scale'] == 0.7 and not s['errors'] and s['httpDone'] and s['locks'] == 1 and s['unlocks'] == 1 and s['resumes'] == 1)
            replace_config('{')
            wait_for(lambda s: s['scale'] == 0.7 and any('Invalid JSON' in e['message'] for e in s['errors']))
            result = subprocess.run(['qs', 'ipc', '-p', str(probe), 'call', 'config', 'validate'],
                                    env=env, capture_output=True, text=True, timeout=5)
            assert 'Invalid JSON' in result.stdout, result.stdout + result.stderr
            replace_config(json.dumps({'version': 1, 'wallpaper': {'monitors': {'DP-1': {'fillMode': 999, 'typo': True}}}}))
            wait_for(lambda s: s['scale'] == 0.7 and len(s['errors']) == 2)
            replace_config('[]')
            wait_for(lambda s: s['scale'] == 0.7 and any('expected object' in e['message'] for e in s['errors']))
            replace_config(json.dumps({'version': 1, 'appearance': {'motionScale': 0.9}}))
            wait_for(lambda s: s['scale'] == 0.9 and not s['errors'] and s['successes'] == 1)
            print('PASS: config rejection/recovery, IPC diagnostics, monitor validation, HTTP timeout/error/cancel, session signal isolation')
        finally:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
            selector.close()
            server.shutdown()


if __name__ == '__main__':
    check_compiler_contract()
    run()
