#!/usr/bin/env python3
"""Exercise libsecret against a temporary daemon and a private session bus."""
from pathlib import Path
import os
import subprocess
import sys
import tempfile
import time

if len(sys.argv) != 2:
    raise SystemExit('usage: tools/test-network-keyring.py /path/to/network_agent_test')
binary = str(Path(sys.argv[1]).resolve())
if os.environ.get('SHELL_KEYRING_HARNESS_INSIDE') != '1':
    with tempfile.TemporaryDirectory(prefix='shell-private-keyring-') as temp:
        temp = Path(temp)
        runtime = temp / 'runtime'
        runtime.mkdir(mode=0o700)
        control = temp / 'control'
        control.mkdir(mode=0o700)
        env = dict(os.environ, XDG_DATA_HOME=str(temp), XDG_RUNTIME_DIR=str(runtime),
                   GNOME_KEYRING_CONTROL=str(control), SHELL_KEYRING_HARNESS_INSIDE='1',
                   SHELL_KEYRING_ORIGINAL_BUS=os.environ.get('DBUS_SESSION_BUS_ADDRESS', ''))
        result = subprocess.run(['dbus-run-session', '--', sys.executable, __file__, binary], env=env, timeout=30)
        raise SystemExit(result.returncode)
if os.environ.get('DBUS_SESSION_BUS_ADDRESS') == os.environ.get('SHELL_KEYRING_ORIGINAL_BUS'):
    raise SystemExit('Refusing to test on the original session bus')
if not os.environ.get('XDG_DATA_HOME', '').startswith('/tmp/shell-private-keyring-'):
    raise SystemExit('Refusing a non-temporary keyring directory')
daemon = subprocess.Popen(['gnome-keyring-daemon', '--foreground', '--unlock', '--components=secrets',
                           '--control-directory', os.environ['GNOME_KEYRING_CONTROL']],
                          stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
owner_pid = None
try:
    daemon.stdin.write(b'isolated-test-keyring-password\n')
    daemon.stdin.close()
    owner = ''
    for _ in range(50):
        reply = subprocess.run(['busctl', '--address', os.environ['DBUS_SESSION_BUS_ADDRESS'], 'call',
                                'org.freedesktop.DBus', '/org/freedesktop/DBus', 'org.freedesktop.DBus',
                                'GetNameOwner', 's', 'org.freedesktop.secrets'], capture_output=True, text=True)
        if reply.returncode == 0:
            owner = reply.stdout.split('"')[1]
            break
        time.sleep(0.05)
    if not owner:
        raise SystemExit('Temporary secret service did not start')
    pid = subprocess.check_output(['busctl', '--address', os.environ['DBUS_SESSION_BUS_ADDRESS'], 'call',
                                  'org.freedesktop.DBus', '/org/freedesktop/DBus', 'org.freedesktop.DBus',
                                  'GetConnectionUnixProcessID', 's', owner], text=True)
    candidate_pid = int(pid.split()[1])
    data = Path(f'/proc/{candidate_pid}/environ').read_bytes().split(b'\0')
    if ('XDG_DATA_HOME=' + os.environ['XDG_DATA_HOME']).encode() not in data:
        raise SystemExit('Secret service is not isolated')
    owner_pid = candidate_pid
    env = dict(os.environ, SHELL_TEST_PRIVATE_KEYRING='1', QT_ASSUME_STDERR_HAS_CONSOLE='1')
    result = subprocess.run([binary, 'privateKeyringRoundTrip'], env=env, timeout=20)
    if result.returncode:
        raise SystemExit(result.returncode)
finally:
    if owner_pid and owner_pid != daemon.pid:
        import signal
        try:
            os.kill(owner_pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
    if daemon.poll() is None:
        daemon.terminate()
    try:
        daemon.wait(timeout=3)
    except subprocess.TimeoutExpired:
        daemon.kill()
        daemon.wait(timeout=3)
