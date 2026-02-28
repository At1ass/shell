import Quickshell
import Quickshell.Wayland
import qs.src.core.services

Scope {
    WlSessionLock {
        id: sessionLock
        locked: GlobalStates.lockscreenActive

        WlSessionLockSurface {
            id: lockSurface
            color: "black"

            LockSurface {
                anchors.fill: parent
                screen: lockSurface.screen
                onUnlocked: GlobalStates.unlockSession()
            }
        }
    }
}
