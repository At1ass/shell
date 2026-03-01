pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var users: []
    readonly property int count: users.length

    Process {
        id: passwdReader
        command: ["getent", "passwd"]
        running: true

        stdout: SplitParser {
            onRead: data => {
                root._rawLines.push(data)
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                console.warn("UserModel: getent passwd failed with code", exitCode)
            }
            root._parseUsers()
        }
    }

    property var _rawLines: []

    function _parseUsers() {
        let result = []

        for (let i = 0; i < _rawLines.length; i++) {
            let parts = _rawLines[i].split(":")
            if (parts.length < 7) continue

            let username = parts[0]
            let uid = parseInt(parts[2])
            let gecos = parts[4]
            let home = parts[5]
            let loginShell = parts[6]

            // Filter: UID >= 1000, < 65534, not nologin/false
            if (uid < 1000 || uid >= 65534) continue
            if (loginShell.indexOf("nologin") !== -1 || loginShell.indexOf("/false") !== -1) continue

            let displayName = gecos ? gecos.split(",")[0] : username
            let facePath = home + "/.face"

            result.push({
                username: username,
                displayName: displayName || username,
                uid: uid,
                home: home,
                facePath: "file://" + facePath
            })
        }

        root.users = result
    }
}
