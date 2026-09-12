pragma Singleton

import QtQuick
import Quickshell

// Every application the shell starts, in one place.
//
// Anything spawned straight from the shell (DesktopEntry.execute(),
// Quickshell.execDetached) lands in the shell's own cgroup. Apps do outlive
// the shell process there, but they share its fate as a unit: stopping the
// scope, or a kernel OOM kill of any process in it (OOMPolicy=stop), takes
// all of them down, and resource accounting lumps them under the shell.
// app2unit gives each launch its own systemd scope
// (app-<desktop>-<app>-<rand>.scope), managed and accounted individually.
// Slice mapping comes from APP2UNIT_SLICES in the session environment.
Singleton {
    id: root

    // app2unit takes "<entry-id>.desktop" (":<action>" would select an
    // action, hence no ':' allowed). Empty = not launchable by id.
    //
    // The suffix is only ever APPENDED. Quickshell's id is the desktop-file id
    // without its extension -- /usr/share/applications/org.telegram.desktop.desktop
    // has the id "org.telegram.desktop" -- and a reverse-DNS id can itself end
    // in ".desktop". Stripping a trailing ".desktop" "in case it was there" cut
    // that id down to "org.telegram", app2unit was handed "org.telegram.desktop",
    // and every launch from the launcher or dock failed with "Could not find
    // entry". Firefox ("firefox") never showed it, which is why it looked like
    // a per-application problem.
    function _entryArg(entry) {
        const id = entry?.id ?? ""
        return /^[A-Za-z0-9._-]+$/.test(id) ? id + ".desktop" : ""
    }

    // Terminal=true entries only work through app2unit (it wraps them in
    // xdg-terminal-exec); DesktopEntry.execute() spawns them without a TTY.
    function canLaunch(entry) {
        if (!entry) return false
        return root._entryArg(entry) !== "" || !entry.runInTerminal
    }

    function launchEntry(entry) {
        if (!entry) return
        const arg = root._entryArg(entry)
        if (arg === "") {
            // No usable id: Quickshell's own spawner beats dropping the launch.
            entry.execute()
            return
        }
        Quickshell.execDetached(["app2unit", "--", arg])
    }

    // Arbitrary argv, no shell involved.
    function launchCommand(argv) {
        if (!Array.isArray(argv) || argv.length === 0) return
        Quickshell.execDetached(["app2unit", "--"].concat(argv))
    }
}
