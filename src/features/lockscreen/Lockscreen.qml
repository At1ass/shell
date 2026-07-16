import Quickshell
import Quickshell.Wayland
import qs.src.core.services
import qs.src.core.config

Scope {
    WlSessionLock {
        id: sessionLock
        locked: GlobalStates.lockscreenActive

        WlSessionLockSurface {
            id: lockSurface
            color: Theme.surface

            LockSurface {
                anchors.fill: parent
                screen: lockSurface.screen
                onUnlocked: GlobalStates.unlockSession()
            }
        }
    }
}
